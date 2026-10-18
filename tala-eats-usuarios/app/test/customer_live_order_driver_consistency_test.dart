import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

const _shop = Restaurant(
  id: 424, name: 'Comercio de Tala', category: 'Comida local',
  rating: 0, eta: '30 minutos', deliveryFee: 39,
  image: '', description: '',
);

OrderEntry _order() => OrderEntry(
  id: 1701, restaurant: _shop, total: 119, status: 'Recibido',
  rawStatus: 'received', deliveryMode: 'delivery', eta: '30 min',
  paymentStatus: 'pending', lines: <CartLine>[],
);

Map<String, dynamic> _live({
  int id = 1701,
  String status = 'picked_up',
  bool includeDriver = true,
  bool? assigned = true,
  bool includePin = true,
  String pin = '7462',
}) => <String, dynamic>{
  'order': <String, dynamic>{
    'id': id,
    'restaurant_id': 424,
    'total': 119,
    'status': status,
    'order_type': 'delivery',
    'payment_status': 'paid',
    'payment_method': 'cash',
    'estimated_minutes': 12,
    'items': <dynamic>[],
    if (includeDriver)
      'driver_info': assigned == true
          ? <String, dynamic>{
              'name': 'Repartidor confirmado',
              'vehicle': 'Moto',
              'rating': 4.9,
            }
          : null,
    if (includePin) 'delivery_pin': pin,
  },
};

class _LiveOrdersApi extends TalaApi {
  Map<String, dynamic> next = _live();

  @override
  Future<Map<String, dynamic>> liveOrder(int id) async => next;
}

void main() {
  test('Live actualiza repartidor y PIN; payload parcial no borra datos vigentes',
      () async {
    final api = _LiveOrdersApi();
    final model = TalaModel(apiClient: api)..restaurants.add(_shop);
    final order = _order();
    await model.refreshOrder(order);
    expect(order.driverName, 'Repartidor confirmado');
    expect(order.driverVehicle, 'Moto');
    expect(order.driverRating, 4.9);
    expect(order.pin, '7462');
    expect(order.status, 'En camino');
    expect(order.paymentStatus, 'paid');
    expect(order.eta, '12 min');

    api.next = _live(includeDriver: false, includePin: false);
    await model.refreshOrder(order);
    expect(order.driverName, 'Repartidor confirmado');
    expect(order.pin, '7462');

    api.next = _live(assigned: false, pin: '');
    await model.refreshOrder(order);
    expect(order.driverName, isEmpty);
    expect(order.driverVehicle, isEmpty);
    expect(order.driverRating, 0);
    expect(order.pin, isEmpty);
    model.dispose();
  });

  test('Pedido live ajeno es rechazado sin mutar historial visible', () async {
    final api = _LiveOrdersApi()..next = _live(id: 1702);
    final model = TalaModel(apiClient: api)..restaurants.add(_shop);
    final order = _order();
    await expectLater(model.refreshOrder(order),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)));
    expect(order.id, 1701);
    expect(order.status, 'Recibido');
    expect(order.pin, isEmpty);
    expect(order.driverName, isEmpty);
    model.dispose();
  });

  testWidgets('Seguimiento completado oculta PIN; pedido activo lo muestra',
      (tester) async {
    tester.view.physicalSize = const Size(390, 920);
    tester.view.devicePixelRatio = 1;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final model = TalaModel()..restaurants.add(_shop);
    final order = _order()..pin = '7462';
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: TrackingScreen(model: model, order: order),
    ));
    await tester.pump();
    expect(find.text('PIN de entrega'), findsOneWidget);
    order.status = 'Entregado';
    order.rawStatus = 'delivered';
    model.notifyListeners();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('PIN de entrega'), findsNothing);
    expect(find.text('Finalizado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
