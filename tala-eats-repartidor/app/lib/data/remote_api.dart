import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/failures.dart';

const String kDefaultApiBase = 'https://talaeats.alan-palacios-dev.com/api/v1';
const String kApiBase = String.fromEnvironment(
  'TALA_EATS_API_BASE',
  defaultValue: kDefaultApiBase,
);
const String kDriverAppVersion = '1.2.7';

class RemoteSessionStore {
  RemoteSessionStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static const _accessKey = 'driver_access_token_v1';
  static const _deviceTokenKey = 'driver_device_token_v1';
  static const _deviceIdKey = 'driver_device_id_v1';
  static const _routePrefix = 'driver_route_stage_v1_';

  final FlutterSecureStorage _secure;

  Future<String?> accessToken() => _secure.read(key: _accessKey);
  Future<String?> deviceToken() => _secure.read(key: _deviceTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String deviceToken,
  }) async {
    await _secure.write(key: _accessKey, value: accessToken);
    if (deviceToken.trim().isNotEmpty) {
      await _secure.write(key: _deviceTokenKey, value: deviceToken);
    } else {
      await _secure.delete(key: _deviceTokenKey);
    }
  }

  Future<void> clear() async {
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _deviceTokenKey);
  }

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.length >= 8) return existing;
    final random = Random.secure();
    final suffix = List<int>.generate(16, (_) => random.nextInt(256))
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    final value = 'driver-$suffix';
    await prefs.setString(_deviceIdKey, value);
    return value;
  }

  Future<String?> routeStage(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_routePrefix$orderId');
  }

  Future<void> saveRouteStage(int orderId, String stage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_routePrefix$orderId', stage);
  }

  Future<void> clearRouteStage(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_routePrefix$orderId');
  }
}

class RemoteApi {
  static const int _maxResponseBytes = 4 * 1024 * 1024;

  static http.Client _defaultClient() {
    final io = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 20)
      ..maxConnectionsPerHost = 8;
    return IOClient(io);
  }

  RemoteApi({
    String baseUrl = kApiBase,
    http.Client? client,
    RemoteSessionStore? session,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? _defaultClient(),
        session = session ?? RemoteSessionStore();

  final String baseUrl;
  final http.Client _client;
  final RemoteSessionStore session;

  Uri uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(queryParameters: query);
  }

  Uri orderWebSocketUri(int orderId) {
    final api = Uri.parse(baseUrl);
    final scheme = api.scheme == 'https' ? 'wss' : 'ws';
    var rootPath = api.path;
    if (rootPath.endsWith('/api/v1')) {
      rootPath = rootPath.substring(0, rootPath.length - '/api/v1'.length);
    }
    return api.replace(
      scheme: scheme,
      path: '${rootPath.replaceAll(RegExp(r'/+$'), '')}/ws/orders/$orderId',
      query: null,
      fragment: null,
    );
  }

  Future<Map<String, String>> _headers({
    bool auth = true,
    bool json = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-TalaEats-Client': 'driver-mobile',
      'X-TalaEats-App-Version': kDriverAppVersion,
      'X-Device-ID': await session.deviceId(),
      'X-Request-ID':
          'driver-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff).toRadixString(16)}',
    };
    if (json) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = await session.accessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final deviceToken = await session.deviceToken();
      if (deviceToken != null && deviceToken.isNotEmpty) {
        headers['X-Device-Token'] = deviceToken;
      }
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    Object? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client
            .get(uri(path, query), headers: await _headers())
            .timeout(const Duration(seconds: 14));
        return _decode(response);
      } on AppFailure {
        rethrow;
      } on TimeoutException catch (error) {
        last = error;
      } on SocketException catch (error) {
        last = error;
      } on http.ClientException catch (error) {
        last = error;
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
    if (last is TimeoutException) throw const AppFailure(FailureKind.timeout);
    throw const AppFailure(FailureKind.offline);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    try {
      final response = await _client
          .post(
            uri(path),
            headers: await _headers(auth: auth),
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 18));
      return _decode(response, authRoute: path.contains('/auth/login'));
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw const AppFailure(FailureKind.timeout);
    } on SocketException {
      throw const AppFailure(FailureKind.offline);
    } on http.ClientException {
      throw const AppFailure(FailureKind.offline);
    }
  }

  Future<dynamic> patch(String path, {required Map<String, dynamic> body}) async {
    try {
      final response = await _client
          .patch(uri(path), headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 18));
      return _decode(response);
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw const AppFailure(FailureKind.timeout);
    } on SocketException {
      throw const AppFailure(FailureKind.offline);
    } on http.ClientException {
      throw const AppFailure(FailureKind.offline);
    }
  }

  Future<String> uploadDeliveryProof(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw const AppFailure(FailureKind.media);
    final ext = file.path.toLowerCase().split('.').last;
    final mediaType = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
    final request = http.MultipartRequest('POST', uri('/uploads/delivery-proof'));
    request.headers.addAll(await _headers(json: false));
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path, contentType: mediaType),
    );
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 35));
      final response = await http.Response.fromStream(streamed);
      final data = _decode(response);
      if (data is Map && data['url'] != null) return '${data['url']}';
      throw const AppFailure(FailureKind.server);
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw const AppFailure(FailureKind.timeout);
    } on SocketException {
      throw const AppFailure(FailureKind.offline);
    } on http.ClientException {
      throw const AppFailure(FailureKind.offline);
    }
  }

  Future<WebSocket> connectOrderSocket(int orderId) async {
    final token = await session.accessToken();
    if (token == null || token.isEmpty) {
      throw const AppFailure(FailureKind.sessionExpired);
    }
    try {
      return await WebSocket.connect(
        orderWebSocketUri(orderId).toString(),
        headers: <String, dynamic>{'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw const AppFailure(FailureKind.timeout);
    } on SocketException {
      throw const AppFailure(FailureKind.offline);
    }
  }

  dynamic _decode(http.Response response, {bool authRoute = false}) {
    if (response.bodyBytes.length > _maxResponseBytes) {
      throw const AppFailure(FailureKind.server);
    }
    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        payload = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return payload;

    final detail = payload is Map ? '${payload['detail'] ?? ''}'.trim() : '';
    if (response.statusCode == 401) {
      if (authRoute && detail.toLowerCase().contains('2fa')) {
        throw AppFailure(FailureKind.twoFactorRequired, detail);
      }
      if (authRoute) throw AppFailure(FailureKind.invalidCredentials, detail);
      throw AppFailure(FailureKind.sessionExpired, detail);
    }
    if (response.statusCode == 403) {
      throw AppFailure(FailureKind.permissionDenied, detail);
    }
    if (response.statusCode == 404) {
      throw AppFailure(FailureKind.notFound, detail);
    }
    if (response.statusCode == 409) {
      throw AppFailure(FailureKind.conflict, detail);
    }
    if (response.statusCode == 410) {
      throw AppFailure(FailureKind.permissionDenied, detail);
    }
    if (response.statusCode == 413 || response.statusCode == 415) {
      throw AppFailure(FailureKind.media, detail);
    }
    if (response.statusCode == 400 || response.statusCode == 422) {
      throw AppFailure(FailureKind.validation, detail);
    }
    if (response.statusCode == 429) {
      throw const AppFailure(
        FailureKind.server,
        'Hay muchas solicitudes. Espera un momento e intenta de nuevo.',
      );
    }
    if (response.statusCode >= 500) {
      throw AppFailure(FailureKind.server, detail);
    }
    throw AppFailure(FailureKind.unknown, detail);
  }

  void close() => _client.close();
}
