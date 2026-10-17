import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

class LoginOtpCaptureApi extends TalaApi {
  String lastOtp = '';
  int requests = 0;

  @override
  Future<Map<String, dynamic>> login(
      String email, String password, {String otp = ''}) async {
    requests++;
    lastOtp = otp;
    throw ApiException(401, 'Código de verificación 2FA requerido o inválido');
  }
}

void main() {
  testWidgets('Login muestra OTP editable y lo envía al backend, sin inventar autenticación',
      (WidgetTester tester) async {
    final api = LoginOtpCaptureApi();
    final model = TalaModel(apiClient: api);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: LoginScreen(model: model),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('login-otp')), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Términos y Condiciones'), findsOneWidget);
    expect(find.text('Aviso de Privacidad'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'qa@example.invalid');
    await tester.enterText(find.byType(TextField).at(1), 'ContraseñaQA123!');
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(api.requests, 1);
    expect(api.lastOtp, isEmpty);
    expect(find.textContaining('2FA requerido'), findsOneWidget);

    final otpField = find.byKey(const ValueKey<String>('login-otp'));
    await tester.ensureVisible(otpField);
    await tester.enterText(otpField, '12345');
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(api.requests, 1, reason: 'OTP parcial no debe consultar servidor');

    await tester.ensureVisible(otpField);
    await tester.enterText(otpField, '123456');
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(api.requests, 2);
    expect(api.lastOtp, '123456');
    expect(model.signedIn, false, reason: 'Solo backend puede aprobar 2FA');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Intro Flutter usa solo imagen original, sin animación ni barra de carga',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LaunchScreen()));
    expect(find.byType(Image), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName,
        'assets/branding/tala_intro.png');
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(TalaLogoMark), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Bootstrap exige 4 segundos y oculta glyph Android 12', () {
    final dart = File('lib/main.dart').readAsStringSync();
    final native = File('../ci/bootstrap_android.py').readAsStringSync();
    expect(dart, contains('Duration(seconds: 4)'));
    expect(native, contains('android:windowSplashScreenAnimatedIcon'));
    expect(native, contains('@android:color/transparent'));
    expect(File('assets/branding/tala_intro.png').existsSync(), true);
    expect(File('assets/branding/login_food.png').existsSync(), true);
  });
}
