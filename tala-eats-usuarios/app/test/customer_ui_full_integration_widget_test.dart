import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

class _CustomerWidgetApi extends TalaApi {
  @override
  Future<List<Map<String, dynamic>>> customerDevices() async =>
      <Map<String, dynamic>>[
        <String, dynamic>{'id': 7, 'device_label': 'Android QA',
          'active': true, 'current': true, 'platform': 'android'},
      ];

  @override
  Future<List<Map<String, dynamic>>> orderSubstitutions(int id) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 14, 'order_id': id, 'status': 'pending',
          'replacement_menu_item_id': 50,
          'message': 'No queda el producto solicitado',
          'original_amount': '100.00', 'replacement_amount': '95.00',
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> orderRefunds(int id) async =>
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 22, 'amount': '5.00', 'status': 'pending',
          'provider': 'stripe', 'reason': 'Sustitución',
        },
      ];
}

Restaurant _shop() => const Restaurant(
  id: 1, name: 'Tienda de prueba', category: 'Restaurante',
  rating: 4.5, eta: '20 min', deliveryFee: 35,
  image: '', description: 'Sin datos reales',
);

void main() {
  testWidgets('Pantalla principal y selector accesible en 320/360/390/430dp',
      (WidgetTester tester) async {
    final model = TalaModel(apiClient: _CustomerWidgetApi());
    for (final width in <double>[320, 360, 390, 430]) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(body: HomeScreen(model: model)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Comprar en Tala'), findsOneWidget);
      expect(find.text('Restaurantes y comercios'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Home debe soportar $width dp con texto ampliado');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Selector muestra mercados, no cambia localidad sin acción',
      (WidgetTester tester) async {
    final model = TalaModel(apiClient: _CustomerWidgetApi());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Center(child: CustomerMarketSelector(model: model))),
    ));
    await tester.tap(find.text('Comprar en Tala'));
    await tester.pumpAndSettle();
    expect(find.text('¿Dónde quieres comprar?'), findsOneWidget);
    expect(find.text('Tala'), findsWidgets);
    expect(model.marketCode, 'TALA-JAL');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Seguridad lista dispositivos reportados por backend mock',
      (WidgetTester tester) async {
    final model = TalaModel(apiClient: _CustomerWidgetApi());
    await tester.pumpWidget(MaterialApp(
      home: CustomerDeviceSessionsScreen(model: model),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Android QA'), findsOneWidget);
    expect(find.text('Este teléfono'), findsOneWidget);
    expect(find.text('Cerrar todas las demás'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Pedido muestra sustitución y reembolso sin afirmar fondos liquidados',
      (WidgetTester tester) async {
    final model = TalaModel(apiClient: _CustomerWidgetApi());
    final order = OrderEntry(
      id: 71, restaurant: _shop(), total: 249, status: 'En camino',
      deliveryMode: 'delivery', lines: <CartLine>[],
    );
    await tester.pumpWidget(MaterialApp(
      home: CustomerOrderAdjustmentsScreen(model: model, order: order),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No queda el producto solicitado'), findsOneWidget);
    expect(find.textContaining('pendiente'), findsWidgets);
    expect(find.text('Aceptar reemplazo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
