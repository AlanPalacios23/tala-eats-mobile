import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talaeats_restaurant/core/failures.dart';
import 'package:talaeats_restaurant/data/remote/remote_api.dart';
import 'package:talaeats_restaurant/data/remote/remote_repositories.dart';

class _SessionForLogin extends RemoteSessionStore {
  String? token;
  String? attestation;

  @override
  Future<String?> accessToken() async => token;
  @override
  Future<String?> deviceToken() async => attestation;
  @override
  Future<String> deviceId() async => 'restaurant-login-test-device';
  @override
  Future<void> saveTokens({required String accessToken, required String deviceToken}) async {
    token = accessToken;
    attestation = deviceToken;
  }
}

Map<String, dynamic> _success() => {
  'access_token': 'token-prueba-nuevo',
  'device_token': 'atestacion-prueba-nueva',
  'user': {
    'id': 31, 'name': 'Restaurante Ejemplo',
    'email': 'restaurante@example.com', 'role': 'restaurant',
    'phone': '', 'two_factor_enabled': true,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('login real usa POST /api/v1/auth/login sin token antiguo y guarda nueva sesión', () async {
    final session = _SessionForLogin()..token = 'anterior';
    var calls = 0;
    final api = RemoteApi(session: session, client: MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.scheme, 'https');
      expect(request.url.path, '/api/v1/auth/login');
      expect(request.headers.entries.where((e) => e.key.toLowerCase() == 'x-talaeats-client').single.value, 'restaurant-mobile');
      expect(request.headers.entries.where((e) => e.key.toLowerCase() == 'x-talaeats-app-version').single.value, '0.7.5');
      expect(request.headers.keys.any((k) => k.toLowerCase() == 'authorization'), isFalse);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['email'], 'restaurante@example.com');
      expect(body['password'], 'clave-segura');
      expect(body['otp'], '123456');
      return http.Response(jsonEncode(_success()), 200,
          headers: {'content-type': 'application/json'});
    }));
    final user = await RemoteAuthRepository(api).signIn(
      email: ' Restaurante@Example.com ', password: 'clave-segura', otp: '123456');
    expect(user.id, 31);
    expect(user.role, 'restaurant');
    expect(user.twoFactorEnabled, isTrue);
    expect(session.token, 'token-prueba-nuevo');
    expect(session.attestation, 'atestacion-prueba-nueva');
    expect(calls, 1);
  });

  test('login 401 por 2FA solicita código y no guarda tokens', () async {
    final session = _SessionForLogin();
    final api = RemoteApi(session: session, client: MockClient((_) async =>
      http.Response(jsonEncode({'detail': 'Código de verificación 2FA requerido o inválido'}), 401)));
    await expectLater(
      RemoteAuthRepository(api).signIn(email: 'restaurante@example.com', password: 'a'),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.twoFactorRequired)),
    );
    expect(session.token, isNull);
  });

  test('token cookie de web se rechaza en app móvil', () async {
    final session = _SessionForLogin();
    final payload = _success()..['access_token'] = 'cookie';
    final api = RemoteApi(session: session, client: MockClient((_) async =>
      http.Response(jsonEncode(payload), 200)));
    await expectLater(
      RemoteAuthRepository(api).signIn(email: 'restaurante@example.com', password: 'a'),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.server)),
    );
    expect(session.token, isNull);
  });

  test('fallo de certificado HTTPS se explica y no se oculta como unknown', () async {
    final api = RemoteApi(session: _SessionForLogin(), client: MockClient((_) async {
      throw HandshakeException('test TLS');
    }));
    await expectLater(
      RemoteAuthRepository(api).signIn(email: 'restaurante@example.com', password: 'a'),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.offline)),
    );
  });
}
