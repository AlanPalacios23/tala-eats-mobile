import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

/// Este QA no utiliza Kali ni envía mensajes. El chat compartido heredado
/// nunca debe activarse desde la nueva UI del cliente.
class _DriverChatQaApi extends TalaApi {
  int assignedDriverId = 0;
  String driverName = '';
  String orderStatus = 'ready';
  int sharedChatRequests = 0;

  @override
  Future<Map<String, dynamic>> liveOrder(int orderId) async => <String, dynamic>{
        'order': <String, dynamic>{
          'id': orderId,
          'restaurant_id': 8,
          'status': orderStatus,
          'order_type': 'delivery',
          'payment_method': 'cash',
          'payment_status': 'pending',
          'driver_id': assignedDriverId == 0 ? null : assignedDriverId,
          'driver_info': assignedDriverId == 0
              ? null
              : <String, dynamic>{
                  'id': assignedDriverId,
                  'name': driverName,
                  'vehicle': 'Motocicleta',
                  'rating': '4.9',
                },
        },
      };

  @override
  Future<dynamic> get(String path) async {
    if (path.contains('/chat')) sharedChatRequests++;
    throw StateError('QA sin solicitudes GET externas: $path');
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    if (path.contains('/chat')) sharedChatRequests++;
    throw StateError('QA sin solicitudes POST externas: $path');
  }
}

const Restaurant _restaurant = Restaurant(
  id: 8,
  name: 'Restaurante QA',
  category: 'Comida',
  rating: 4.5,
  eta: '25 min',
  deliveryFee: 35,
  image: '',
  description: '',
);

OrderEntry _order({
  String mode = 'delivery',
  String status = 'ready',
  int driverId = 0,
  String name = '',
}) =>
    OrderEntry(
      id: 321,
      restaurant: _restaurant,
      total: 249,
      status: status == 'delivered' ? 'Entregado' : 'Listo',
      deliveryMode: mode,
      lines: <CartLine>[],
      rawStatus: status,
      driverId: driverId,
      driverName: name,
    );

void main() {
  test('Chat solo cuando el backend asigna repartidor y el pedido está activo', () {
    expect(_order().canContactDriver, isFalse);
    expect(_order(mode: 'pickup', driverId: 7).canContactDriver, isFalse);
    expect(_order(driverId: 7).canContactDriver, isTrue);
    expect(_order(driverId: 7, status: 'delivered').canContactDriver, isFalse);
    expect(_order(driverId: 7, status: 'cancelled').canContactDriver, isFalse);
  });

  test('Actualizar seguimiento refleja asignación, nombre y desasignación', () async {
    final _DriverChatQaApi api = _DriverChatQaApi();
    final TalaModel model = TalaModel(apiClient: api);
    final OrderEntry order = _order();

    await model.refreshOrder(order);
    expect(order.canContactDriver, isFalse);

    api.assignedDriverId = 45;
    api.driverName = 'María';
    api.orderStatus = 'assigned';
    await model.refreshOrder(order);
    expect(order.driverId, 45);
    expect(order.driverName, 'María');
    expect(order.driverVehicle, 'Motocicleta');
    expect(order.canContactDriver, isTrue);

    api.assignedDriverId = 0;
    api.driverName = '';
    api.orderStatus = 'ready';
    await model.refreshOrder(order);
    expect(order.driverId, 0);
    expect(order.driverName, isEmpty);
    expect(order.canContactDriver, isFalse);
    expect(api.sharedChatRequests, 0);
    model.dispose();
  });

  testWidgets('Sin repartidor, seguimiento no ofrece chat', (WidgetTester tester) async {
    final _DriverChatQaApi api = _DriverChatQaApi();
    final TalaModel model = TalaModel(apiClient: api);
    await tester.pumpWidget(MaterialApp(home: TrackingScreen(model: model, order: _order())));
    await tester.pump();
    expect(find.text('Ver chat con mi repartidor'), findsNothing);
    expect(find.text('Buscando repartidor'), findsOneWidget);
    expect(api.sharedChatRequests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Asignado abre vista previa sin enviar al comercio', (WidgetTester tester) async {
    final _DriverChatQaApi api = _DriverChatQaApi()
      ..assignedDriverId = 45
      ..driverName = 'María'
      ..orderStatus = 'assigned';
    final TalaModel model = TalaModel(apiClient: api);
    final OrderEntry order = _order(driverId: 45, status: 'assigned', name: 'María');

    await tester.pumpWidget(MaterialApp(home: TrackingScreen(model: model, order: order)));
    await tester.pump();
    final Finder action = find.text('Ver chat con mi repartidor');
    expect(action, findsOneWidget);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Chat con tu repartidor'), findsOneWidget);
    expect(find.text('Chat privado pendiente de activación en el backend.'), findsOneWidget);
    final TextField composer = tester.widget<TextField>(find.byType(TextField));
    expect(composer.enabled, isFalse);
    expect(api.sharedChatRequests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Recoger en restaurante no muestra chat de repartidor', (WidgetTester tester) async {
    final _DriverChatQaApi api = _DriverChatQaApi()..assignedDriverId = 45;
    final TalaModel model = TalaModel(apiClient: api);
    final OrderEntry order = _order(mode: 'pickup', driverId: 45);
    await tester.pumpWidget(MaterialApp(home: TrackingScreen(model: model, order: order)));
    await tester.pump();
    expect(find.text('Ver chat con mi repartidor'), findsNothing);
    expect(find.text('Buscando repartidor'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
