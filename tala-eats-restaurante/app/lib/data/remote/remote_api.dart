import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/failures.dart';


class UploadMediaDescriptor {
  const UploadMediaDescriptor(this.contentType, this.extension);

  final MediaType contentType;
  final String extension;
}

UploadMediaDescriptor detectUploadMediaHeader(List<int> bytes) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) {
    return UploadMediaDescriptor(MediaType('image', 'jpeg'), '.jpg');
  }
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return UploadMediaDescriptor(MediaType('image', 'png'), '.png');
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return UploadMediaDescriptor(MediaType('image', 'webp'), '.webp');
  }
  if (startsWith(const [0x25, 0x50, 0x44, 0x46, 0x2D])) {
    return UploadMediaDescriptor(MediaType('application', 'pdf'), '.pdf');
  }

  throw const AppFailure(
    FailureKind.media,
    'Esta imagen usa un formato no compatible. Elige o exporta la foto como JPG, PNG o WEBP.',
  );
}

const String kDefaultApiBase = 'https://talaeats.alan-palacios-dev.com/api/v1';
const String kApiBase = String.fromEnvironment(
  'TALA_EATS_API_BASE',
  defaultValue: kDefaultApiBase,
);

class RemoteSessionStore {
  RemoteSessionStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static const _accessKey = 'restaurant_access_token_v1';
  static const _deviceTokenKey = 'restaurant_device_token_v1';
  static const _deviceIdKey = 'restaurant_device_id_v1';
  final FlutterSecureStorage _secure;

  // No persistir tokens fuera del almacén cifrado. Si Android conserva un
  // Keystore de una instalación anterior que ya no puede descifrar, la sesión
  // recién autenticada sigue operando SOLO en memoria hasta cerrar la app.
  String? _memoryAccessToken;
  String? _memoryDeviceToken;
  bool _memoryOnly = false;
  String? _temporaryDeviceId;

  bool get sessionIsTemporary => _memoryOnly;

  Future<String?> accessToken() async {
    if (_memoryOnly) return _memoryAccessToken;
    try {
      return await _secure.read(key: _accessKey);
    } on PlatformException {
      _memoryOnly = _memoryAccessToken != null;
      return _memoryAccessToken;
    } on MissingPluginException {
      _memoryOnly = _memoryAccessToken != null;
      return _memoryAccessToken;
    } on FormatException {
      _memoryOnly = _memoryAccessToken != null;
      return _memoryAccessToken;
    }
  }

  Future<String?> deviceToken() async {
    if (_memoryOnly) return _memoryDeviceToken;
    try {
      return await _secure.read(key: _deviceTokenKey);
    } on PlatformException {
      _memoryOnly = _memoryAccessToken != null;
      return _memoryDeviceToken;
    } on MissingPluginException {
      _memoryOnly = _memoryAccessToken != null;
      return _memoryDeviceToken;
    } on FormatException {
      _memoryOnly = _memoryAccessToken != null;
      return _memoryDeviceToken;
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String deviceToken,
  }) async {
    // Guardar primero en memoria para que un error de Keystore posterior a un
    // HTTP 200 no convierta un login válido en "Algo no salió bien".
    _memoryAccessToken = accessToken;
    _memoryDeviceToken = deviceToken.trim().isEmpty ? null : deviceToken;
    _memoryOnly = true;
    try {
      await _secure.write(key: _accessKey, value: accessToken);
      if (deviceToken.trim().isNotEmpty) {
        await _secure.write(key: _deviceTokenKey, value: deviceToken);
      } else {
        await _secure.delete(key: _deviceTokenKey);
      }
      _memoryOnly = false;
    } on PlatformException {
      // No almacenar contraseñas ni tokens en SharedPreferences no cifradas.
    } on MissingPluginException {
      // En este dispositivo la sesión será temporal y no persistida.
    } on FormatException {
      // La sesión actual sigue disponible solo en memoria.
    }
  }

  Future<void> clear() async {
    _memoryAccessToken = null;
    _memoryDeviceToken = null;
    _memoryOnly = false;
    try {
      await _secure.delete(key: _accessKey);
      await _secure.delete(key: _deviceTokenKey);
    } on PlatformException {
      // Se evita fallar al cerrar sesión por un Keystore dañado.
    } on MissingPluginException {
      // Sin plugin nativo; la sesión en memoria ya se borró.
    } on FormatException {
      // Credenciales de memoria borradas.
    }
  }

  Future<String> deviceId() async {
    if (_temporaryDeviceId != null) return _temporaryDeviceId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_deviceIdKey);
      if (existing != null && existing.length >= 8) return existing;
      final value = _newDeviceId();
      // Si la escritura falla, conservarlo en memoria por esta ejecución.
      _temporaryDeviceId = value;
      await prefs.setString(_deviceIdKey, value);
      return value;
    } on PlatformException {
      return _temporaryDeviceId ??= _newDeviceId();
    } on MissingPluginException {
      return _temporaryDeviceId ??= _newDeviceId();
    } on FormatException {
      return _temporaryDeviceId ??= _newDeviceId();
    }
  }

  String _newDeviceId() {
    final random = Random.secure();
    final suffix = List<int>.generate(16, (_) => random.nextInt(256))
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'restaurant-$suffix';
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

  Future<Map<String, String>> _headers({
    bool auth = true,
    bool json = true,
    String? idempotencyKey,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-TalaEats-Client': 'restaurant-mobile',
      'X-TalaEats-App-Version': '0.7.6',
      'X-Device-ID': await session.deviceId(),
      'X-Request-ID': 'rest-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff).toRadixString(16)}',
    };
    if (json) headers['Content-Type'] = 'application/json';
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
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
      if (attempt == 0) await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (last is TimeoutException) throw const AppFailure(FailureKind.timeout);
    throw const AppFailure(FailureKind.offline);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _client
          .post(
            uri(path, query),
            headers: await _headers(auth: auth, idempotencyKey: idempotencyKey),
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
    } on HandshakeException {
      throw const AppFailure(
        FailureKind.offline,
        'No se pudo validar la conexión HTTPS con Tala Eats. Verifica fecha, hora y conexión del teléfono.',
      );
    } on TlsException {
      throw const AppFailure(
        FailureKind.offline,
        'Falló la conexión HTTPS segura con Tala Eats. Comprueba tu conexión.',
      );
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

  Future<void> delete(String path) async {
    try {
      final response = await _client
          .delete(uri(path), headers: await _headers())
          .timeout(const Duration(seconds: 18));
      _decode(response);
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

  Future<String> uploadOnboardingFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw const AppFailure(FailureKind.media);

    final media = await _detectUploadMedia(file);
    final request = http.MultipartRequest('POST', uri('/uploads/onboarding-document'));
    request.headers.addAll(await _headers(json: false));
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: 'talaeats_${DateTime.now().microsecondsSinceEpoch}${media.extension}',
        contentType: media.contentType,
      ),
    );
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
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

  Future<String> uploadCatalogImage(String filePath, String endpoint) async {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) return filePath;
    final file = File(filePath);
    if (!await file.exists()) throw const AppFailure(FailureKind.media);
    final media = await _detectUploadMedia(file);
    if (media.contentType.type != 'image') throw const AppFailure(FailureKind.media);
    final request = http.MultipartRequest('POST', uri(endpoint));
    request.headers.addAll(await _headers(json: false));
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: 'talaeats_${DateTime.now().microsecondsSinceEpoch}${media.extension}',
        contentType: media.contentType,
      ),
    );
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      final data = _decode(response);
      if (data is Map && data['url'] is String) {
        final url = (data['url'] as String).trim();
        final location = Uri.tryParse(url);
        final origin = Uri.tryParse(baseUrl);
        if (location != null && origin != null &&
            location.scheme == 'https' && location.host == origin.host &&
            location.path.startsWith('/api/v1/uploads/catalog/') &&
            location.pathSegments.length == 5) {
          return url;
        }
      }
      throw const AppFailure(
        FailureKind.server,
        'El servidor no confirmó la URL pública de la foto. No se marcó como publicada.',
      );
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

  Future<UploadMediaDescriptor> _detectUploadMedia(File file) async {
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      final header = await handle.read(16);
      return detectUploadMediaHeader(header);
    } on AppFailure {
      rethrow;
    } on FileSystemException {
      throw const AppFailure(FailureKind.media);
    } finally {
      await handle?.close();
    }
  }

  dynamic _decode(http.Response response, {bool authRoute = false}) {
    if (response.bodyBytes.length > _maxResponseBytes) {
      throw const AppFailure(
        FailureKind.server,
        'La respuesta del servidor fue demasiado grande. Intenta de nuevo.',
      );
    }
    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body);
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
      if (detail.toLowerCase().contains('2fa')) {
        throw AppFailure(FailureKind.twoFactorSetupRequired, detail);
      }
      throw AppFailure(FailureKind.permissionDenied, detail);
    }
    if (response.statusCode == 404) throw AppFailure(FailureKind.notFound, detail);
    if (response.statusCode == 409) throw AppFailure(FailureKind.conflict, detail);
    if (response.statusCode == 413 || response.statusCode == 415) {
      throw AppFailure(FailureKind.media, detail);
    }
    if (response.statusCode == 400 || response.statusCode == 422) {
      throw AppFailure(FailureKind.validation, detail);
    }
    if (response.statusCode == 429) {
      throw const AppFailure(FailureKind.server, 'Hay muchas solicitudes. Espera un momento e intenta de nuevo.');
    }
    if (response.statusCode >= 500) throw AppFailure(FailureKind.server, detail);
    throw AppFailure(FailureKind.unknown, detail);
  }
}
