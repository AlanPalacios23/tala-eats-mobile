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

  // Crash-safe checkout journal: encryption and durable commit are required.
  // Any native failure MUST prevent HTTP POST, never silently fall back to
  // unencrypted local storage or a new client_reference.
  static Future<String?> readPendingOrder(int userId) async {
    try {
      return await _channel.invokeMethod<String>('readPendingOrder',
          <String, dynamic>{'userId': userId});
    } on PlatformException {
      throw ApiException(409, 'No pudimos recuperar la compra pendiente '
          'de forma segura. Contacta soporte.');
    } on MissingPluginException {
      throw ApiException(409, 'Almacenamiento Android seguro no disponible. '
          'No se enviará el pedido.');
    }
  }

  static Future<void> writePendingOrder(int userId, String payload) async {
    try {
      await _channel.invokeMethod<void>('writePendingOrder',
          <String, dynamic>{'userId': userId, 'payload': payload});
    } on PlatformException {
      throw ApiException(409, 'No pudimos guardar de forma segura tu pedido. '
          'No se envió el pedido.');
    } on MissingPluginException {
      throw ApiException(409, 'Almacenamiento Android seguro no disponible. '
          'No se enviará el pedido.');
    }
  }

  static Future<void> clearPendingOrder(int userId) async {
    try {
      await _channel.invokeMethod<void>('clearPendingOrder',
          <String, dynamic>{'userId': userId});
    } on PlatformException {
      throw ApiException(409, 'No pudimos confirmar la recuperación local '
          'del pedido. Revisa Mis pedidos antes de continuar.');
    } on MissingPluginException {
      throw ApiException(409, 'Almacenamiento Android seguro no disponible. '
          'No se enviará el pedido.');
    }
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

/// Only checkout orders carry an HTTP Idempotency-Key matching the body.
String? orderIdempotencyKeyFor(String method, String path, Object? body) {
  if (method != 'POST' || path != '/orders' || body is! Map) return null;
  final dynamic raw = body['client_reference'];
  if (raw is! String || raw.isEmpty || raw.length > 180) return null;
  if (raw.contains(RegExp(r'[^A-Za-z0-9_-]'))) return null;
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

  // Customer-owned session management. Never call admin/merchant security APIs.
  Future<List<Map<String, dynamic>>> customerDevices() async =>
      List<dynamic>.from((await get('/auth/devices')) as List)
          .map((dynamic row) => Map<String, dynamic>.from(row as Map)).toList();

  Future<Map<String, dynamic>> revokeCustomerDevice(int deviceId) async {
    if (deviceId <= 0) throw ArgumentError.value(deviceId, 'deviceId');
    return Map<String, dynamic>.from(
      (await post('/auth/devices/$deviceId/revoke')) as Map,
    );
  }

  Future<Map<String, dynamic>> revokeOtherCustomerDevices() async =>
      Map<String, dynamic>.from((await post('/auth/devices/revoke-others')) as Map);

  // Customer decision on merchant-initiated missing-item requests.
  // These endpoints may be unavailable until the corresponding backend
  // release is authorized on Kali. A 404 must not be treated as success.
  Future<List<Map<String, dynamic>>> orderSubstitutions(int orderId) async {
    if (orderId <= 0) throw ArgumentError.value(orderId, 'orderId');
    return List<dynamic>.from((await get('/v11/orders/$orderId/substitutions')) as List)
        .map((dynamic row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<Map<String, dynamic>> respondOrderSubstitution(
      int orderId, int substitutionId, String action) async {
    if (orderId <= 0 || substitutionId <= 0) {
      throw ArgumentError('Identificadores de pedido y sustitución inválidos');
    }
    if (!const <String>{'accept', 'remove_item', 'cancel_order', 'reject'}
        .contains(action)) {
      throw ArgumentError.value(action, 'action', 'Acción no autorizada');
    }
    return Map<String, dynamic>.from(
      (await post('/v11/orders/$orderId/substitutions/$substitutionId/respond',
          <String, dynamic>{'action': action})) as Map,
    );
  }

  Future<List<Map<String, dynamic>>> orderRefunds(int orderId) async {
    if (orderId <= 0) throw ArgumentError.value(orderId, 'orderId');
    return List<dynamic>.from((await get('/v11/orders/$orderId/refunds')) as List)
        .map((dynamic row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<Map<String, dynamic>> updateCustomerAddress(
      int addressId, Map<String, dynamic> changes) async {
    if (addressId <= 0) throw ArgumentError.value(addressId, 'addressId');
    const fields = <String>{'label', 'address', 'lat', 'lng', 'is_default'};
    if (changes.isEmpty || changes.keys.any((String key) => !fields.contains(key))) {
      throw ArgumentError('Solo se permiten cambios de dirección soportados');
    }
    return Map<String, dynamic>.from(
      (await patch('/platform/addresses/$addressId', changes)) as Map,
    );
  }

}
