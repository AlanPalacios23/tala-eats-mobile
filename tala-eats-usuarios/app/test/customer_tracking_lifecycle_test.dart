import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

const _restaurant = Restaurant(
  id: 701, name: 'Comercio local de prueba', category: 'Comida',
  rating: 0, eta: '30 minutos', deliveryFee: 39,
  image: '', description: '',
);

class _TrackingApi extends TalaApi {
  int reads = 0;

  @override
  Future<Map<String, dynamic>> liveOrder(int id) async {
    reads++;
    return <String, dynamic>{
      'order': <String, dynamic>{
        'id': id,
        'restaurant_id': 701,
        'total': '120.00',
        'status': 'received',
        'payment_status': 'pending',
        'payment_method': 'cash',
        'order_type': 'delivery',
        'items': <dynamic>[],
      },
    };
  }
}

void main() {
  testWidgets('Seguimiento consulta en primer plano, pausa al salir y reanuda al volver',
      (tester) async {
    final api = _TrackingApi();
    final model = TalaModel(apiClient: api)..restaurants.add(_restaurant);
    final order = OrderEntry(
      id: 901, restaurant: _restaurant, total: 120,
      status: 'Recibido', rawStatus: 'received',
      deliveryMode: 'delivery', eta: '30 minutos',
      lines: <CartLine>[],
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: TrackingScreen(model: model, order: order),
      ),
    ));
    await tester.pump();
    expect(api.reads, greaterThanOrEqualTo(1));
    expect(find.text('Estado automático'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('no ubicación GPS en tiempo real'), 180,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('no ubicación GPS en tiempo real'), findsOneWidget);
    expect(find.text('En vivo'), findsNothing);
    await tester.pump(const Duration(seconds: 9));
    final readsBeforePause = api.reads;
    expect(readsBeforePause, greaterThanOrEqualTo(2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 25));
    expect(api.reads, readsBeforePause,
        reason: 'No consultar el backend periódicamente en segundo plano');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.reads, greaterThan(readsBeforePause),
        reason: 'Actualizar al volver al primer plano');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
