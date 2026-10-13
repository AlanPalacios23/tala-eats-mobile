import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/core/controller.dart';
import 'package:talaeats_driver/main.dart';

/// Credenciales de prueba con formato válido (solo existen en tests).
const String kTestEmail = 'prueba@ejemplo.com';
const String kTestPassword = 'contrasena-segura';

/// Controlador con esperas locales mínimas para pruebas.
DriverController testController({DateTime Function()? clock}) =>
    DriverController(
      clock: clock,
      bootDelay: Duration.zero,
      authDelay: const Duration(milliseconds: 10),
      refreshDelay: const Duration(milliseconds: 10),
    );

/// Simula una pantalla de teléfono de [width] x [height] dp.
void setPhoneSize(WidgetTester tester, double width, [double height = 800]) {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(width * 3, height * 3);
  addTearDown(tester.view.reset);
}

/// Monta la app y llega al login (boot local completado).
Future<DriverController> pumpLogin(WidgetTester tester) async {
  final controller = testController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(TalaEatsDriverApp(controller: controller));
  await tester.pump();
  await tester.pumpAndSettle();
  return controller;
}

/// Monta la app con sesión iniciada en Inicio.
Future<DriverController> pumpSignedInApp(WidgetTester tester) async {
  final controller = await pumpLogin(tester);
  unawaited(controller.signIn(email: kTestEmail, password: kTestPassword));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pumpAndSettle();
  expect(controller.signedIn, isTrue);
  return controller;
}

/// Toca el CTA principal de Inicio y espera a que terminen las transiciones.
Future<void> tapPrimaryCta(WidgetTester tester) async {
  final cta = find.byKey(const Key('primary-cta'));
  expect(cta, findsOneWidget);
  await tester.tap(cta);
  await tester.pumpAndSettle();
}

/// `onPressed` del FilledButton dentro de un [PrimaryButton] con [key].
VoidCallback? primaryOnPressed(WidgetTester tester, Key key) =>
    tester
        .widget<FilledButton>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed;
