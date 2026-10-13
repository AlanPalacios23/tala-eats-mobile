import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

class _RestoreApi extends TalaApi {
  _RestoreApi(this.status);
  final int status;
  @override
  Future<dynamic> get(String path) async {
    if (path == '/auth/google/config') return <String, dynamic>{'enabled': false};
    return const <String, dynamic>{};
  }
  @override
  Future<Map<String, dynamic>> me() async {
    throw ApiException(status, 'Error de conexión/sesión de prueba');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.talaeats.app/native');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'readToken') return 'qa-valid-encrypted-token';
      if (call.method == 'initialUri') return null;
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('P0 red offline NO destruye el token cifrado durante restauración', () async {
    final api = _RestoreApi(0);
    final model = TalaModel(apiClient: api);
    await model.initialize();
    expect(model.signedIn, isFalse);
    expect(api.token, 'qa-valid-encrypted-token');
    expect(calls, isNot(contains('clearToken')));
    expect(model.lastError, contains('conexión'));
    model.dispose();
  });

  test('P0 HTTP 500 NO destruye sesión guardada', () async {
    final api = _RestoreApi(500);
    final model = TalaModel(apiClient: api);
    await model.initialize();
    expect(api.token, isNotNull);
    expect(calls, isNot(contains('clearToken')));
    model.dispose();
  });

  test('P0 HTTP 401 sí invalida la sesión local', () async {
    final api = _RestoreApi(401);
    final model = TalaModel(apiClient: api);
    await model.initialize();
    expect(api.token, isNull);
    expect(calls, contains('clearToken'));
    model.dispose();
  });

  test('P0 respuesta JSON fragmentada de tamaño permitido', () async {
    final s = Stream<List<int>>.fromIterable(<List<int>>[
      utf8.encode('{"status":'),
      utf8.encode('"ok"}'),
    ]);
    expect(await readBoundedUtf8Response(s, maxBytes: 128), '{"status":"ok"}');
  });

  test('P0 bloquea respuesta HTTP excesiva (evita consumo de memoria)', () async {
    final s = Stream<List<int>>.fromIterable(<List<int>>[
      List<int>.filled(7, 65),
      List<int>.filled(6, 66),
    ]);
    await expectLater(readBoundedUtf8Response(s, maxBytes: 10),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 502)));
  });

  test('P0 rechaza límite de respuesta inválido', () async {
    await expectLater(
      readBoundedUtf8Response(Stream<List<int>>.empty(), maxBytes: 0),
      throwsArgumentError,
    );
  });
}
