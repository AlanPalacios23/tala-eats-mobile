import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/production_api.dart';

// Tests de seguridad P0: MethodChannel falso; nunca llama servicios externos.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.talaeats.app/native');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'readToken') return 'TOKEN-QA';
      if (call.method == 'openUrl') return null;
      if (call.method == 'writeToken') return null;
      if (call.method == 'clearToken') return null;
      throw MissingPluginException('QA unsupported '+call.method);
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('P0 API de Usuarios usa HTTPS y elimina barras finales', () {
    final api = TalaApi(baseUrl: 'https://example.test/api/v1///');
    expect(api.baseUrl, 'https://example.test/api/v1');
    expect(kProductionApiBase, startsWith('https://'));
  });

  test('P0 bloquea apertura de checkout HTTP antes de invocar Android', () async {
    await expectLater(
      NativeBridge.openExternal('http://example.test/payments'),
      throwsA(isA<ApiException>()),
    );
    expect(calls, isEmpty);
  });

  test('P0 permite abrir URL HTTPS mediante canal nativo', () async {
    await NativeBridge.openExternal('https://example.test/checkout');
    expect(calls, hasLength(1));
    expect(calls.single.method, 'openUrl');
    expect(calls.single.arguments, <String, dynamic>{'url': 'https://example.test/checkout'});
  });

  test('P0 errores al guardar token NO se ocultan como autenticación correcta', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'writeToken') {
        throw PlatformException(code: 'STORE_FAILED', message: 'Keystore no disponible');
      }
      return null;
    });
    await expectLater(
      NativeBridge.writeToken('TOKEN-QA'),
      throwsA(isA<ApiException>()),
    );
  });

  test('P0 lee y elimina token solo mediante Android seguro', () async {
    expect(await NativeBridge.readToken(), 'TOKEN-QA');
    await NativeBridge.clearToken();
    expect(calls.map((c) => c.method).toList(), <String>['readToken', 'clearToken']);
  });
}
