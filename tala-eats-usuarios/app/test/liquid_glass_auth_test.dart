import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

/// Pure widget QA. No server calls, credentials, customers or payments.
void main() {
  testWidgets('Login y registro usan Liquid Glass sin cambiar sus formularios',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();

    for (final double width in <double>[320, 360, 390, 430]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;

      for (final bool register in <bool>[false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTalaTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 844),
                textScaler: const TextScaler.linear(1.3),
                viewInsets: const EdgeInsets.only(bottom: 240),
                disableAnimations: true,
                accessibleNavigation: true,
              ),
              child: register
                  ? SignUpScreen(model: model)
                  : LoginScreen(model: model),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(AuthLiquidBackdrop), findsOneWidget);
        expect(find.byType(AuthGlassCard), findsNWidgets(3));
        expect(find.byType(BackdropFilter), findsNWidgets(3));
        if (register) {
          expect(find.text('Crea tu cuenta'), findsOneWidget);
          expect(find.byType(TextField), findsNWidgets(4));
          expect(find.text('Continuar'), findsOneWidget);
          expect(find.text('Leer aviso de privacidad'), findsOneWidget);
        } else {
          expect(find.text('Bienvenido de vuelta'), findsOneWidget);
          expect(find.byType(TextField), findsNWidgets(2));
          expect(find.text('Iniciar sesión'), findsOneWidget);
          expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
        }
        expect(tester.takeException(), isNull,
            reason: 'Pantalla de acceso en ancho reducido y teclado simulado');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('El inicio de sesion mantiene el acceso a Crear cuenta',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: LoginScreen(model: model),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    final Finder link = find.text('Crear cuenta');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.byType(AuthLiquidBackdrop), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Recuperacion conserva el estilo y flujo originales',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: ForgotPasswordScreen(model: model),
    ));
    await tester.pump();
    expect(find.byType(AuthLiquidBackdrop), findsNothing);
    expect(find.byType(AuthGlassCard), findsNothing);
    expect(find.text('Recupera tu contraseña'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
