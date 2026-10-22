import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// API compartida con el ecosistema Tala Eats. Sin backend independiente.
/// En builds ADMIN no hay URL por defecto: evita operaciones accidentales en LIVE.
const String kAdminApiBase = String.fromEnvironment(
  'TALAEATS_ADMIN_API_BASE_URL',
  defaultValue: '',
);

/// Las escrituras se activan solo en builds deliberados para STAGING.
const bool kAdminWritesEnabled = bool.fromEnvironment(
  'TALAEATS_ADMIN_WRITES_ENABLED', defaultValue: false);

/// Un build con permisos de escritura se fija a UNA URL exacta de staging.
/// Ningún dominio queda permitido implícitamente, ni siquiera producción.
const String kAdminWriteApiBase = String.fromEnvironment(
  'TALAEATS_ADMIN_WRITE_API_BASE_URL', defaultValue: '');

class AdminApiException implements Exception {
  const AdminApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

class AdminApi {
  AdminApi({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? kAdminApiBase).replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? token;
  bool get configured => baseUrl.isNotEmpty;

  /// Exige 2 definiciones independientes y la coincidencia exacta HTTPS.
  /// No sustituye la autorización ADMIN+MFA del servidor.
  bool get writesEnabled =>
      // V0.1 solo pruebas DEBUG; nunca habilitar escrituras en un APK release.
      kDebugMode &&
      kAdminWritesEnabled &&
      kAdminWriteApiBase.isNotEmpty &&
      baseUrl == kAdminWriteApiBase &&
      Uri.tryParse(baseUrl)?.scheme == 'https';

  void dispose() => _client.close();

  Uri _uri(String path) {
    if (!configured) throw const AdminApiException(0, 'Falta configurar la API ADMIN.');
    final base = Uri.tryParse(baseUrl);
    if (base == null || (base.scheme != 'https' &&
        !(kDebugMode && base.scheme == 'http' && base.host == '10.0.2.2'))) {
      throw const AdminApiException(0, 'La API ADMIN requiere HTTPS.');
    }
    if (base.userInfo.isNotEmpty || base.query.isNotEmpty || base.fragment.isNotEmpty ||
        base.path != '/api/v1') {
      throw const AdminApiException(0, 'La URL debe terminar en /api/v1.');
    }
    return Uri.parse('$baseUrl$path');
  }

  Future<dynamic> request(String method, String path, {Map<String, dynamic>? data}) async {
    final request = http.Request(method, _uri(path));
    // No reenviar Authorization a destinos externos tras 30x.
    request.followRedirects = false;
    request.headers.addAll(<String, String>{
      'Accept': 'application/json',
      'Cache-Control': 'no-store',
      'x-talaeats-client': 'mobile',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    });
    if (data != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(data);
    }
    try {
      final response = await http.Response.fromStream(await _client.send(request)
          .timeout(const Duration(seconds: 15)));
      dynamic value;
      try {
        value = response.body.isEmpty ? null : jsonDecode(response.body);
      } on FormatException {
        throw AdminApiException(response.statusCode, 'Respuesta inesperada del servidor.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = value is Map ? (value['detail'] ?? value['error']) : null;
        throw AdminApiException(response.statusCode,
            detail is String && detail.isNotEmpty
                ? detail : 'Error HTTP ${response.statusCode}.');
      }
      return value;
    } on AdminApiException {
      rethrow;
    } catch (_) {
      throw const AdminApiException(0, 'No se pudo conectar con la API. Revisa la red.');
    }
  }

  /// Autoregistro ordinario: el servidor asigna exclusivamente role=customer.
  /// Una cuenta nueva NO recibe permisos ADMIN ni acceso al panel.
  /// Revocamos de inmediato el token emitido durante el registro.
  Future<void> registerCustomer(String name, String email, String password) async {
    if (token != null) {
      throw const AdminApiException(409, 'Cierra la sesión antes de crear otra cuenta.');
    }
    if (name.trim().length < 2 || name.trim().length > 120 ||
        !email.contains('@') || password.length < 8 || password.length > 128) {
      throw const AdminApiException(422, 'Revisa nombre, correo y contraseña.');
    }
    final data = await request('POST', '/auth/register', data: {
      'name': name.trim(), 'email': email.trim().toLowerCase(),
      'password': password,
    });
    if (data is! Map || data['user'] is! Map ||
        data['user']['role'] != 'customer') {
      throw const AdminApiException(502, 'El registro no confirmó una cuenta estándar.');
    }
    final issued = data['access_token'];
    if (issued is String && issued.isNotEmpty && issued != 'cookie') {
      token = issued;
      try {
        await logout();
      } catch (_) {
        // La aplicación descarta el token aunque el servidor esté sin red.
      } finally {
        token = null;
      }
    }
  }

  Future<Map<String, dynamic>> login(String email, String password, String otp) async {
    final result = await request('POST', '/auth/login',
      data: <String, dynamic>{'email': email.trim(), 'password': password, 'otp': otp.trim()});
    if (result is! Map || result['user'] is! Map ||
        result['access_token'] is! String || result['access_token'] == 'cookie') {
      throw const AdminApiException(0, 'Respuesta de autenticación incompleta.');
    }
    final user = Map<String, dynamic>.from(result['user'] as Map);
    if (user['role'] != 'admin') {
      throw const AdminApiException(403, 'Solo las cuentas ADMIN pueden entrar.');
    }
    token = result['access_token'] as String;
    return user;
  }

  Future<Map<String, dynamic>> me() async {
    final value = await request('GET', '/auth/me');
    if (value is! Map) throw const AdminApiException(0, 'Perfil inválido.');
    return Map<String, dynamic>.from(value);
  }

  Future<void> logout() async => request('POST', '/auth/logout');

  Future<Map<String, dynamic>> mfaSetup() async {
    final result = await request('POST', '/v9/security/2fa/setup');
    if (result is! Map || result['secret'] is! String) {
      throw const AdminApiException(0, 'Configuración 2FA no disponible.');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<void> mfaConfirm(String code) async {
    await request('POST', '/v9/security/2fa/confirm', data: {'code': code});
  }

  Future<Map<String, dynamic>> stats() async {
    final result = await request('GET', '/admin/stats');
    if (result is! Map) throw const AdminApiException(0, 'Estadísticas inválidas.');
    return Map<String, dynamic>.from(result);
  }

  Future<List<Map<String, dynamic>>> collection(String path) async {
    final result = await request('GET', path);
    if (result is! List) throw const AdminApiException(0, 'Listado inválido.');
    return result.map((e) {
      if (e is! Map) throw const AdminApiException(0, 'Registro inválido.');
      return Map<String, dynamic>.from(e);
    }).toList();
  }

  Future<void> respondSupport(int id, String status, String reply) async {
    if (!writesEnabled) {
      throw const AdminApiException(403, 'Escrituras ADMIN deshabilitadas.');
    }
    if (id <= 0 || !{'in_progress', 'resolved'}.contains(status) ||
        (status == 'resolved' && reply.trim().length < 10)) {
      throw const AdminApiException(422, 'Respuesta de soporte inválida.');
    }
    await request('PATCH', '/admin/support/$id',
        data: {'status': status, if (status == 'resolved') 'reply': reply.trim()});
  }

  Future<void> archiveRestaurant(int id, String name, String reason) async {
    if (!writesEnabled) {
      throw const AdminApiException(403, 'Escrituras ADMIN deshabilitadas.');
    }
    if (id <= 0 || name.trim().isEmpty || reason.trim().length < 10) {
      throw const AdminApiException(422, 'Confirmación de archivo inválida.');
    }
    await request('PATCH', '/admin/restaurants/$id/archive',
      data: {'confirm_name': name, 'reason': reason.trim()});
  }

  Future<void> suspendRestaurant(int id) async {
    if (!writesEnabled || id <= 0) {
      throw const AdminApiException(403, 'Suspensión no autorizada en este build.');
    }
    await request('PATCH', '/admin/restaurants/$id/verification?status=suspended');
  }

  Future<void> decideOnboarding(int id, String status, String notes) async {
    if (!writesEnabled) {
      throw const AdminApiException(403, 'Escrituras ADMIN deshabilitadas en este build.');
    }
    if (!{'approved', 'rejected', 'needs_info'}.contains(status) || id <= 0) {
      throw const AdminApiException(0, 'Decisión inválida.');
    }
    await request('PATCH', '/operations/admin/onboarding/$id',
      data: {'status': status, 'notes': notes.trim()});
  }
}
