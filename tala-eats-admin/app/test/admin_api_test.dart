import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talaeats_admin/admin_api.dart';

void main() {
  test('Soporte y archivado requieren habilitación de escrituras', () async {
    expect(kAdminWritesEnabled, isFalse);
    final api = AdminApi(baseUrl: 'https://stage.example/api/v1');
    await expectLater(api.respondSupport(1, 'resolved', 'Respuesta para cliente'),
        throwsA(isA<AdminApiException>()));
    await expectLater(api.archiveRestaurant(2, 'Comercio', 'Inactivo definitivamente'),
        throwsA(isA<AdminApiException>()));
    api.dispose();
  });
  test('Las mutaciones de ADMIN están apagadas por defecto', () async {
    expect(kAdminWritesEnabled, isFalse);
    final api = AdminApi(baseUrl: 'https://stage.example/api/v1');
    await expectLater(api.decideOnboarding(10, 'approved', ''),
      throwsA(isA<AdminApiException>()));
    api.dispose();
  });
  test('Rechaza acceso de restaurante y nunca conserva token', () async {
    final api = AdminApi(baseUrl: 'https://stage.example/api/v1',
      client: MockClient((request) async => http.Response(jsonEncode({
        'access_token': 'dummy-test-token',
        'user': {'role': 'restaurant', 'two_factor_enabled': true}
      }), 200)));
    await expectLater(api.login('x@example.com', 'password123', '123456'),
      throwsA(isA<AdminApiException>()));
    expect(api.token, isNull);
    api.dispose();
  });

  test('Envía token al endpoint administrativo compartido', () async {
    final api = AdminApi(baseUrl: 'https://stage.example/api/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/stats');
        expect(request.headers['authorization'], 'Bearer token-test');
        expect(request.headers['x-talaeats-client'], 'mobile');
        return http.Response(jsonEncode({'orders': 3, 'active_orders': 1}), 200);
      }));
    api.token = 'token-test';
    expect((await api.stats())['active_orders'], 1);
    api.dispose();
  });

  test('No permite API por HTTP público ni sin URL', () async {
    final invalid = AdminApi(baseUrl: 'http://example.com/api/v1');
    await expectLater(invalid.stats(), throwsA(isA<AdminApiException>()));
    invalid.dispose();
    final empty = AdminApi(baseUrl: '');
    await expectLater(empty.stats(), throwsA(isA<AdminApiException>()));
    empty.dispose();
  });

  test('Una respuesta 403 se propaga; nunca se transforma en éxito', () async {
    final api = AdminApi(baseUrl: 'https://stage.example/api/v1',
      client: MockClient((request) async => http.Response(
        jsonEncode({'error': 'Sin acceso'}), 403)));
    api.token = 'token-test';
    await expectLater(api.stats(), throwsA(
      isA<AdminApiException>().having((e) => e.status, 'status', 403)));
    api.dispose();
  });
}
