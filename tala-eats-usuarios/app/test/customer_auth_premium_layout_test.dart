import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  testWidgets('Login premium responsive conserva CTA y accesos legales a 320dp',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 700),
          textScaler: TextScaler.linear(1.3),
        ),
        child: LoginScreen(model: model),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('auth-hero-title')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('auth-surface')), findsOneWidget);
    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.textContaining('2FA'), findsNothing);
    final legal = find.text('Aviso de Privacidad');
    await tester.ensureVisible(legal);
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Registro premium mantiene inputs, términos y botón continuar',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: SignUpScreen(model: model),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('auth-surface')), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Leer términos'), findsOneWidget);
    expect(find.text('Leer aviso de privacidad'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
