import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/screens/proof_screen.dart';
import 'package:talaeats_driver/widgets/motion.dart';

import 'test_helpers.dart';

void main() {
  // Anchos de referencia del brief (dp) y escalado de texto razonable.
  const widths = [320.0, 360.0, 390.0, 430.0];
  const scales = [1.0, 1.3];

  for (final width in widths) {
    for (final scale in scales) {
      testWidgets('no overflow at ${width.toInt()}dp, text x$scale',
          (tester) async {
        setPhoneSize(tester, width, 720);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final c = await pumpSignedInApp(tester);
        expect(tester.takeException(), isNull, reason: 'Inicio offline');

        c.setOnline(true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Pedido asignado');

        c.beginRoute();
        c.arrivedRestaurant();
        c.confirmPickup();
        c.beginCustomerRoute();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Ruta al cliente');

        for (var tab = 1; tab < 4; tab++) {
          c.setTab(tab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Pestaña $tab');
        }

        c.setTab(0);
        await tester.pumpAndSettle();
        await tapPrimaryCta(tester);
        expect(find.byType(ProofScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Prueba de entrega');

        await tester.enterText(find.byKey(const Key('pin-field')), '1234');
        await tester.ensureVisible(find.byKey(const Key('attach-photo')));
        await tester.tap(find.byKey(const Key('attach-photo')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Foto adjunta');

        await tester.tap(find.byKey(const Key('proof-complete')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Confirmación');

        await tester.tap(find.byKey(const Key('proof-confirm')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Entrega completada');
      });
    }
  }

  testWidgets('reduce motion: state changes are immediate', (tester) async {
    Widget host(String label) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: StateSwitcher(
                child: Text(label, key: ValueKey(label)),
              ),
            ),
          ),
        );

    await tester.pumpWidget(host('A'));
    await tester.pumpWidget(host('B'));
    await tester.pump();
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    // Sin desplazamiento: no queda ningún Transform intermedio activo.
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduce motion: Entrance renders child without transition',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Entrance(child: Text('Hola'))),
        ),
      ),
    );
    expect(find.text('Hola'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Entrance),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('reduce motion: full app stays usable', (tester) async {
    setPhoneSize(tester, 360, 760);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    final c = await pumpSignedInApp(tester);
    await tapPrimaryCta(tester);
    expect(c.online, isTrue);
    expect(find.text('Nuevo pedido asignado'), findsOneWidget);
    expect(find.text('Estás fuera de línea'), findsNothing);

    await tapPrimaryCta(tester);
    expect(find.text('Ve al restaurante'), findsOneWidget);
  });

  testWidgets('primary CTA ignores an accidental double tap', (tester) async {
    setPhoneSize(tester, 390);
    final c = await pumpSignedInApp(tester);
    c.setOnline(true);
    await tester.pumpAndSettle();

    final cta = find.byKey(const Key('primary-cta'));
    await tester.tap(cta);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(cta.last, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Solo avanzó una etapa (assigned → toRestaurant).
    expect(c.active!.stage.name, 'toRestaurant');
  });
}
