import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/production_api.dart';

class _UnexpectedAuthApi extends TalaApi {
  _UnexpectedAuthApi(this.payload);

  final dynamic payload;

  @override
  Future<dynamic> post(String path, [Object? body]) async => payload;
}

void main() {
  test('La API conserva JSON valido para el flujo de Usuarios', () {
    expect(decodeTalaApiResponse('{"ok":true}', statusCode: 200),
      <String, dynamic>{'ok': true});
    expect(decodeTalaApiResponse('[1,2]', statusCode: 200),
      <dynamic>[1, 2]);
    expect(decodeTalaApiResponse('', statusCode: 204), isNull);
  });

  test('HTTP 200 con HTML de proxy no se trata como login exitoso', () {
    expect(
      () => decodeTalaApiResponse(
        '<html><title>cloudflare</title><body>origin error</body></html>',
        statusCode: 200),
      throwsA(isA<ApiException>()
        .having((e) => e.statusCode, 'status', 502)
        .having((e) => e.message, 'mensaje', isNot(contains('<html>')))),
    );
  });

  test('JSON truncado exitoso produce error amable, no FormatException', () {
    expect(() => decodeTalaApiResponse('{"user":', statusCode: 200),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)));
  });

  test('HTML de error HTTP 503 no se muestra ni anula su estado', () {
    expect(decodeTalaApiResponse('<h1>Internal error</h1>', statusCode: 503),
      isNull);
  });

  test('UTF-8 invalido se informa sin arrojar FormatException al formulario', () async {
    final bytes = Stream<List<int>>.fromIterable(<List<int>>[
      <int>[0x7b, 0x22, 0x61, 0x22, 0x3a, 0xff, 0x7d],
    ]);
    await expectLater(readBoundedUtf8Response(bytes),
      throwsA(isA<ApiException>()
        .having((e) => e.statusCode, 'status', 502)));
  });

  test('Login y registro rechazan cuerpos JSON inesperados de manera controlada', () async {
    for (final dynamic body in <dynamic>[
      null, 'ok', <String, dynamic>{'ok': true}, <dynamic>[],
    ]) {
      final api = _UnexpectedAuthApi(body);
      await expectLater(api.login('cliente@ejemplo.com', 'ClaveSegura123'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)));
      await expectLater(api.register('Cliente', 'cliente@ejemplo.com', 'ClaveSegura123'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)));
    }
  });

  test('El cuerpo JSON serializado de alta conserva el contrato actual', () {
    final decoded = decodeTalaApiResponse(
      jsonEncode(<String, dynamic>{
        'user': <String, dynamic>{'id': 123, 'role': 'customer'},
        'access_token': 'token-test',
      }), statusCode: 201);
    expect(decoded['user']['role'], 'customer');
  });
}
