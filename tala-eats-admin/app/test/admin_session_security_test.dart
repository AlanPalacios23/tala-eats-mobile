import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talaeats_admin/admin_api.dart';
import 'package:talaeats_admin/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('Después de enrolar TOTP se exige login nuevo con OTP', () async {
    final paths = <String>[];
    final api = AdminApi(
      baseUrl: 'https://admin-stage.example.test/api/v1',
      client: MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        final path = request.url.path;
        if (path.endsWith('/auth/login')) {
          final input = jsonDecode(request.body) as Map;
          final verified = input['otp'] == '654321';
          return http.Response(jsonEncode({
            'access_token': verified ? 'verified-token' : 'unverified-token',
            'user': {
              'id': 2, 'role': 'admin',
              'two_factor_enabled': verified,
            },
          }), 200);
        }
        if (path.endsWith('/security/2fa/setup')) {
          return http.Response(jsonEncode({'secret': 'TESTSECRET'}), 200);
        }
        if (path.endsWith('/security/2fa/confirm')) {
          return http.Response(jsonEncode({'enabled': true}), 200);
        }
        if (path.endsWith('/auth/logout')) return http.Response('', 204);
        if (path.endsWith('/admin/stats')) {
          expect(request.headers['authorization'], 'Bearer verified-token');
          return http.Response(jsonEncode({'orders': 4}), 200);
        }
        throw StateError('Unexpected request: $path');
      }),
    );
    final storage = const FlutterSecureStorage();
    final control = AdminController(api: api, storage: storage);

    await control.login('admin@example.test', 'password', '');
    expect(control.stage, AdminStage.enrollMfa);
    expect(await storage.read(key: 'talaeats_admin_session_v1'), isNull);

    await control.startMfa();
    await control.confirmMfa('123456');
    expect(control.stage, AdminStage.signedOut);
    expect(api.token, isNull);
    expect(await storage.read(key: 'talaeats_admin_session_v1'), isNull);
    expect(control.notice, contains('Inicia sesión de nuevo'));
    expect(paths, isNot(contains('GET /api/v1/auth/me')));

    await control.login('admin@example.test', 'password', '654321');
    expect(control.stage, AdminStage.signedIn);
    expect(control.stats['orders'], 4);
    expect(await storage.read(key: 'talaeats_admin_session_v1'),
        'verified-token');
    control.dispose();
  });

  test('Sesión revocada (403): olvida token y borra datos previos', () async {
    var statsCount = 0;
    final api = AdminApi(
      baseUrl: 'https://admin-stage.example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(jsonEncode({
            'access_token': 'verified-token',
            'user': {'role': 'admin', 'two_factor_enabled': true},
          }), 200);
        }
        if (request.url.path.endsWith('/admin/stats')) {
          statsCount++;
          if (statsCount == 1) {
            return http.Response(jsonEncode({'orders': 5}), 200);
          }
          return http.Response(jsonEncode({'error': 'Sesión invalidada'}), 403);
        }
        throw StateError('Unexpected path: ${request.url.path}');
      }),
    );
    final storage = const FlutterSecureStorage();
    final control = AdminController(api: api, storage: storage);
    await control.login('admin@example.test', 'password', '654321');
    expect(control.stage, AdminStage.signedIn);
    expect(control.stats['orders'], 5);

    await control.refresh();
    expect(control.stage, AdminStage.signedOut);
    expect(control.stats, isEmpty);
    expect(api.token, isNull);
    expect(await storage.read(key: 'talaeats_admin_session_v1'), isNull);
    control.dispose();
  });
}
