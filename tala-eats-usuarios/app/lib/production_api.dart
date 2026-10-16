import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

const String kProductionApiBase = String.fromEnvironment(
  'TALAEATS_API_BASE_URL',
  defaultValue: 'https://talaeats.alan-palacios-dev.com/api/v1',
);

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.payload]);
  final int statusCode;
  final String message;
  final dynamic payload;
  @override
  String toString() => message;
}

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.talaeats.app/native');

  static Future<String?> readToken() async {
    try { return await _channel.invokeMethod<String>('readToken'); } catch (_) { return null; }
  }

  static Future<void> writeToken(String token) async {
    try {
      await _channel.invokeMethod<void>('writeToken', <String, dynamic>{'token': token});
    } on PlatformException catch (e) {
      throw ApiException(0, 'No pudimos proteger la sesión en este dispositivo: ${e.message ?? 'Keystore no disponible'}');
    }
  }

  static Future<void> clearToken() async {
    try { await _channel.invokeMethod<void>('clearToken'); } catch (_) {}
  }

  static Future<void> openExternal(String url) async {
    if (!url.startsWith('https://')) throw ApiException(0, 'Tala Eats bloqueó un enlace externo no seguro.');
    try {
      await _channel.invokeMethod<void>('openUrl', <String, dynamic>{'url': url});
    } on PlatformException catch (e) {
      throw ApiException(0, 'No pudimos abrir el checkout seguro: ${e.message ?? 'Android rechazó el enlace'}');
    }
  }

  static Future<String?> initialUri() async {
    try { return await _channel.invokeMethod<String>('initialUri'); } catch (_) { return null; }
  }


  static Future<Map<String, double>?> currentLocation() async {
    try {
      final Map<dynamic, dynamic>? raw = await _channel.invokeMapMethod<dynamic, dynamic>('currentLocation');
      if (raw == null) return null;
      final double? lat = double.tryParse(raw['lat']?.toString() ?? '');
      final double? lng = double.tryParse(raw['lng']?.toString() ?? '');
      if (lat == null || lng == null) return null;
      return <String, double>{'lat': lat, 'lng': lng};
    } catch (_) { return null; }
  }


  static Future<String?> pickProfilePhoto(int userId) async {
    try {
      return await _channel.invokeMethod<String>('pickProfilePhoto', <String, dynamic>{'userId': userId});
    } on PlatformException catch (e) {
      throw ApiException(0, 'No pudimos seleccionar la foto: ${e.message ?? 'Android rechazó el archivo'}');
    }
  }

  static Future<String?> profilePhotoPath(int userId) async {
    try { return await _channel.invokeMethod<String>('profilePhotoPath', <String, dynamic>{'userId': userId}); } catch (_) { return null; }
  }

  static Future<void> clearProfilePhoto(int userId) async {
    try { await _channel.invokeMethod<void>('clearProfilePhoto', <String, dynamic>{'userId': userId}); } catch (_) {}
  }
}

/// Bound JSON responses to avoid unbounded memory growth.
Future<String> readBoundedUtf8Response(Stream<List<int>> source, {int maxBytes = 4 * 1024 * 1024}) async {
  if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
  final bytes = <int>[];
  await for (final chunk in source.timeout(const Duration(seconds: 20))) {
    if (chunk.length > maxBytes - bytes.length) {
      throw ApiException(502, 'La respuesta del servidor excedió el tamaño permitido.');
    }
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}

/// Matches the server's existing middleware contract for POST /orders only.
/// The value must be identical to client_reference in the immutable body.
String? orderIdempotencyKeyFor(String method, String path, Object? body) {
  if (method != 'POST' || path != '/orders' || body is! Map) return null;
  final dynamic raw = body['client_reference'];
  if (raw is! String || raw.isEmpty || raw.length > 180) return null;
  if (!RegExp(r'^[A-Za-z0-9_-]+
  TalaApi({String? baseUrl}) : baseUrl = (baseUrl ?? kProductionApiBase).replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  String? token;

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> delete(String path) => _request('DELETE', path);
  Future<dynamic> post(String path, [Object? body]) => _request('POST', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) => _request('PATCH', path, body: body);
  Future<dynamic> put(String path, [Object? body]) => _request('PUT', path, body: body);

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    // Preserve credentials for a logout request already in flight.
    final String? requestToken = token;
    final Uri uri = Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}');
    HttpClientRequest req;
    try {
      req = await _client.openUrl(method, uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(0, 'El servidor tardó demasiado en responder.');
    } on SocketException {
      throw ApiException(0, 'No pudimos conectar con Tala Eats. Revisa tu internet.');
    }
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    req.headers.set('X-TalaEats-Client', 'mobile');
    final String? orderKey = orderIdempotencyKeyFor(method, path, body);
    if (orderKey != null) req.headers.set('Idempotency-Key', orderKey);
    if (requestToken != null && requestToken.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $requestToken');
    }
    if (body != null) req.write(jsonEncode(body));
    HttpClientResponse res;
    try {
      res = await req.close().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(0, 'La operación tardó demasiado. Inténtalo otra vez.');
    }
    String raw;
    try {
      raw = await readBoundedUtf8Response(res);
    } on TimeoutException {
      throw ApiException(0, 'El servidor tardó demasiado en enviar la respuesta.');
    } on SocketException {
      throw ApiException(0, 'Se interrumpió la respuesta. Verifica el pedido antes de reintentar.');
    }
    dynamic decoded;
    if (raw.isNotEmpty) {
      try { decoded = jsonDecode(raw); } catch (_) { decoded = raw; }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = 'No pudimos completar la operación.';
      if (decoded is Map && decoded['detail'] != null) message = decoded['detail'].toString();
      throw ApiException(res.statusCode, message, decoded);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login(String email, String password, {String otp = ''}) async {
    final dynamic data = await post('/auth/login', <String, dynamic>{'email': email, 'password': password, 'otp': otp});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final dynamic data = await post('/auth/register', <String, dynamic>{'name': name, 'email': email, 'password': password});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from((await get('/auth/me')) as Map);
  Future<Map<String, dynamic>> bootstrap() async => Map<String, dynamic>.from((await get('/platform/bootstrap')) as Map);
  Future<List<dynamic>> restaurants() async => List<dynamic>.from((await get('/restaurants')) as List);
  Future<Map<String, dynamic>> restaurant(int id) async => Map<String, dynamic>.from((await get('/restaurants/$id')) as Map);
  Future<List<dynamic>> addresses() async => List<dynamic>.from((await get('/platform/addresses')) as List);
  Future<List<dynamic>> orders() async => List<dynamic>.from((await get('/orders/mine')) as List);
  Future<List<dynamic>> favorites() async => List<dynamic>.from((await get('/platform/favorites')) as List);
  Future<Map<String, dynamic>> wallet() async => Map<String, dynamic>.from((await get('/platform/wallet')) as Map);
  Future<List<dynamic>> notifications() async => List<dynamic>.from((await get('/platform/notifications')) as List);

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async => Map<String, dynamic>.from((await post('/orders', payload)) as Map);
  Future<Map<String, dynamic>> checkout(int orderId) async => Map<String, dynamic>.from((await post('/payments/mercadopago/orders/$orderId/checkout')) as Map);
  Future<Map<String, dynamic>> stripeConfig() async => Map<String, dynamic>.from((await get('/payments/stripe/config')) as Map);
  Future<Map<String, dynamic>> stripePaymentIntent(int orderId) async => Map<String, dynamic>.from((await post('/payments/stripe/orders/$orderId/payment-intent')) as Map);
  Future<Map<String, dynamic>> liveOrder(int orderId) async => Map<String, dynamic>.from((await get('/v11/orders/$orderId/live')) as Map);

  Future<void> forgotPassword(String email) async { await post('/auth/password/forgot', <String, dynamic>{'email': email}); }
  Future<void> resetPassword(String resetToken, String password) async { await post('/auth/password/reset', <String, dynamic>{'token': resetToken, 'password': password}); }
  Future<Map<String, dynamic>> addAddress(Map<String, dynamic> payload) async => Map<String, dynamic>.from((await post('/platform/addresses', payload)) as Map);
  Future<void> deleteAddress(int id) async { await delete('/platform/addresses/$id'); }
  Future<bool> toggleFavorite(int id) async {
    final dynamic data = await post('/platform/favorites/$id');
    return (data as Map)['favorite'] == true;
  }
  Future<Map<String, dynamic>> createSupport(String message, {String category = 'general', int? orderId}) async => Map<String, dynamic>.from((await post('/platform/support', <String, dynamic>{'order_id': orderId, 'category': category, 'message': message})) as Map);
  Future<Map<String, dynamic>> privacy() async => Map<String, dynamic>.from((await get('/v11/privacy/preferences')) as Map);
  Future<Map<String, dynamic>> updatePrivacy(Map<String, dynamic> payload) async => Map<String, dynamic>.from((await put('/v11/privacy/preferences', payload)) as Map);
}
).hasMatch(raw)) return null;
  return raw;
}

class TalaApi {
  TalaApi({String? baseUrl}) : baseUrl = (baseUrl ?? kProductionApiBase).replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  String? token;

  Future<dynamic> get(String path) => _request('GET', path);
  Future<dynamic> delete(String path) => _request('DELETE', path);
  Future<dynamic> post(String path, [Object? body]) => _request('POST', path, body: body);
  Future<dynamic> patch(String path, [Object? body]) => _request('PATCH', path, body: body);
  Future<dynamic> put(String path, [Object? body]) => _request('PUT', path, body: body);

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    // Preserve credentials for a logout request already in flight.
    final String? requestToken = token;
    final Uri uri = Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}');
    HttpClientRequest req;
    try {
      req = await _client.openUrl(method, uri).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(0, 'El servidor tardó demasiado en responder.');
    } on SocketException {
      throw ApiException(0, 'No pudimos conectar con Tala Eats. Revisa tu internet.');
    }
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    req.headers.set('X-TalaEats-Client', 'mobile');
    final String? orderKey = orderIdempotencyKeyFor(method, path, body);
    if (orderKey != null) req.headers.set('Idempotency-Key', orderKey);
    if (requestToken != null && requestToken.isNotEmpty) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $requestToken');
    }
    if (body != null) req.write(jsonEncode(body));
    HttpClientResponse res;
    try {
      res = await req.close().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(0, 'La operación tardó demasiado. Inténtalo otra vez.');
    }
    String raw;
    try {
      raw = await readBoundedUtf8Response(res);
    } on TimeoutException {
      throw ApiException(0, 'El servidor tardó demasiado en enviar la respuesta.');
    } on SocketException {
      throw ApiException(0, 'Se interrumpió la respuesta. Verifica el pedido antes de reintentar.');
    }
    dynamic decoded;
    if (raw.isNotEmpty) {
      try { decoded = jsonDecode(raw); } catch (_) { decoded = raw; }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = 'No pudimos completar la operación.';
      if (decoded is Map && decoded['detail'] != null) message = decoded['detail'].toString();
      throw ApiException(res.statusCode, message, decoded);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login(String email, String password, {String otp = ''}) async {
    final dynamic data = await post('/auth/login', <String, dynamic>{'email': email, 'password': password, 'otp': otp});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final dynamic data = await post('/auth/register', <String, dynamic>{'name': name, 'email': email, 'password': password});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from((await get('/auth/me')) as Map);
  Future<Map<String, dynamic>> bootstrap() async => Map<String, dynamic>.from((await get('/platform/bootstrap')) as Map);
  Future<List<dynamic>> restaurants() async => List<dynamic>.from((await get('/restaurants')) as List);
  Future<Map<String, dynamic>> restaurant(int id) async => Map<String, dynamic>.from((await get('/restaurants/$id')) as Map);
  Future<List<dynamic>> addresses() async => List<dynamic>.from((await get('/platform/addresses')) as List);
  Future<List<dynamic>> orders() async => List<dynamic>.from((await get('/orders/mine')) as List);
  Future<List<dynamic>> favorites() async => List<dynamic>.from((await get('/platform/favorites')) as List);
  Future<Map<String, dynamic>> wallet() async => Map<String, dynamic>.from((await get('/platform/wallet')) as Map);
  Future<List<dynamic>> notifications() async => List<dynamic>.from((await get('/platform/notifications')) as List);

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> payload) async => Map<String, dynamic>.from((await post('/orders', payload)) as Map);
  Future<Map<String, dynamic>> checkout(int orderId) async => Map<String, dynamic>.from((await post('/payments/mercadopago/orders/$orderId/checkout')) as Map);
  Future<Map<String, dynamic>> stripeConfig() async => Map<String, dynamic>.from((await get('/payments/stripe/config')) as Map);
  Future<Map<String, dynamic>> stripePaymentIntent(int orderId) async => Map<String, dynamic>.from((await post('/payments/stripe/orders/$orderId/payment-intent')) as Map);
  Future<Map<String, dynamic>> liveOrder(int orderId) async => Map<String, dynamic>.from((await get('/v11/orders/$orderId/live')) as Map);

  Future<void> forgotPassword(String email) async { await post('/auth/password/forgot', <String, dynamic>{'email': email}); }
  Future<void> resetPassword(String resetToken, String password) async { await post('/auth/password/reset', <String, dynamic>{'token': resetToken, 'password': password}); }
  Future<Map<String, dynamic>> addAddress(Map<String, dynamic> payload) async => Map<String, dynamic>.from((await post('/platform/addresses', payload)) as Map);
  Future<void> deleteAddress(int id) async { await delete('/platform/addresses/$id'); }
  Future<bool> toggleFavorite(int id) async {
    final dynamic data = await post('/platform/favorites/$id');
    return (data as Map)['favorite'] == true;
  }
  Future<Map<String, dynamic>> createSupport(String message, {String category = 'general', int? orderId}) async => Map<String, dynamic>.from((await post('/platform/support', <String, dynamic>{'order_id': orderId, 'category': category, 'message': message})) as Map);
  Future<Map<String, dynamic>> privacy() async => Map<String, dynamic>.from((await get('/v11/privacy/preferences')) as Map);
  Future<Map<String, dynamic>> updatePrivacy(Map<String, dynamic> payload) async => Map<String, dynamic>.from((await put('/v11/privacy/preferences', payload)) as Map);
}
