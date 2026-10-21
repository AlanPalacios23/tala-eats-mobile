import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'local_markets.dart';

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

  // Non-sensitive customer shopping locality persists across Android restarts.
  // Native storage is device-local; no GPS or customer address is saved here.
  static Future<String?> readMarketCode() async {
    try {
      return await _channel.invokeMethod<String>('readMarketCode');
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeMarketCode(String code) async {
    if (!TalaMarket.valid(code)) throw ArgumentError.value(code, 'code');
    try {
      await _channel.invokeMethod<void>(
        'writeMarketCode', <String, dynamic>{'code': code});
    } on PlatformException {
      throw ApiException(503, 'No se pudo guardar la zona de compras.');
    } on MissingPluginException {
      throw ApiException(503, 'Configuración Android de zonas no disponible.');
    }
  }

  // An opaque, random per-install ID; never device serial, advertising ID,
  // GPS or hardware fingerprint. User consent is scoped to this account.
  static Future<String?> pushInstallationId() async {
    try { return await _channel.invokeMethod<String>('pushInstallationId'); }
    catch (_) { return null; }
  }

  static Future<bool> readPushConsent(int userId) async {
    if (userId <= 0) return false;
    try {
      return await _channel.invokeMethod<bool>(
        'readPushConsent', <String, dynamic>{'userId': userId}) == true;
    } catch (_) { return false; }
  }

  static Future<void> writePushConsent(int userId, bool enabled) async {
    if (userId <= 0) throw ArgumentError.value(userId, 'userId');
    try {
      await _channel.invokeMethod<void>('writePushConsent',
        <String, dynamic>{'userId': userId, 'enabled': enabled});
    } on PlatformException {
      throw ApiException(503, 'No se pudo guardar tu preferencia push.');
    } on MissingPluginException {
      throw ApiException(503, 'El dispositivo no admite notificaciones nativas.');
    }
  }

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
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw ApiException(502,
      'Recibimos una respuesta dañada del servidor. Intenta nuevamente.');
  }
}

/// Decode only JSON from the API. Never leak Cloudflare HTML or raw
/// infrastructure error responses into the customer UI.
dynamic decodeTalaApiResponse(String raw, {required int statusCode}) {
  if (raw.isEmpty) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    if (statusCode >= 200 && statusCode < 300) {
      throw ApiException(502,
        'Recibimos una respuesta inesperada del servidor de TALA EATS. '
        'Intenta nuevamente más tarde.');
    }
    // HTTP failures retain their status and get a safe generic message.
    return null;
  }
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
      throw ApiException(0, 'No hay conexión con el servicio de TALA EATS. Comprueba tu internet e inténtalo de nuevo.');
    } on HandshakeException {
      throw ApiException(0, 'No se pudo establecer una conexión segura con TALA EATS.');
    } on HttpException {
      throw ApiException(503, 'El servidor de TALA EATS no está disponible temporalmente.');
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
    } on SocketException {
      throw ApiException(0, 'Se perdió la conexión con el servidor de TALA EATS.');
    } on HandshakeException {
      throw ApiException(0, 'No se pudo establecer una conexión segura con TALA EATS.');
    } on HttpException {
      throw ApiException(503, 'El servidor de TALA EATS no está disponible temporalmente.');
    }
    String raw;
    try {
      raw = await readBoundedUtf8Response(res);
    } on TimeoutException {
      throw ApiException(0, 'El servidor tardó demasiado en enviar la respuesta.');
    } on SocketException {
      throw ApiException(0, 'Se interrumpió la respuesta. Verifica el pedido antes de reintentar.');
    }
    final dynamic decoded = decodeTalaApiResponse(
      raw, statusCode: res.statusCode);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      // Cloudflare 52x responses are upstream failures, not invalid passwords.
      // Never render provider HTML or English origin-error prose to users.
      if (res.statusCode >= 500) {
        throw ApiException(res.statusCode,
          'No logramos comunicarnos con el servidor de TALA EATS. '
          'El servicio está temporalmente no disponible; intenta nuevamente en unos minutos.');
      }
      String message = 'No pudimos completar la operación.';
      if (res.statusCode == 429) {
        message = 'Demasiados intentos. Espera un momento antes de continuar.';
      } else if (decoded is Map && decoded['detail'] != null) {
        final String detail = decoded['detail'].toString();
        // Avoid showing long untrusted infrastructure traces or HTML.
        if (detail.length <= 240 &&
            !RegExp(r'<[^>]+>|cloudflare|origin web server',
                caseSensitive: false).hasMatch(detail)) {
          message = detail;
        }
      }
      throw ApiException(res.statusCode, message);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login(String email, String password, {String otp = ''}) async {
    final dynamic data = await post('/auth/login', <String, dynamic>{'email': email, 'password': password, 'otp': otp});
    if (data is! Map || data['user'] is! Map) {
      throw ApiException(502, 'La respuesta de inicio de sesión no es válida. Intenta nuevamente.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final dynamic data = await post('/auth/register', <String, dynamic>{'name': name, 'email': email, 'password': password});
    if (data is! Map || data['user'] is! Map) {
      throw ApiException(502, 'La respuesta del registro no es válida. Intenta nuevamente.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from((await get('/auth/me')) as Map);
  Future<Map<String, dynamic>> bootstrap() async => Map<String, dynamic>.from((await get('/platform/bootstrap')) as Map);
  Future<List<dynamic>> restaurants() async => List<dynamic>.from((await get('/restaurants')) as List);

  /// Public paged catalog with *server-side* market_code.
  /// Legacy backend versions silently ignore unknown query params, so
  /// verify every record. A mismatched record fails closed (no mixed cities).
  Future<List<dynamic>> restaurantsForMarket(String code) async {
    if (!TalaMarket.valid(code)) {
      throw ArgumentError.value(code, 'code', 'Mercado no soportado');
    }
    const int size = 100;
    const int maxPages = 20;
    final List<dynamic> found = <dynamic>[];
    final Set<int> seen = <int>{};
    try {
      for (int page = 0; page < maxPages; page++) {
        final int offset = page * size;
        final dynamic data = await get(
            '/restaurants?market_code=${Uri.encodeQueryComponent(code)}&limit=$size&offset=$offset');
        if (data is! List) {
          throw const FormatException('El catálogo del servidor no es una lista');
        }
        TalaMarket.verifyPage(code, data, seen);
        found.addAll(data);
        if (data.length < size) return found;
      }
    } on FormatException {
      throw ApiException(503,
          'Este servidor todavía no tiene habilitado el catálogo por localidad. '
          'No se mostrarán negocios de otra ciudad.');
    }
    throw ApiException(503,
        'El catálogo supera el máximo seguro de páginas. Actualiza la app.');
  }

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

  // FCM customer-only. Never send device tokens to analytics or other roles.
  Future<Map<String, dynamic>> customerPushConfig() async =>
      Map<String, dynamic>.from((await get('/mobile-push/config')) as Map);

  Future<Map<String, dynamic>> registerCustomerPush({
    required String token, required String deviceId, bool marketing = false,
  }) async {
    if (token.length < 20 || token.length > 4096 ||
        !RegExp(r'^[A-Za-z0-9_.-]{8,96}$').hasMatch(deviceId)) {
      throw ArgumentError('Token o identificador push inválido');
    }
    return Map<String, dynamic>.from(
      (await put('/mobile-push/devices', <String, dynamic>{
        'token': token, 'device_id': deviceId,
        'application': 'customer', 'platform': 'android',
        'marketing_opt_in': marketing,
      })) as Map);
  }

  Future<Map<String, dynamic>> changeCustomerPushMarketing(
      String deviceId, bool marketing) async {
    if (!RegExp(r'^[A-Za-z0-9_.-]{8,96}$').hasMatch(deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId');
    }
    return Map<String, dynamic>.from(
      (await put('/mobile-push/devices/$deviceId/preferences',
        <String, dynamic>{'marketing_opt_in': marketing})) as Map);
  }

  Future<void> unregisterCustomerPush(String deviceId) async {
    if (!RegExp(r'^[A-Za-z0-9_.-]{8,96}$').hasMatch(deviceId)) {
      throw ArgumentError.value(deviceId, 'deviceId');
    }
    final dynamic result = await delete('/mobile-push/devices/$deviceId');
    if (result is! Map || result['registered'] != false) {
      throw ApiException(502, 'El servidor no confirmó la desactivación push.');
    }
  }


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
