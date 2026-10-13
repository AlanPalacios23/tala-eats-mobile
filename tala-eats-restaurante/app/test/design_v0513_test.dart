// v0.5.13: estado de espera en comandas, cocina con franja de urgencia y
// nombre de quien recoge, detalle con teléfono copiable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/data/app_services.dart';
import 'package:talaeats_restaurant/data/local/qa_scenario.dart';
import 'package:talaeats_restaurant/data/repositories.dart';
import 'package:talaeats_restaurant/main.dart';
import 'package:talaeats_restaurant/models/entities.dart';
import 'package:talaeats_restaurant/screens/orders/order_widgets.dart';

class _FakeMedia implements MediaRepository {
  @override
  Future<String?> pickImage({
    required MediaSource source,
    required MediaPurpose purpose,
  }) async =>
      'test/fixtures/${purpose.name}.jpg';
}

RestaurantOrder _order({
  required String status,
  String type = 'delivery',
  int? driverId,
}) =>
    RestaurantOrder(
      id: 90,
      status: status,
      paymentMethod: 'card',
      paymentStatus: 'paid',
      total: 100,
      subtotal: 100,
      restaurantPayout: 85,
      address: 'Calle 2',
      notes: '',
      orderType: type,
      createdAt: DateTime(2026, 10, 12, 14),
      items: const <OrderLine>[],
      driverId: driverId,
      recipientName: 'Luis',
      recipientPhone: '33 0000 0000',
    );

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Finder _nav(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _launchAndSignIn(WidgetTester tester) async {
  await tester.pumpWidget(
    TalaEatsRestaurantApp(
      services: AppServices.local(
        latency: const LocalLatency(
          read: Duration(milliseconds: 40),
          write: Duration(milliseconds: 40),
        ),
        scenario: QaScenario.normal,
        media: _FakeMedia(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, _key('alreadyHaveAccountButton'));
  await tester.enterText(_key('loginEmail'), 'propietario@correo.mx');
  await tester.enterText(_key('loginPassword'), 'clave-segura');
  await _tap(tester, _key('loginSubmitButton'));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('estado de espera según status, tipo y repartidor', () {
    expect(
      orderWaitingLabel(_order(status: 'ready')),
      'Esperando repartidor',
    );
    expect(
      orderWaitingLabel(_order(status: 'ready', driverId: 7)),
      'Repartidor asignado, por recoger',
    );
    expect(
      orderWaitingLabel(_order(status: 'assigned', driverId: 7)),
      'Repartidor asignado, por recoger',
    );
    expect(
      orderWaitingLabel(_order(status: 'ready', type: 'pickup')),
      'Esperando al cliente',
    );
    expect(
      orderWaitingLabel(_order(status: 'on_the_way', driverId: 7)),
      'En camino con el repartidor',
    );
    expect(orderWaitingLabel(_order(status: 'preparing')), isNull);
    expect(orderWaitingLabel(_order(status: 'received')), isNull);
    expect(orderWaitingLabel(_order(status: 'delivered')), isNull);
  });

  testWidgets('pedido listo muestra en qué está la entrega', (tester) async {
    await _launchAndSignIn(tester);
    await tester.tap(_nav('Pedidos'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listos'));
    await tester.pumpAndSettle();
    expect(find.text('Repartidor asignado, por recoger'), findsOneWidget);
  });

  testWidgets('cocina muestra quién recoge', (tester) async {
    await _launchAndSignIn(tester);
    await tester.tap(_nav('Pedidos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir modo cocina'));
    await tester.pumpAndSettle();

    expect(find.text('Recoge: Ricardo Peña'), findsOneWidget);
  });

  testWidgets('detalle: línea de tiempo y teléfono copiable', (tester) async {
    await _launchAndSignIn(tester);
    await tester.tap(_nav('Pedidos'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('#1842'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido #1842'), findsOneWidget);
    expect(_key('orderTimeline'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byTooltip('Copiar teléfono'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byTooltip('Copiar teléfono'), findsOneWidget);
    expect(find.text('33 1111 9082'), findsOneWidget);
  });
}
