import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/core/controller.dart';
import 'package:talaeats_driver/core/mock_data.dart';
import 'package:talaeats_driver/core/theme.dart';
import 'package:talaeats_driver/main.dart';
import 'package:talaeats_driver/models/delivery.dart';
import 'package:talaeats_driver/models/driver_profile.dart';
import 'package:talaeats_driver/screens/proof_screen.dart';
import 'package:talaeats_driver/widgets/motion.dart';

import 'test_helpers.dart';

/// Pruebas del polish visual (no tocan la capa de producción).
void main() {
  DeliveryJob job({
    String id = 'TE-9100',
    DeliveryStage stage = DeliveryStage.assigned,
    String? phone,
    bool coords = false,
    DateTime? completedAt,
  }) =>
      DeliveryJob(
        id: id,
        restaurant: 'Restaurante Centro',
        restaurantAddress: 'Av. Principal 10, Tala, Jal.',
        restaurantLat: coords ? 20.65 : null,
        restaurantLng: coords ? -103.70 : null,
        customer: 'Cliente Prueba',
        customerAddress: 'Col. Centro, Tala, Jal.',
        customerPhone: phone,
        customerLat: coords ? 20.66 : null,
        customerLng: coords ? -103.71 : null,
        total: 210,
        earning: 42.5,
        distanceKm: 3.2,
        etaMinutes: 12,
        stage: stage,
        completedAt: completedAt,
      );

  /// Monta la app con un controlador local propio y sesión iniciada.
  Future<void> pumpWith(WidgetTester tester, DriverController c) async {
    addTearDown(c.dispose);
    await tester.pumpWidget(TalaEatsDriverApp(controller: c));
    await tester.pump();
    await tester.pumpAndSettle();
    unawaited(c.signIn(email: kTestEmail, password: kTestPassword));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(c.signedIn, isTrue);
  }

  /// Lleva la entrega mock a "esperando pedidos".
  Future<void> finishMockJob(WidgetTester tester, DriverController c) async {
    c.setOnline(true);
    c.beginRoute();
    c.arrivedRestaurant();
    c.confirmPickup();
    c.beginCustomerRoute();
    c.completeDelivery();
    await tester.pumpAndSettle();
    c.dismissCompleted();
    await tester.pumpAndSettle();
    expect(find.text('Esperando pedidos'), findsOneWidget);
  }

  testWidgets('new assignment gets a one-shot highlight and focus actions',
      (tester) async {
    setPhoneSize(tester, 390, 860);
    final c = await pumpSignedInApp(tester);
    await finishMockJob(tester, c);

    expect(c.assign(job(coords: true)), isTrue);
    await tester.pump();
    final flash = tester.widget<AttentionFlash>(
      find.byType(AttentionFlash).last,
    );
    expect(flash.active, isTrue);

    await tester.pumpAndSettle();
    expect(find.text('Nuevo pedido asignado'), findsOneWidget);
    expect(find.text('RECOGER EN'), findsOneWidget);
    expect(find.byKey(const Key('focus-navigate')), findsOneWidget);
    // Llamar solo aplica en la fase de entrega.
    expect(find.byKey(const Key('focus-call')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing job on connect is not announced', (tester) async {
    setPhoneSize(tester, 390, 860);
    final c = await pumpSignedInApp(tester);
    c.setOnline(true);
    await tester.pumpAndSettle();
    final flash = tester.widget<AttentionFlash>(find.byType(AttentionFlash));
    expect(flash.active, isFalse);
  });

  testWidgets('focus stop switches to customer with call action',
      (tester) async {
    setPhoneSize(tester, 390, 860);
    final c = await pumpSignedInApp(tester);
    await finishMockJob(tester, c);

    c.assign(job(id: 'TE-9200', phone: '33 1234 5678', coords: true));
    c.beginRoute();
    c.arrivedRestaurant();
    c.confirmPickup();
    await tester.pumpAndSettle();

    expect(find.text('ENTREGAR A'), findsOneWidget);
    expect(find.byKey(const Key('focus-call')), findsOneWidget);
    expect(find.byKey(const Key('focus-navigate')), findsOneWidget);
    expect(find.text('Recogido en Restaurante Centro'), findsOneWidget);
  });

  testWidgets('mock job without coordinates hides orientation actions',
      (tester) async {
    setPhoneSize(tester, 390, 860);
    final c = await pumpSignedInApp(tester);
    c.setOnline(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-navigate')), findsNothing);
    expect(find.byKey(const Key('focus-call')), findsNothing);
  });

  testWidgets('completed delivery counts up to the earning', (tester) async {
    setPhoneSize(tester, 390, 860);
    final c = await pumpSignedInApp(tester);
    c.setOnline(true);
    c.beginRoute();
    c.arrivedRestaurant();
    c.confirmPickup();
    c.beginCustomerRoute();
    c.completeDelivery();
    await tester.pumpAndSettle();
    expect(find.text('+\$47.50'), findsOneWidget);
    expect(find.text('Listo, seguir disponible'), findsOneWidget);
  });

  testWidgets('proof shows evidence step before PIN step', (tester) async {
    setPhoneSize(tester, 390, 860);
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

    final photoY = tester.getTopLeft(find.text('Foto de evidencia')).dy;
    final pinY = tester.getTopLeft(find.text('PIN del cliente')).dy;
    expect(photoY, lessThan(pinY));
    expect(find.text('Toma la foto e ingresa el PIN para continuar.'),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('attach-photo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('retake-photo')), findsOneWidget);
    expect(find.text('Falta el PIN del cliente.'), findsOneWidget);
  });

  testWidgets('history is grouped by day with day totals', (tester) async {
    setPhoneSize(tester, 390, 860);
    final now = DateTime(2026, 10, 10, 13);
    final c = DriverController.withData(
      clock: () => now,
      bootDelay: Duration.zero,
      authDelay: const Duration(milliseconds: 10),
      refreshDelay: const Duration(milliseconds: 10),
      profile: MockData.profile,
      history: [
        job(
          id: 'TE-1',
          stage: DeliveryStage.delivered,
          completedAt: now.subtract(const Duration(hours: 1)),
        ),
        job(
          id: 'TE-2',
          stage: DeliveryStage.delivered,
          completedAt: now.subtract(const Duration(days: 1)),
        ),
      ],
    );
    await pumpWith(tester, c);
    c.setTab(1);
    await tester.pumpAndSettle();

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);
    expect(find.text('\$42.50'), findsWidgets);
  });

  testWidgets('profile without documents is not shown as up to date',
      (tester) async {
    setPhoneSize(tester, 390, 860);
    final c = DriverController.withData(
      bootDelay: Duration.zero,
      authDelay: const Duration(milliseconds: 10),
      profile: const DriverProfile(
        firstName: 'Ana',
        fullName: 'Ana López',
        zone: 'Tala, Jalisco',
        vehicleType: 'Motocicleta',
        plateSuffix: '—',
        verified: false,
        documents: <DriverDocument>[],
      ),
    );
    await pumpWith(tester, c);
    c.setTab(3);
    await tester.pumpAndSettle();

    expect(find.text('En verificación'), findsOneWidget);
    expect(find.text('Sin documentos registrados'), findsOneWidget);
    expect(find.text('Motocicleta · Placa no registrada'), findsOneWidget);
    expect(find.text('Todos vigentes'), findsNothing);
  });
}
