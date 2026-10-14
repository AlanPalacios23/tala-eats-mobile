import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

const Restaurant _testRestaurant = Restaurant(
  id: 21,
  name: 'Comida local',
  category: 'Cocina',
  rating: 4.7,
  eta: '25 min',
  deliveryFee: 35,
  image: '',
  description: '',
);

OrderEntry _order({
  String status = 'confirmed',
  String mode = 'delivery',
  String paymentMethod = 'cash',
  String paymentStatus = 'pending',
  int driverId = 0,
  double? driverLat,
  double? driverLng,
  double? deliveryLat,
  double? deliveryLng,
}) =>
    OrderEntry(
      id: 123,
      restaurant: _testRestaurant,
      total: 120,
      status: status == 'delivered' ? 'Entregado' : 'Confirmado',
      rawStatus: status,
      deliveryMode: mode,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      driverId: driverId,
      driverLat: driverLat,
      driverLng: driverLng,
      deliveryLat: deliveryLat,
      deliveryLng: deliveryLng,
      lines: <CartLine>[],
    );

class _LocationApiFake extends TalaApi {
  int driverId = 0;
  double? lat;
  double? lng;
  String status = 'confirmed';

  @override
  Future<Map<String, dynamic>> liveOrder(int orderId) async => <String, dynamic>{
        'order': <String, dynamic>{
          'id': orderId,
          'restaurant_id': 21,
          'status': status,
          'order_type': 'delivery',
          'payment_method': 'cash',
          'payment_status': 'pending',
          'delivery_lat': 20.6534,
          'delivery_lng': -103.704,
          'driver_id': driverId == 0 ? null : driverId,
          'driver_info': driverId == 0 ? null : <String, dynamic>{
            'id': driverId,
            'name': 'Repartidor de prueba',
            'current_lat': lat,
            'current_lng': lng,
          },
        },
      };
}

void main() {
  test('GPS rechaza ausencias, NaN, infinito y coordenadas fuera de rango', () {
    expect(validTrackingCoordinates(null, -103.70), false);
    expect(validTrackingCoordinates(20.65, null), false);
    expect(validTrackingCoordinates(double.nan, -103.7), false);
    expect(validTrackingCoordinates(20.65, double.infinity), false);
    expect(validTrackingCoordinates(91, -103.7), false);
    expect(validTrackingCoordinates(20.65, -181), false);
    expect(validTrackingCoordinates(0, 0), false);
    expect(validTrackingCoordinates(20.65, -103.7), true);
  });

  test('Mapa solo después de confirmar, no en pickup, cancelado o entregado', () {
    expect(_order(status: 'received').canShowTrackingMap, false);
    expect(_order().canShowTrackingMap, true);
    expect(_order(status: 'preparing').canShowTrackingMap, true);
    expect(_order(status: 'assigned').canShowTrackingMap, true);
    expect(_order(status: 'on_the_way').canShowTrackingMap, true);
    expect(_order(mode: 'pickup').canShowTrackingMap, false);
    expect(_order(status: 'cancelled').canShowTrackingMap, false);
    expect(_order(status: 'delivered').canShowTrackingMap, false);
    expect(_order(paymentMethod: 'stripe', paymentStatus: 'pending').canShowTrackingMap, false);
  });

  test('Ubicación del repartidor exige asignación del pedido y lat/lng válidos', () {
    expect(_order(driverLat: 20.66, driverLng: -103.71).hasDriverCoordinates, false);
    expect(_order(driverId: 43, driverLat: 20.66).hasDriverCoordinates, false);
    expect(_order(driverId: 43, driverLat: 20.66, driverLng: -103.71).hasDriverCoordinates, true);
    expect(_order(deliveryLat: 20.65, deliveryLng: -103.70).hasDeliveryCoordinates, true);
    expect(_order(deliveryLat: 20.65, deliveryLng: -190).hasDeliveryCoordinates, false);
  });

  test('Seguimiento lee GPS real, cambios y desasignación desde backend', () async {
    final _LocationApiFake api = _LocationApiFake();
    final TalaModel model = TalaModel(apiClient: api);
    model.restaurants.add(_testRestaurant);
    final OrderEntry order = _order();

    await model.refreshOrder(order);
    expect(order.hasDeliveryCoordinates, true);
    expect(order.hasDriverCoordinates, false);

    api.driverId = 43;
    api.lat = 20.662;
    api.lng = -103.708;
    api.status = 'assigned';
    await model.refreshOrder(order);
    expect(order.driverId, 43);
    expect(order.driverLat, 20.662);
    expect(order.driverLng, -103.708);
    expect(order.hasDriverCoordinates, true);

    api.lat = 20.661;
    api.lng = -103.706;
    api.status = 'on_the_way';
    await model.refreshOrder(order);
    expect(order.driverLat, 20.661);
    expect(order.driverLng, -103.706);

    api.driverId = 0;
    api.lat = null;
    api.lng = null;
    api.status = 'ready';
    await model.refreshOrder(order);
    expect(order.driverId, 0);
    expect(order.hasDriverCoordinates, false);
    model.dispose();
  });

  testWidgets('Confirmado sin GPS muestra estado de espera, no dibuja ubicación falsa', (WidgetTester tester) async {
    final TalaModel model = TalaModel(apiClient: _LocationApiFake());
    final OrderEntry order = _order();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DriverTrackingMap(order: order)),
    ));
    await tester.pump();

    expect(find.text('Mapa de tu entrega'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('tracking-map-no-coordinates')), findsOneWidget);
    expect(find.text('Esperando coordenadas verificadas del pedido.'), findsOneWidget);
    expect(find.text('GPS disponible'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Pedido sin confirmar oculta mapa completo', (WidgetTester tester) async {
    final OrderEntry order = _order(status: 'received', deliveryLat: 20.65, deliveryLng: -103.7);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DriverTrackingMap(order: order)),
    ));
    expect(find.text('Mapa de tu entrega'), findsNothing);
    expect(find.byKey(const ValueKey<String>('tracking-map-no-coordinates')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
