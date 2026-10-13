import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/main.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('app reaches secure login shell', (tester) async {
    final controller = testController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(TalaEatsDriverApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Entra y empieza tu ruta.'), findsOneWidget);
    expect(find.text('repartidor@talaeats.mx'), findsNothing);
  });

  testWidgets('login has no prefilled credentials and gates the CTA',
      (tester) async {
    setPhoneSize(tester, 412, 915);
    final controller = await pumpLogin(tester);

    final email = tester.widget<TextFormField>(
      find.byKey(const Key('login-email')),
    );
    final password = tester.widget<TextFormField>(
      find.byKey(const Key('login-password')),
    );
    expect(email.controller!.text, isEmpty);
    expect(password.controller!.text, isEmpty);
    expect(primaryOnPressed(tester, const Key('login-submit')), isNull);

    await tester.enterText(find.byKey(const Key('login-email')), 'malo');
    await tester.enterText(find.byKey(const Key('login-password')), '123');
    await tester.pump();
    expect(primaryOnPressed(tester, const Key('login-submit')), isNotNull);

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Revisa el formato del correo.'), findsOneWidget);
    expect(find.text('Debe tener al menos 8 caracteres.'), findsOneWidget);
    expect(controller.signedIn, isFalse);
    expect(controller.authenticating, isFalse);
  });

  testWidgets('valid login shows loading and reaches Inicio', (tester) async {
    setPhoneSize(tester, 412, 915);
    final controller = await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login-email')), kTestEmail);
    await tester.enterText(
      find.byKey(const Key('login-password')),
      kTestPassword,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(controller.authenticating, isTrue);
    expect(find.text('Entrando…'), findsOneWidget);
    expect(primaryOnPressed(tester, const Key('login-submit')), isNull);

    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(controller.signedIn, isTrue);
    expect(find.text('Hola, Alex'), findsOneWidget);
  });
}
