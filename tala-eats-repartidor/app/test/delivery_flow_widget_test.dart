import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/core/controller.dart';
import 'package:talaeats_driver/core/theme.dart';
import 'package:talaeats_driver/models/delivery.dart';
import 'package:talaeats_driver/screens/proof_screen.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('full delivery flow from offline to waiting', (tester) async {
    setPhoneSize(tester, 412, 915);
    final c = await pumpSignedInApp(tester);

    // Offline: CTA principal "Conectarme".
    expect(find.text('Estás fuera de línea'), findsOneWidget);
    await tapPrimaryCta(tester);
    expect(c.online, isTrue);
    expect(find.text('Nuevo pedido asignado'), findsOneWidget);

    // Etapas con CTA único y feedback por etapa.
    await tapPrimaryCta(tester);
    expect(c.active!.stage, DeliveryStage.toRestaurant);
    expect(find.text('Ve al restaurante'), findsOneWidget);

    await tapPrimaryCta(tester);
    expect(c.active!.stage, DeliveryStage.atRestaurant);

    await tapPrimaryCta(tester);
    expect(c.active!.stage, DeliveryStage.pickedUp);

    await tapPrimaryCta(tester);
    expect(c.active!.stage, DeliveryStage.toCustomer);
    expect(find.text('En camino al cliente'), findsOneWidget);

    // Prueba de entrega.
    await tapPrimaryCta(tester);
    expect(find.byType(ProofScreen), findsOneWidget);
    expect(primaryOnPressed(tester, const Key('proof-complete')), isNull);

    await tester.enterText(find.byKey(const Key('pin-field')), '1234');
    await tester.pumpAndSettle();
    expect(primaryOnPressed(tester, const Key('proof-complete')), isNull);

    await tester.ensureVisible(find.byKey(const Key('attach-photo')));
    await tester.tap(find.byKey(const Key('attach-photo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('photo-attached')), findsOneWidget);
    expect(primaryOnPressed(tester, const Key('proof-complete')), isNotNull);

    final earningsBefore = c.todayEarnings;
    await tester.tap(find.byKey(const Key('proof-complete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('proof-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('proof-confirm')));
    await tester.pumpAndSettle();

    // Éxito discreto en Inicio y acreditación única.
    expect(find.byType(ProofScreen), findsNothing);
    expect(c.active!.stage, DeliveryStage.delivered);
    expect(c.todayEarnings, earningsBefore + c.active!.earning);
    expect(find.text('Entrega completada'), findsWidgets);

    await tapPrimaryCta(tester);
    expect(c.active, isNull);
    expect(find.text('Esperando pedidos'), findsOneWidget);
  });

  testWidgets('availability is locked during a route', (tester) async {
    setPhoneSize(tester, 390);
    final c = await pumpSignedInApp(tester);
    c.setOnline(true);
    c.beginRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('availability-switch')), findsNothing);
    expect(find.text('En ruta'), findsOneWidget);

    await tester.tap(find.text('Entrega en curso'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lock-notice')), findsOneWidget);
    expect(c.online, isTrue);
  });

  testWidgets('logout is blocked during a route', (tester) async {
    setPhoneSize(tester, 390);
    final c = await pumpSignedInApp(tester);
    c.setOnline(true);
    c.beginRoute();
    c.setTab(3);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('logout')));
    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout-blocked')), findsOneWidget);
    expect(c.signedIn, isTrue);
  });

  testWidgets('proof CTA requires PIN of 4 digits AND evidence',
      (tester) async {
    setPhoneSize(tester, 360, 760);
    final c = testController();
    addTearDown(c.dispose);
    c.setOnline(true);
    c.beginRoute();
    c.arrivedRestaurant();
    c.confirmPickup();
    c.beginCustomerRoute();

    await tester.pumpWidget(
      MaterialApp(theme: driverTheme(), home: ProofScreen(controller: c)),
    );
    await tester.pumpAndSettle();
    const complete = Key('proof-complete');
    expect(primaryOnPressed(tester, complete), isNull);

    await tester.enterText(find.byKey(const Key('pin-field')), '12');
    await tester.pumpAndSettle();
    expect(primaryOnPressed(tester, complete), isNull);

    await tester.ensureVisible(find.byKey(const Key('attach-photo')));
    await tester.tap(find.byKey(const Key('attach-photo')));
    await tester.pumpAndSettle();
    expect(primaryOnPressed(tester, complete), isNull, reason: 'PIN parcial');

    await tester.enterText(find.byKey(const Key('pin-field')), '12ab34');
    await tester.pumpAndSettle();
    expect(primaryOnPressed(tester, complete), isNotNull, reason: 'solo dígitos');

    await tester.ensureVisible(find.byKey(const Key('remove-photo')));
    await tester.tap(find.byKey(const Key('remove-photo')));
    await tester.pumpAndSettle();
    expect(primaryOnPressed(tester, complete), isNull, reason: 'sin foto');
    expect(c.active!.stage, DeliveryStage.toCustomer);
  });

  testWidgets('bottom navigation switches tabs and back returns to Inicio',
      (tester) async {
    setPhoneSize(tester, 390);
    final c = await pumpSignedInApp(tester);

    Finder navItem(String label) => find
        .descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        )
        .first;

    await tester.tap(navItem('Ganancias'));
    await tester.pumpAndSettle();
    expect(c.tabIndex, 2);
    expect(find.text('TU GANANCIA DE HOY'), findsOneWidget);

    await tester.tap(navItem('Entregas'));
    await tester.pumpAndSettle();
    expect(c.tabIndex, 1);

    // Botón "atrás" del sistema: vuelve a Inicio en lugar de salir.
    final observer =
        tester.state(find.byType(WidgetsApp)) as WidgetsBindingObserver;
    await observer.didPopRoute();
    await tester.pumpAndSettle();
    expect(c.tabIndex, 0);
  });

  testWidgets('order details separate earnings from order total',
      (tester) async {
    setPhoneSize(tester, 390);
    final c = await pumpSignedInApp(tester);
    c.setOnline(true);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Detalles'));
    await tester.tap(find.text('Detalles'));
    await tester.pumpAndSettle();
    expect(find.text('Tu ganancia'), findsOneWidget);
    expect(find.text('Total del pedido'), findsOneWidget);
    expect(find.textContaining('no forma parte'), findsOneWidget);
  });

  testWidgets('history states: empty, loading skeleton and error',
      (tester) async {
    setPhoneSize(tester, 390);
    final c = await pumpSignedInApp(tester);
    c.setTab(1);
    await tester.pumpAndSettle();
    expect(find.text('Historial'), findsOneWidget);

    c.setHistoryStatus(LoadStatus.error);
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar tus entregas'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(c.historyStatus, LoadStatus.loading);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(c.historyStatus, LoadStatus.ready);
  });

  testWidgets('PIN field only accepts digits', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinInput(
            controller: controller,
            focusNode: focus,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('pin-field')), '9a8b7c6d5');
    await tester.pump();
    expect(controller.text, '9876');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('pin-field')))
          .keyboardType,
      TextInputType.number,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('pin-field')))
          .inputFormatters,
      contains(isA<FilteringTextInputFormatter>()),
    );
  });
}
