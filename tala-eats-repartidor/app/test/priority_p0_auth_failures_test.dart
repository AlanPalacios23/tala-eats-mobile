import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talaeats_driver/core/failures.dart';
import 'package:talaeats_driver/data/remote_api.dart';

class _QaSession extends RemoteSessionStore {
  @override Future<String> deviceId() async => 'qa-driver-device-1234';
  @override Future<String?> accessToken() async => null;
  @override Future<String?> deviceToken() async => null;
}

void main() {
  Future<void> checkStatus({
    required int status, required String endpoint, required String method,
    required FailureKind expected, String detail = 'QA denied',
  }) async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.host, 'example.test');
      expect(request.headers['Authorization'], isNull);
      expect(request.headers['X-Device-ID'], 'qa-driver-device-1234');
      expect(request.method, method);
      return http.Response(jsonEncode(<String, dynamic>{'detail':detail}), status,
        headers: <String,String>{'content-type':'application/json'});
    });
    final api = RemoteApi(baseUrl: 'https://example.test/api/v1',
      client: client, session: _QaSession());
    Future<dynamic> action() => method == 'GET'
        ? api.get(endpoint)
        : api.post(endpoint, body: const <String,dynamic>{}, auth: false);
    await expectLater(action(), throwsA(isA<AppFailure>()
      .having((e) => e.kind, 'failure kind', expected)));
    expect(calls, 1, reason:'Una respuesta 401/403 no debe reintentarse sin credenciales');
    client.close();
  }

  test('P0 dashboard 401 causa sesión vencida', () =>
    checkStatus(status:401, endpoint:'/driver/dashboard', method:'GET',
      expected:FailureKind.sessionExpired));
  test('P0 login 401 contraseña errónea', () =>
    checkStatus(status:401, endpoint:'/auth/login', method:'POST',
      expected:FailureKind.invalidCredentials));
  test('P0 login solicita 2FA', () =>
    checkStatus(status:401, endpoint:'/auth/login', method:'POST',
      expected:FailureKind.twoFactorRequired, detail:'2FA required'));
  test('P0 acceso sin rol 403 no permite operación', () =>
    checkStatus(status:403, endpoint:'/driver/dashboard', method:'GET',
      expected:FailureKind.permissionDenied));
  test('P1 estado de reparto conflictivo 409', () =>
    checkStatus(status:409, endpoint:'/driver/dashboard', method:'GET',
      expected:FailureKind.conflict));
  test('P1 control de frecuencia 429', () =>
    checkStatus(status:429, endpoint:'/driver/dashboard', method:'GET',
      expected:FailureKind.server));
}
