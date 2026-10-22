import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talaeats_admin/admin_api.dart';
import 'package:talaeats_admin/admin_registration.dart';

void main() {
  test('Registro crea únicamente usuario customer y descarta Bearer', () async {
    final paths = <String>[];
    final api = AdminApi(
      baseUrl: 'https://node-stage.example.test/api/v1',
      client: MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/auth/register')) {
          final payload = jsonDecode(request.body) as Map;
          expect(payload.keys.toSet(), {'name', 'email', 'password'});
          expect(payload['name'], 'Operadora QA');
          expect(payload['email'], 'test@example.test');
          return http.Response(jsonEncode({
            'access_token': 'temporary-signup-token',
            'user': {'role': 'customer', 'name': 'Operadora QA'},
          }), 201);
        }
        if (request.url.path.endsWith('/auth/logout')) {
          expect(request.headers['authorization'], 'Bearer temporary-signup-token');
          return http.Response('', 204);
        }
        throw StateError('Ruta no prevista');
      }),
    );
    await api.registerCustomer(' Operadora QA ', 'TEST@example.test', 'password1234');
    expect(paths, ['POST /api/v1/auth/register', 'POST /api/v1/auth/logout']);
    expect(api.token, isNull);
    api.dispose();
  });

  test('Registro que retorne rol privilegiado no se considera válido', () async {
    final api = AdminApi(
      baseUrl: 'https://node-stage.example.test/api/v1',
      client: MockClient((_) async => http.Response(
        jsonEncode({'access_token': 'unused',
          'user': {'role': 'admin'}}), 201)),
    );
    await expectLater(
        api.registerCustomer('Operador', 'test@example.test', 'password1234'),
        throwsA(isA<AdminApiException>().having((e) => e.status, 'status', 502)));
    expect(api.token, isNull);
    api.dispose();
  });

  test('Conexión confirma Node staging sin enviar credenciales', () async {
    final api = AdminApi(
      baseUrl: 'https://node-stage.example.test/api/v1',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/health');
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response(jsonEncode({
          'status': 'ok', 'version': '0.1.0-node-stripe-only-stage',
          'production': false, 'digital_payment_provider': 'stripe'
        }), 200);
      }),
    );
    expect(await api.connectionInfo(), contains('Node staging conectado'));
    api.dispose();
  });

  testWidgets('Crear cuenta no muestra opción de autoconceder rol ADMIN', (tester) async {
    final api = AdminApi(baseUrl: 'https://node-stage.example.test/api/v1');
    await tester.pumpWidget(MaterialApp(home: AdminRegistrationScreen(api: api)));
    expect(find.text('Crear cuenta estándar'), findsOneWidget);
    expect(find.textContaining('nunca otorga permisos ADMIN'), findsOneWidget);
    expect(find.text('Administrador'), findsNothing);
    api.dispose();
  });
}
