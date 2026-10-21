import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  testWidgets('Alta blanca nombre > apellido > correo > clave > consentimiento',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: TalaStepAuthScreen(
        model: model, onBack: () {},
        initialMode: TalaEmailMode.signUp,
      ),
    ));
    await tester.pump();
    expect(find.text('¡Hola!\n¿Cuál es tu nombre?'), findsOneWidget);
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('stepNext'))).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey<String>('stepInput0')), 'María');
    await tester.tap(find.byKey(const ValueKey<String>('stepNext')));
    await tester.pump();
    expect(find.text('¿Cuál es tu apellido?'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey<String>('stepInput1')), 'López');
    await tester.tap(find.byKey(const ValueKey<String>('stepNext')));
    await tester.pump();
    expect(find.text('Por último, agrega tu\ncorreo electrónico'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey<String>('stepInput2')),
      'maria@example.com');
    await tester.tap(find.byKey(const ValueKey<String>('stepNext')));
    await tester.pump();
    expect(find.text('Crea tu contraseña\nde TALA EATS'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey<String>('stepInput3')), 'Segura123');
    await tester.tap(find.byKey(const ValueKey<String>('stepNext')));
    await tester.pumpAndSettle();
    expect(find.text('Términos y condiciones'), findsOneWidget);
    final FilledButton btnBefore = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('legalAccept')));
    expect(btnBefore.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey<String>('consentTerms')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('legalAccept'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey<String>('consentPrivacy')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('legalAccept'))).onPressed, isNotNull);
    // Never submit to production in widget tests.
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Inicio posterior usa solo correo y contraseña Tala Eats',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: TalaStepAuthScreen(model: model, onBack: () {}),
    ));
    await tester.pump();
    expect(find.text('Ingresa tu correo\npara iniciar sesión'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey<String>('stepInput0')),
      'maria@example.com');
    await tester.tap(find.byKey(const ValueKey<String>('stepNext')));
    await tester.pump();
    expect(find.text('Ingresa tu contraseña\npara iniciar sesión'),
      findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('stepBack')));
    await tester.pump();
    expect(find.text('Ingresa tu correo\npara iniciar sesión'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('El usuario puede cambiar inicio por registro sin red',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: TalaStepAuthScreen(model: model, onBack: () {}),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('switchMode')));
    await tester.pump();
    expect(find.text('¡Hola!\n¿Cuál es tu nombre?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('A 320dp y texto x1.3 registro permanece usable',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 720),
          textScaler: TextScaler.linear(1.3),
          accessibleNavigation: true,
          disableAnimations: true,
        ),
        child: TalaStepAuthScreen(
          model: model, onBack: () {},
          initialMode: TalaEmailMode.signUp,
        ),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('stepNext')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
