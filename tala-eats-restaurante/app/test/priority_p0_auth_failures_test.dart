import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talaeats_restaurant/core/failures.dart';
import 'package:talaeats_restaurant/data/remote/remote_api.dart';

class _QaSession extends RemoteSessionStore {
  @override Future<String> deviceId() async => 'qa-android-device-1234';
  @override Future<String?> accessToken() async => null;
  @override Future<String?> deviceToken() async => null;
}

void main() {
  Future<void> checkStatus({
    required int status, required String endpoint, required String method,
    required FailureKind expected, String detail = 'QA no autorizado',
  }) async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.host, 'example.test');
      expect(request.headers['Authorization'], isNull);
      expect(request.headers['X-Device-ID'], 'qa-android-device-1234');
      expect(request.method, method);
      return http.Response(jsonEncode(<String, dynamic>{'detail': detail}), status,
        headers: <String, String>{'content-type':'application/json'});
    });
    final api = RemoteApi(
      baseUrl: 'https://example.test/api/v1', client: client, session: _QaSession(),
    );
    Future<dynamic> action() => method == 'GET'
      ? api.get(endpoint)
      : api.post(endpoint, body: const <String, dynamic>{}, auth: false);
    await expectLater(action(), throwsA(isA<AppFailure>()
      .having((e) => e.kind, 'failure kind', expected)));
    expect(calls, 1, reason: 'No repetir automáticamente un fallo de autorización');
    client.close();
  }

  test('P0 sesión caducada 401 en pedidos', () =>
      checkStatus(status: 401, endpoint: '/owner/orders', method: 'GET',
        expected: FailureKind.sessionExpired));
  test('P0 login inválido 401 sin asumir sesión válida', () =>
      checkStatus(status: 401, endpoint: '/auth/login', method: 'POST',
        expected: FailureKind.invalidCredentials));
  test('P0 login 2FA obligatorio', () =>
      checkStatus(status: 401, endpoint: '/auth/login', method: 'POST',
        expected: FailureKind.twoFactorRequired, detail: '2FA required'));
  test('P0 acceso a finanzas sin rol 403', () =>
      checkStatus(status: 403, endpoint: '/owner/orders', method: 'GET',
        expected: FailureKind.permissionDenied));
  test('P0 alta obligatoria 2FA privilegiada', () =>
      checkStatus(status: 403, endpoint: '/owner/orders', method: 'GET',
        expected: FailureKind.twoFactorSetupRequired, detail: '2FA setup required'));
  test('P1 conflicto en cambio de pedido 409', () =>
      checkStatus(status: 409, endpoint: '/owner/orders', method: 'GET',
        expected: FailureKind.conflict));
  test('P1 limitación de peticiones 429', () =>
      checkStatus(status: 429, endpoint: '/owner/orders', method: 'GET',
        expected: FailureKind.server));
}
