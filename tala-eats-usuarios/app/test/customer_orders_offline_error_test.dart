import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

class OrdersOfflineApi extends TalaApi {
  bool failing = true;
  int queries = 0;

  @override
  Future<List<dynamic>> orders() async {
    queries++;
    if (failing) throw ApiException(503, 'Servicio temporalmente no disponible');
    return <dynamic>[];
  }
}

const Restaurant sampleMerchant = Restaurant(
  id: 88, name: 'Comercio de prueba',
  category: 'Comida local', rating: 4.5, eta: '25 min',
  deliveryFee: 35, image: '', description: '',
);

OrderEntry sampleOrder() => OrderEntry(
  id: 880, restaurant: sampleMerchant,
  status: 'Preparando', rawStatus: 'preparing',
  total: 120, eta: '25 min', deliveryMode: 'delivery',
  lines: <CartLine>[],
);

void main() {
  test('Fallo al cargar historial conserva pedidos previos y muestra error',
      () async {
    final api = OrdersOfflineApi();
    final model = TalaModel(apiClient: api);
    model.orders.add(sampleOrder());
    await model.refreshOrders();
    expect(model.orders.length, 1,
        reason: 'Un GET fallido no demuestra que el usuario no tiene pedidos.');
    expect(model.ordersLoadError, isNotEmpty);
    expect(model.ordersRefreshing, false);
    api.failing = false;
    await model.refreshOrders();
    expect(model.ordersLoadError, isEmpty);
    expect(model.orders, isEmpty,
        reason: 'Un GET correcto con [] confirma el estado vacío.');
    expect(api.queries, 2);
    model.dispose();
  });

  testWidgets('Pedidos con fallo de red: reintenta sin pantalla vacía ni POST',
      (WidgetTester tester) async {
    final api = OrdersOfflineApi();
    final model = TalaModel(apiClient: api);
    await model.refreshOrders();
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: AnimatedBuilder(
            animation: model,
            builder: (BuildContext context, Widget? child) =>
                OrdersScreen(model: model),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar tus pedidos'), findsOneWidget);
    expect(find.text('Aún no tienes pedidos'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(tester.takeException(), isNull);

    api.failing = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no tienes pedidos'), findsOneWidget);
    expect(find.text('No pudimos cargar tus pedidos'), findsNothing);
    expect(model.ordersLoadError, isEmpty);
    expect(api.queries, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
