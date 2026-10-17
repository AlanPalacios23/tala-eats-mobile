import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

const _shop = Restaurant(
  id: 999, name: 'Comercio QA', category: 'Comida local',
  rating: 4.9, eta: '20-30 min', deliveryFee: 15,
  image: '', description: '', delivery: true, pickup: true,
);
const _food = FoodItem(
  id: 12345, restaurantId: 999, name: 'Hamburguesa QA',
  description: 'Producto sintético', price: 260,
  image: '', category: 'Comida',
  imageUrl: 'https://example.invalid/photos/qa-product.jpg',
);

class _MockOrdersApi extends TalaApi {
  int orderReads = 0;
  @override
  Future<List<dynamic>> orders() async {
    orderReads++;
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 23, 'restaurant_id': 999, 'total': '333.20',
        'status': 'cancelled', 'order_type': 'delivery',
        'payment_status': 'pending', 'payment_method': 'stripe',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'menu_item_id': 12345, 'quantity': 2,
            'unit_price': '260.00',
            'name_snapshot': 'Hamburguesa QA',
            'options_snapshot': '',
          },
        ],
      },
    ];
  }
}

class _PendingPaymentApi extends TalaApi {
  int polls = 0;
  @override
  Future<Map<String, dynamic>> checkout(int id) async =>
    throw ApiException(503, 'Pasarela de prueba no disponible');
  @override
  Future<Map<String, dynamic>> liveOrder(int id) async {
    polls++;
    return <String, dynamic>{
      'order': <String, dynamic>{
        'id': id, 'restaurant_id': 999,
        'total': '333.20', 'status': 'received',
        'payment_status': 'pending', 'payment_method': 'mercadopago',
        'order_type': 'delivery', 'items': <dynamic>[],
      },
    };
  }
}

void main() {
  test('Ficha edita la cantidad existente, permite reducir a cero y no duplica',
    () {
      final model = TalaModel();
      model.restaurants.add(_shop);
      model.addToCart(_food, 2);
      expect(model.cart.single.quantity, 2);
      model.setCartItemQuantity(_food, 1);
      expect(model.cart.single.quantity, 1);
      model.setCartItemQuantity(_food, 3);
      expect(model.cart.single.quantity, 3);
      model.setCartItemQuantity(_food, 0);
      expect(model.cart, isEmpty);
      expect(model.cartRestaurantId, isNull);
      model.dispose();
    });

  test('Una orden sin image_url conserva foto catálogo en refresh sucesivo',
    () async {
      final api = _MockOrdersApi();
      final model = TalaModel(apiClient: api);
      model.restaurants.add(_shop);
      model.menu.add(_food);
      model.cart.add(CartLine(item: _food, quantity: 2));
      model.cartRestaurantId = 999;
      await model.refreshOrders();
      expect(model.orders.single.lines.single.item.imageUrl, _food.imageUrl);
      model.cart.clear();
      model.menu.clear();
      await model.refreshOrders();
      expect(model.orders.single.lines.single.item.imageUrl, _food.imageUrl);
      model.reorder(model.orders.single);
      expect(model.cart.single.item.imageUrl, _food.imageUrl);
      expect(model.cart.single.quantity, 2);
      model.dispose();
    });

  testWidgets('La navegación siempre da acceso al carrito cuando contiene productos',
    (tester) async {
      final model = TalaModel();
      model.restaurants.add(_shop);
      model.addToCart(_food, 2);
      await tester.pumpWidget(MaterialApp(
        theme: buildTalaTheme(),
        home: CustomerShell(model: model),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('global-cart-fab')), findsOneWidget);
      expect(find.textContaining('520'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    });

  testWidgets('Pago pendiente no tiene botón manual y consulta estado automáticamente',
    (tester) async {
      final api = _PendingPaymentApi();
      final model = TalaModel(apiClient: api);
      model.restaurants.add(_shop);
      final order = OrderEntry(
        id: 123, restaurant: _shop, total: 333.20,
        status: 'Pago pendiente', deliveryMode: 'delivery',
        paymentStatus: 'pending', paymentMethod: 'mercadopago',
        lines: <CartLine>[],
      );
      await tester.pumpWidget(MaterialApp(
        theme: buildTalaTheme(),
        home: PaymentStatusScreen(model: model, order: order),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Verificar pago'), findsNothing);
      expect(find.textContaining('se actualiza automáticamente'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
      expect(api.polls, greaterThanOrEqualTo(1));
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    });

  testWidgets('Pago en segundo plano no consulta; reanudar consulta backend',
    (tester) async {
      final api = _PendingPaymentApi();
      final model = TalaModel(apiClient: api);
      model.restaurants.add(_shop);
      final order = OrderEntry(
        id: 124, restaurant: _shop, total: 333.20,
        status: 'Pago pendiente', deliveryMode: 'delivery',
        paymentStatus: 'pending', paymentMethod: 'mercadopago',
        lines: <CartLine>[],
      );
      await tester.pumpWidget(MaterialApp(
        theme: buildTalaTheme(),
        home: PaymentStatusScreen(model: model, order: order),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final beforePause = api.polls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 17));
      expect(api.polls, beforePause, reason:
          'No consultar pedidos continuamente con Android en segundo plano');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(api.polls, greaterThan(beforePause),
          reason: 'Al volver, consultar solo el backend autoritativo');
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    });

}
