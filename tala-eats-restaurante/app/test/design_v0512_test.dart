// v0.5.12: alerta de pedidos nuevos, línea de tiempo del pedido, cobro en
// caja, menú agrupado por categoría y búsqueda en el historial.

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
  String status = 'preparing',
  String type = 'delivery',
  String payment = 'card',
  String paymentStatus = 'paid',
}) =>
    RestaurantOrder(
      id: 77,
      status: status,
      paymentMethod: payment,
      paymentStatus: paymentStatus,
      total: 150,
      subtotal: 120,
      restaurantPayout: 102,
      address: 'Calle 1',
      notes: '',
      orderType: type,
      createdAt: DateTime(2026, 10, 12, 14),
      items: const <OrderLine>[],
      driverId: null,
      recipientName: 'Ana',
      recipientPhone: '',
    );

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Finder _nav(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

Finder _categoryHeaders() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('menuCategory-'),
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

  group('línea de tiempo del pedido', () {
    test('pasos según estado y tipo de pedido', () {
      expect(orderTimelineSteps(_order()), hasLength(6));
      expect(orderTimelineSteps(_order(type: 'pickup')), hasLength(5));
      expect(orderTimelineIndex(_order(status: 'received')), 0);
      expect(orderTimelineIndex(_order(status: 'confirmed')), 1);
      expect(orderTimelineIndex(_order(status: 'preparing')), 2);
      expect(orderTimelineIndex(_order(status: 'ready')), 3);
      expect(orderTimelineIndex(_order(status: 'assigned')), 3);
      expect(orderTimelineIndex(_order(status: 'on_the_way')), 4);
      expect(orderTimelineIndex(_order(status: 'delivered')), 5);
      expect(
        orderTimelineIndex(_order(status: 'delivered', type: 'pickup')),
        4,
      );
      expect(orderTimelineIndex(_order(status: 'cancelled')), -1);
    });

    Future<void> pumpTimeline(
      WidgetTester tester,
      RestaurantOrder order,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: OrderTimeline(order: order))),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra paso actual y siguiente', (tester) async {
      await pumpTimeline(tester, _order());
      expect(find.text('Paso 3 de 6'), findsOneWidget);
      expect(find.text('En preparación'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);

      await pumpTimeline(tester, _order(status: 'assigned'));
      expect(find.text('Listo · repartidor asignado'), findsOneWidget);

      await pumpTimeline(tester, _order(status: 'cancelled'));
      expect(find.text('Pedido cancelado'), findsOneWidget);
      expect(find.textContaining('Paso'), findsNothing);
    });
  });

  test('cobro en caja solo para recoger + efectivo sin pagar', () {
    expect(
      collectsCashAtCounter(
        _order(type: 'pickup', payment: 'cash', paymentStatus: 'pending'),
      ),
      isTrue,
    );
    expect(
      collectsCashAtCounter(_order(type: 'pickup', payment: 'cash')),
      isFalse,
    );
    expect(
      collectsCashAtCounter(
        _order(payment: 'cash', paymentStatus: 'pending'),
      ),
      isFalse,
    );
    expect(
      collectsCashAtCounter(
        _order(type: 'pickup', paymentStatus: 'pending'),
      ),
      isFalse,
    );
  });

  testWidgets('alerta de pedidos nuevos fuera de Inicio y Pedidos',
      (tester) async {
    await _launchAndSignIn(tester);

    // Inicio ya muestra los pendientes: sin alerta duplicada.
    expect(_key('incomingOrdersBanner'), findsNothing);

    await tester.tap(_nav('Menú'));
    await tester.pumpAndSettle();
    expect(_key('incomingOrdersBanner'), findsOneWidget);
    expect(find.text('2 pedidos nuevos esperan respuesta'), findsOneWidget);

    await tester.tap(_key('incomingOrdersBanner'));
    await tester.pumpAndSettle();
    expect(_key('incomingOrdersBanner'), findsNothing);
    expect(_key('orderAction-1842'), findsOneWidget);
  });

  testWidgets('menú agrupado por categoría y lista plana al buscar',
      (tester) async {
    await _launchAndSignIn(tester);
    await tester.tap(_nav('Menú'));
    await tester.pumpAndSettle();

    expect(_categoryHeaders(), findsWidgets);
    expect(_key('menuCategory-Bebidas'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'taco');
    await tester.pumpAndSettle();
    expect(_categoryHeaders(), findsNothing);
  });

  testWidgets('historial: búsqueda por folio sin resultados y limpiar',
      (tester) async {
    await _launchAndSignIn(tester);
    await tester.tap(_nav('Pedidos'));
    await tester.pumpAndSettle();

    // El chip Historial estaba construido pero quedaba parcialmente fuera
    // del viewport (centro en x=788). scrollUntilVisible lo consideraba
    // visible sin poder pulsarlo. Desplazamos el carrusel de filtros primero.
    final horizontalFilters = find.byWidgetPredicate(
      (widget) => widget is Scrollable &&
          (widget.axisDirection == AxisDirection.right ||
           widget.axisDirection == AxisDirection.left),
    );
    expect(horizontalFilters, findsOneWidget);
    await tester.drag(horizontalFilters, const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(find.text('Historial').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Historial').hitTestable());
    await tester.pumpAndSettle();
    expect(_key('ordersHistorySearch'), findsOneWidget);
    final mainScroll = find.descendant(
      of: find.byType(CustomScrollView).first,
      matching: find.byType(Scrollable),
    ).first;

    await tester.enterText(_key('ordersHistorySearch'), '#1831');
    await tester.pumpAndSettle();
    // Los pedidos se construyen con SliverList: desplazamiento real.
    await tester.scrollUntilVisible(
      _key('order-1831'), 140.0,
      scrollable: mainScroll,
      maxScrolls: 20,
    );
    await tester.pumpAndSettle();
    expect(_key('order-1831'), findsOneWidget);
    expect(_key('order-1828'), findsNothing);

    await tester.enterText(_key('ordersHistorySearch'), '99999');
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados para "99999"'), findsOneWidget);

    final clearSearch = find.text('Limpiar búsqueda');
    // El estado vacío tiene scroll propio en viewport de altura reducida.
    await tester.ensureVisible(clearSearch);
    await tester.pumpAndSettle();
    expect(clearSearch.hitTestable(), findsOneWidget);
    await tester.tap(clearSearch.hitTestable());
    await tester.pumpAndSettle();
    // Prueba el efecto de pulsar: consulta vacía, se retira el estado vacío
    // y se reconstruyen los pedidos. No se oculta un error con warnIfMissed.
    final search = tester.widget<TextField>(_key('ordersHistorySearch'));
    expect(search.controller!.text, isEmpty);
    expect(find.text('Sin resultados para "99999"'), findsNothing);
    await tester.scrollUntilVisible(
      _key('order-1831'), 120.0,
      scrollable: mainScroll,
      maxScrolls: 20,
    );
    await tester.pumpAndSettle();
    expect(_key('order-1831'), findsOneWidget);
    await tester.scrollUntilVisible(
      _key('order-1828'),
      150.0,
      scrollable: mainScroll,
      maxScrolls: 14,
    );
    expect(_key('order-1828'), findsOneWidget);
  });
}
