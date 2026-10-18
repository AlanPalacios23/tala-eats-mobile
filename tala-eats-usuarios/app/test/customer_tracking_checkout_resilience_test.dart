import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

const _shop = Restaurant(
  id: 811, name: 'Comercio de Tala', category: 'Comida',
  rating: 4.5, eta: '20 min', deliveryFee: 39,
  image: '', description: '', delivery: true, pickup: true,
);
const _item = FoodItem(
  id: 812, restaurantId: 811, name: 'Bolsa de fruta de 500 g',
  description: 'Presentación fija', price: 79, image: '', category: 'Frutería',
);
const _extra = FoodItem(
  id: 813, restaurantId: 811, name: 'Producto sin indicaciones',
  description: '', price: 20, image: '', category: 'Frutería',
);

class _ResilientApi extends TalaApi {
  int reads = 0;
  bool unavailable = true;

  @override
  Future<Map<String, dynamic>> liveOrder(int id) async {
    reads++;
    if (unavailable) throw ApiException(503, 'Sin red temporal');
    return <String, dynamic>{
      'order': <String, dynamic>{
        'id': id, 'restaurant_id': 811,
        'status': 'preparing', 'payment_status': 'pending',
        'payment_method': 'cash', 'order_type': 'delivery',
        'estimated_minutes': 18, 'total': 79,
        'items': <dynamic>[],
      },
    };
  }
}

void main() {
  testWidgets('Seguimiento muestra estado conocido en error y lo recupera con retry',
      (tester) async {
    final api = _ResilientApi();
    final model = TalaModel(apiClient: api)..restaurants.add(_shop);
    final order = OrderEntry(
      id: 411, restaurant: _shop, total: 79, status: 'Recibido',
      deliveryMode: 'delivery', eta: '20 min',
      rawStatus: 'received', lines: <CartLine>[],
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Temporary CI diagnostic: prints widget/constraints causing overflow.
      // Remove after fixing the actual layout.
      // ignore: avoid_print
      print('TRACKING_LAYOUT_DIAGNOSTIC: ${details.toString()}');
      previousHandler?.call(details);
    };
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: TrackingScreen(model: model, order: order),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(api.reads, greaterThanOrEqualTo(1));
    expect(find.text('No pudimos actualizar el seguimiento'), findsOneWidget);
    expect(find.textContaining('último estado conocido'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(order.status, 'Recibido',
      reason: 'Fallo de red no significa cancelación ni estado nuevo');
    final Object? renderException = tester.takeException();
    FlutterError.onError = previousHandler;
    expect(renderException, isNull);
    api.unavailable = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(api.reads, greaterThanOrEqualTo(2));
    expect(order.status, 'Preparando');
    expect(order.eta, '18 min');
    expect(find.text('No pudimos actualizar el seguimiento'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Checkout presenta cada nota real y conserva desglose 320–430dp',
      (tester) async {
    final model = TalaModel()..restaurants.add(_shop);
    model.addToCart(_item, 2,
      note: 'Seleccionar fruta madura para el pedido, por favor.');
    model.addToCart(_extra, 1);
    for (final width in <double>[320, 360, 390, 430]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 850);
      await tester.pumpWidget(MaterialApp(
        theme: buildTalaTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(body: AnimatedBuilder(
            animation: model,
            builder: (context, _) => ListView(
              children: <Widget>[SummaryCard(model: model)],
            ),
          )),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('Nota: Seleccionar fruta madura'), findsOneWidget);
      expect(find.text('Producto sin indicaciones'), findsOneWidget);
      expect(find.text('Total de referencia'), findsOneWidget);
      expect(find.textContaining('Nota: Producto sin indicaciones'), findsNothing);
      expect(tester.takeException(), isNull,
        reason: 'Resumen y notas sin desbordes a ${width}dp x1.3');
    }
    model.setCartItemQuantity(_item, 2, note: '');
    await tester.pump();
    expect(find.textContaining('Nota: Seleccionar fruta madura'), findsNothing,
      reason: 'La nota eliminada no puede seguir en la confirmación');
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
