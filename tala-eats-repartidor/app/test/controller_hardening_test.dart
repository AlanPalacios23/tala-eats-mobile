import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/core/controller.dart';
import 'package:talaeats_driver/core/mock_data.dart';
import 'package:talaeats_driver/core/validators.dart';
import 'package:talaeats_driver/models/delivery.dart';

DriverController _controller({DateTime Function()? clock}) => DriverController(
      clock: clock,
      bootDelay: Duration.zero,
      authDelay: Duration.zero,
      refreshDelay: Duration.zero,
    );

/// Lleva la entrega activa hasta "En camino al cliente".
void _toCustomer(DriverController c) {
  expect(c.setOnline(true), isTrue);
  expect(c.beginRoute(), isTrue);
  expect(c.arrivedRestaurant(), isTrue);
  expect(c.confirmPickup(), isTrue);
  expect(c.beginCustomerRoute(), isTrue);
}

void main() {
  group('delivery flow guards (v0.2.0 conservados)', () {
    test('cannot begin route while offline', () {
      final c = _controller();
      expect(c.beginRoute(), isFalse);
      expect(c.active!.stage, DeliveryStage.assigned);
    });

    test('cannot go offline during an active delivery', () {
      final c = _controller();
      expect(c.setOnline(true), isTrue);
      expect(c.beginRoute(), isTrue);
      expect(c.setOnline(false), isFalse);
      expect(c.online, isTrue);
    });

    test('can go offline while only assigned (route not started)', () {
      final c = _controller();
      c.setOnline(true);
      expect(c.deliveryInProgress, isFalse);
      expect(c.setOnline(false), isTrue);
      expect(c.online, isFalse);
    });

    test('a completed delivery is credited only once', () {
      final c = _controller();
      _toCustomer(c);
      final earningsBefore = c.todayEarnings;
      final deliveriesBefore = c.todayDeliveries;
      final historyBefore = c.history.length;

      expect(c.completeDelivery(), isTrue);
      expect(c.completeDelivery(), isFalse);
      expect(c.todayEarnings, earningsBefore + c.active!.earning);
      expect(c.todayDeliveries, deliveriesBefore + 1);
      expect(c.history.length, historyBefore + 1);
      expect(c.history.first.id, c.active!.id);
    });

    test('transitions only accept the expected previous stage', () {
      final c = _controller();
      c.setOnline(true);
      // Fuera de orden desde "assigned".
      expect(c.arrivedRestaurant(), isFalse);
      expect(c.confirmPickup(), isFalse);
      expect(c.beginCustomerRoute(), isFalse);
      expect(c.completeDelivery(), isFalse);
      expect(c.active!.stage, DeliveryStage.assigned);

      expect(c.beginRoute(), isTrue);
      expect(c.beginRoute(), isFalse);
      expect(c.confirmPickup(), isFalse);
      expect(c.active!.stage, DeliveryStage.toRestaurant);
    });

    test('full sequence follows the business order', () {
      final c = _controller();
      final seen = <DeliveryStage>[c.active!.stage];
      c.setOnline(true);
      c.beginRoute();
      seen.add(c.active!.stage);
      c.arrivedRestaurant();
      seen.add(c.active!.stage);
      c.confirmPickup();
      seen.add(c.active!.stage);
      c.beginCustomerRoute();
      seen.add(c.active!.stage);
      c.completeDelivery();
      seen.add(c.active!.stage);
      expect(seen, DeliveryStage.values);
      expect(c.active!.completedAt, isNotNull);
    });
  });

  group('navigation', () {
    test('setTab ignores invalid indices', () {
      final c = _controller();
      c.setTab(-1);
      c.setTab(kTabCount);
      c.setTab(99);
      expect(c.tabIndex, 0);
      c.setTab(2);
      expect(c.tabIndex, 2);
    });
  });

  group('session', () {
    test('signIn rejects invalid formats without entering loading', () async {
      final c = _controller();
      expect(await c.signIn(email: 'no-es-correo', password: '12345678'),
          isFalse);
      expect(await c.signIn(email: 'a@b.co', password: 'corta'), isFalse);
      expect(c.authenticating, isFalse);
      expect(c.signedIn, isFalse);
    });

    test('signIn accepts valid formats locally', () async {
      final c = _controller();
      expect(await c.signIn(email: 'a@b.co', password: '12345678'), isTrue);
      expect(c.signedIn, isTrue);
      expect(c.authenticating, isFalse);
    });

    test('logout is blocked during an active delivery', () async {
      final c = _controller();
      await c.signIn(email: 'a@b.co', password: '12345678');
      c.setOnline(true);
      c.beginRoute();
      expect(c.logout(), isFalse);
      expect(c.signedIn, isTrue);
      expect(c.online, isTrue);
    });

    test('logout resets availability and tab when allowed', () async {
      final c = _controller();
      await c.signIn(email: 'a@b.co', password: '12345678');
      c.setOnline(true);
      c.setTab(3);
      expect(c.logout(), isTrue);
      expect(c.signedIn, isFalse);
      expect(c.online, isFalse);
      expect(c.tabIndex, 0);
    });
  });

  group('proof of delivery', () {
    test('rejects proof outside the correct stage', () {
      final c = _controller();
      c.setOnline(true);
      expect(
        c.submitProof(pin: '1234', evidenceAttached: true),
        ProofResult.wrongStage,
      );
      expect(c.active!.stage, DeliveryStage.assigned);
    });

    test('requires a 4-digit PIN and evidence', () {
      final c = _controller();
      _toCustomer(c);
      for (final pin in ['', '12', '123', '12a4', '12345', ' 1 2']) {
        expect(
          c.submitProof(pin: pin, evidenceAttached: true),
          ProofResult.invalidPin,
          reason: 'PIN "$pin"',
        );
      }
      expect(
        c.submitProof(pin: '1234', evidenceAttached: false),
        ProofResult.missingEvidence,
      );
      expect(c.active!.stage, DeliveryStage.toCustomer);
    });

    test('completes once and never double-credits', () {
      final c = _controller();
      _toCustomer(c);
      final before = c.todayEarnings;
      expect(
        c.submitProof(pin: '1234', evidenceAttached: true),
        ProofResult.completed,
      );
      expect(
        c.submitProof(pin: '1234', evidenceAttached: true),
        ProofResult.wrongStage,
      );
      expect(c.todayEarnings, before + MockData.activeJob.earning);
    });

    test('PIN validator', () {
      expect(Validators.isPin('0000'), isTrue);
      expect(Validators.isPin('9876'), isTrue);
      expect(Validators.isPin('987'), isFalse);
      expect(Validators.isPin('abcd'), isFalse);
    });
  });

  group('assignment lifecycle (integration hooks)', () {
    const next = DeliveryJob(
      id: 'TE-9001',
      restaurant: 'Restaurante',
      restaurantAddress: 'Dirección',
      customer: 'Cliente',
      customerAddress: 'Destino',
      total: 100,
      earning: 30,
      distanceKm: 2,
      etaMinutes: 8,
      stage: DeliveryStage.assigned,
    );

    test('dismissCompleted only works after delivery', () {
      final c = _controller();
      expect(c.dismissCompleted(), isFalse);
      _toCustomer(c);
      expect(c.dismissCompleted(), isFalse);
      c.completeDelivery();
      expect(c.dismissCompleted(), isTrue);
      expect(c.active, isNull);
    });

    test('assign requires session, availability and no active job', () async {
      final c = _controller();
      expect(c.assign(next), isFalse);
      await c.signIn(email: 'a@b.co', password: '12345678');
      expect(c.assign(next), isFalse, reason: 'fuera de línea');
      c.setOnline(true);
      expect(c.assign(next), isFalse, reason: 'ya hay entrega activa');

      _toCustomerFromAssigned(c);
      c.completeDelivery();
      c.dismissCompleted();
      expect(c.assign(next), isTrue);
      expect(c.active!.id, 'TE-9001');
    });

    test('assign rejects an already credited delivery', () async {
      final c = _controller();
      await c.signIn(email: 'a@b.co', password: '12345678');
      _toCustomer(c);
      c.completeDelivery();
      c.dismissCompleted();
      expect(c.assign(MockData.activeJob), isFalse);
    });

    test('cannot go offline while a newly assigned job is in route', () async {
      final c = _controller();
      await c.signIn(email: 'a@b.co', password: '12345678');
      _toCustomer(c);
      c.completeDelivery();
      c.dismissCompleted();
      expect(c.assign(next), isTrue);
      expect(c.beginRoute(), isTrue);
      expect(c.setOnline(false), isFalse);
    });
  });

  group('earnings model', () {
    test('mock day totals are coherent with history', () {
      final c = _controller();
      final sum = c.history.fold<double>(0, (s, j) => s + j.earning);
      expect(c.todayEarnings, closeTo(sum, 0.001));
      expect(c.todayDeliveries, c.history.length);
      expect(c.averagePerDelivery, closeTo(sum / c.history.length, 0.001));
    });

    test('order totals never mix with driver earnings', () {
      final c = _controller();
      _toCustomer(c);
      final earnings = c.todayEarnings;
      final orders = c.todayOrdersTotal;
      c.completeDelivery();
      expect(c.todayEarnings, earnings + MockData.activeJob.earning);
      expect(c.todayOrdersTotal, orders + MockData.activeJob.total);
    });

    test('week uses live value for today and null for future days', () {
      // Miércoles 7 de octubre de 2026 → índice 2.
      final c = _controller(clock: () => DateTime(2026, 10, 7, 13));
      final week = c.weekEarnings;
      expect(c.todayIndex, 2);
      expect(week[0], MockData.weekEarnings[0]);
      expect(week[2], c.todayEarnings);
      expect(week.sublist(3), everyElement(isNull));
    });
  });

  group('lifecycle', () {
    test('dispose cancels pending local waits', () async {
      final c = DriverController(bootDelay: const Duration(seconds: 5));
      final boot = c.bootstrap();
      c.dispose();
      // No debe lanzar ni notificar después de dispose.
      expect(boot, isA<Future<void>>());
    });

    test('refreshHistory goes loading → ready', () async {
      final c = _controller();
      final future = c.refreshHistory();
      expect(c.historyStatus, LoadStatus.loading);
      await future;
      expect(c.historyStatus, LoadStatus.ready);
    });
  });
}

void _toCustomerFromAssigned(DriverController c) {
  expect(c.beginRoute(), isTrue);
  expect(c.arrivedRestaurant(), isTrue);
  expect(c.confirmPickup(), isTrue);
  expect(c.beginCustomerRoute(), isTrue);
}
