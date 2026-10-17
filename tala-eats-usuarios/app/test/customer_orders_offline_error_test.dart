import 'dart:async';
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

class DelayedOrdersApi extends TalaApi {
  final Completer<List<dynamic>> pending = Completer<List<dynamic>>();

  @override
  Future<List<dynamic>> orders() => pending.future;

  @override
  Future<dynamic> post(String path, [Object? body]) async =>
      <String, dynamic>{};
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


class BootstrapOrdersApi extends TalaApi {
  bool failingOrders = true;
  int errorStatus = 503;
  Completer<List<dynamic>>? delayedOrders;

  @override
  Future<List<dynamic>> orders() async {
    if (delayedOrders != null) return delayedOrders!.future;
    if (failingOrders) {
      throw ApiException(errorStatus, 'Pedidos temporalmente no disponibles');
    }
    return <dynamic>[];
  }

  @override
  Future<Map<String, dynamic>> bootstrap() async => <String, dynamic>{
        'user': <String, dynamic>{
          'id': 88, 'name': 'Cliente de prueba', 'role': 'customer',
        },
        'wallet': <String, dynamic>{'balance': 0, 'points': 0},
        'unread_notifications': 0,
      };

  @override
  Future<List<dynamic>> restaurantsForMarket(String code) async =>
      <dynamic>[
        <String, dynamic>{
          'id': 88, 'name': 'Comercio local de prueba',
          'market_code': code, 'cuisine': 'Comida local',
          'is_open': true, 'eta_min': 20,
        }
      ];

  @override
  Future<List<dynamic>> addresses() async => <dynamic>[];

  @override
  Future<List<dynamic>> favorites() async => <dynamic>[];

  @override
  Future<Map<String, dynamic>> wallet() async =>
      <String, dynamic>{'balance': 0, 'points': 0, 'transactions': <dynamic>[]};

  @override
  Future<List<dynamic>> notifications() async => <dynamic>[];

  @override
  Future<Map<String, dynamic>> privacy() async =>
      <String, dynamic>{'marketing_opt_in': false};

  @override
  Future<dynamic> get(String path) async {
    if (path == '/platform/promotions' || path == '/platform/coupons') {
      return <dynamic>[];
    }
    if (path == '/platform/loyalty') {
      return <String, dynamic>{'points': 0, 'wallet_balance': 0};
    }
    if (path == '/orders/payment-methods') {
      return <String, dynamic>{'methods': <dynamic>[]};
    }
    throw StateError('GET inesperado: $path');
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async =>
      <String, dynamic>{};
}

void main() {
  test('Consulta tardía nunca revive historial después de logout', () async {
    final api = DelayedOrdersApi();
    final model = TalaModel(apiClient: api);
    model.orders.add(sampleOrder());
    final Future<void> stale = model.refreshOrders();
    expect(model.ordersRefreshing, true);
    await model.logout();
    api.pending.complete(<dynamic>[
      <String, dynamic>{'id': 880, 'status': 'preparing'},
    ]);
    await stale;
    expect(model.orders, isEmpty);
    expect(model.ordersLoadError, isEmpty);
    expect(model.ordersRefreshing, false);
    model.dispose();
  });

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

  test('Bootstrap: pedidos 503 no oculta catálogo, preserva historial y permite recuperación', () async {
    final api = BootstrapOrdersApi();
    final model = TalaModel(apiClient: api);
    model.orders.add(sampleOrder());

    await model.refreshAll();
    expect(model.loading, false);
    expect(model.restaurants.single.name, 'Comercio local de prueba');
    expect(model.userName, 'Cliente de prueba');
    expect(model.orders.single.id, 880,
        reason: 'Un 503 en /orders/mine no equivale a una lista vacía.');
    expect(model.ordersLoadError, isNotEmpty);
    expect(model.lastError, isEmpty,
        reason: 'Catálogo y otras secciones sí cargaron correctamente.');

    api.failingOrders = false;
    await model.refreshAll();
    expect(model.orders, isEmpty,
        reason: 'Solo el GET exitoso con [] puede vaciar el historial.');
    expect(model.ordersLoadError, isEmpty);
    expect(model.restaurants.single.id, 88);
    model.dispose();
  });

  test('Bootstrap: respuesta después de logout no revive catálogos ni pedidos', () async {
    final api = BootstrapOrdersApi()
      ..delayedOrders = Completer<List<dynamic>>();
    final model = TalaModel(apiClient: api);
    final Future<void> oldBootstrap = model.refreshAll();
    expect(model.loading, true);

    await model.logout();
    expect(model.loading, false);
    api.delayedOrders!.complete(<dynamic>[
      <String, dynamic>{'id': 100, 'restaurant_id': 88},
    ]);
    await oldBootstrap;
    expect(model.loading, false);
    expect(model.restaurants, isEmpty);
    expect(model.orders, isEmpty);
    expect(model.ordersLoadError, isEmpty);
    model.dispose();
  });

  test('Bootstrap: un 401 en pedidos no se disfraza de historial vacío', () async {
    final api = BootstrapOrdersApi()..errorStatus = 401;
    final model = TalaModel(apiClient: api);
    await model.refreshAll();
    expect(model.restaurants, isEmpty);
    expect(model.orders, isEmpty);
    expect(model.lastError, 'Pedidos temporalmente no disponibles');
    expect(model.ordersLoadError, isEmpty,
        reason: '401 debe pasar por el camino de error de autenticación.');
    model.dispose();
  });

}
