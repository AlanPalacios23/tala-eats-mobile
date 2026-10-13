import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/core/controller.dart';
import 'package:talaeats_driver/core/theme.dart';
import 'package:talaeats_driver/screens/login_screen.dart';
import 'package:talaeats_driver/screens/register_screen.dart';

Future<void> openDriverRegistration(WidgetTester tester) async {
  final createAccount = find.byKey(const Key('create-driver-account'));
  expect(createAccount, findsOneWidget);
  await tester.dragUntilVisible(
    createAccount,
    find.byType(Scrollable).first,
    const Offset(0, -180),
  );
  await tester.pumpAndSettle();
  await tester.tap(createAccount);
  await tester.pumpAndSettle();
  expect(find.text('Ser repartidor'), findsOneWidget);
}

void main() {
  testWidgets('new driver can create account application from login', (tester) async {
    final controller = DriverController(authDelay: Duration.zero);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: driverTheme(),
        home: LoginScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await openDriverRegistration(tester);
    expect(find.byKey(const Key('register-name')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('register-name')),
      'Repartidor Prueba',
    );
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'driver.test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-phone')),
      '3312345678',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'Driver123!',
    );

    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Solicitud enviada'), findsOneWidget);
    expect(find.textContaining('pendiente de aprobación'), findsOneWidget);
  });

  testWidgets('existing Tala Eats account can enter driver application mode',
      (tester) async {
    final controller = DriverController(authDelay: Duration.zero);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: driverTheme(),
        home: LoginScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await openDriverRegistration(tester);

    await tester.tap(find.byKey(const Key('register-mode-existing')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('register-name')), findsNothing);
    expect(find.byKey(const Key('register-otp')), findsOneWidget);
    expect(find.text('Enviar solicitud con mi cuenta'), findsOneWidget);
  });
  testWidgets('registration screen has no overflow at 320dp text x1.3',
      (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(320 * 3, 720 * 3);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final controller = DriverController(authDelay: Duration.zero);
    addTearDown(controller.dispose);

    // Esta prueba valida REGISTRO directamente. No depende del scroll del
    // Login ni de un tap previo que pueda quedar fuera del viewport.
    await tester.pumpWidget(
      MaterialApp(
        theme: driverTheme(),
        home: RegisterDriverScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ser repartidor'), findsOneWidget);
    expect(find.byKey(const Key('register-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Recorremos el formulario completo para forzar layout de la zona baja.
    final submit = find.byKey(const Key('register-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('login reaches registration at 320dp text x1.3', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(320 * 3, 720 * 3);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final controller = DriverController(authDelay: Duration.zero);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: driverTheme(),
        home: LoginScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await openDriverRegistration(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('register-submit')), findsOneWidget);
  });

  for (final width in <double>[320, 360]) {
    testWidgets('registration compact layout fits ${width.toInt()}dp text x1.3',
        (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = Size(width * 3, 720 * 3);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final controller = DriverController(authDelay: Duration.zero);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: driverTheme(),
          home: RegisterDriverScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('register-mode-existing')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final submit = find.byKey(const Key('register-submit'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

}
