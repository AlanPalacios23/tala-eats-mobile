import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

class _EffectiveMenuWinsApi extends TalaApi {
  @override
  Future<Map<String, dynamic>> restaurant(int id) async => <String, dynamic>{
        'id': id,
        'menu_items': <dynamic>[],
      };

  @override
  Future<dynamic> get(String path) async {
    if (path == '/v9/restaurants/501/effective-menu') {
      return <String, dynamic>{
        'restaurant_id': 501,
        'items': <dynamic>[
          <String, dynamic>{
            'id': 5011,
            'name': 'La Gran Doble Smash con Tocino',
            'category': 'Especialidades',
            'base_price': '260.00',
            'effective_price': '260.00',
            'available_now': true,
            'stock': 30,
          },
          <String, dynamic>{
            'id': 5012,
            'name': 'BURGER SUPER STAR',
            'category': 'Especialidades',
            'base_price': '230.00',
            'effective_price': '230.00',
            'available_now': true,
            'stock': 30,
          },
        ],
      };
    }
    return <String, dynamic>{};
  }
}

class _DetailMenuFallbackApi extends TalaApi {
  @override
  Future<Map<String, dynamic>> restaurant(int id) async => <String, dynamic>{
        'id': id,
        'menu_items': <dynamic>[
          <String, dynamic>{
            'id': 5021,
            'restaurant_id': id,
            'name': 'Producto desde detalle',
            'description': 'Fallback QA',
            'category': 'General',
            'price': '99.00',
            'is_available': true,
            'stock': 4,
          },
        ],
      };

  @override
  Future<dynamic> get(String path) async {
    if (path == '/v9/restaurants/502/effective-menu') {
      throw ApiException(503, 'effective-menu no disponible');
    }
    return <String, dynamic>{};
  }
}


// Checkout tests use an isolated payment-methods response; no live network calls.
// The screen refreshes these capabilities in initState, so setting booleans
// directly on TalaModel before pumpWidget does not reliably test the contract.
class _CheckoutPaymentMethodsQaApi extends TalaApi {
  _CheckoutPaymentMethodsQaApi({required this.cash, required this.mercadoPago, required this.stripe});

  final bool cash;
  final bool mercadoPago;
  final bool stripe;
  int refreshCalls = 0;

  @override
  Future<dynamic> get(String path) async {
    if (path != '/orders/payment-methods') {
      throw StateError('Unexpected QA API request: $path');
    }
    refreshCalls++;
    return <String, dynamic>{
      'commercial_pricing_version': '1.5.2',
      'service_fee_rate': '0.07',
      'delivery_base_fee': '39.00',
      'methods': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'cash', 'enabled': cash},
        <String, dynamic>{'id': 'mercadopago', 'enabled': mercadoPago},
        <String, dynamic>{'id': 'stripe', 'enabled': stripe},
      ],
    };
  }
}

class _PendingStripeOrderApi extends TalaApi {
  bool cancelCalled = false;

  Map<String, dynamic> _order({String status = 'received'}) => <String, dynamic>{
        'id': 7001,
        'restaurant_id': 700,
        'total': '139.00',
        'status': status,
        'order_type': 'delivery',
        'estimated_minutes': 30,
        'payment_status': 'pending',
        'payment_method': 'stripe',
        'items': <dynamic>[
          <String, dynamic>{
            'menu_item_id': 70001,
            'name_snapshot': 'Hamburguesa Stripe QA',
            'unit_price': '100.00',
            'quantity': 1,
            'options_snapshot': '',
          },
        ],
      };

  @override
  Future<List<dynamic>> orders() async => <dynamic>[_order()];

  @override
  Future<Map<String, dynamic>> liveOrder(int orderId) async => <String, dynamic>{'order': _order()};

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    if (path.startsWith('/orders/7001/cancel')) {
      cancelCalled = true;
      return _order(status: 'cancelled');
    }
    return <String, dynamic>{};
  }
}

void main() {
  testWidgets('Tala Eats production abre login sin credenciales demo', (WidgetTester tester) async {
    await tester.pumpWidget(const TalaEatsApp(testMode: true));
    await tester.pump();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Términos y Condiciones'), findsOneWidget);
    expect(find.text('Aviso de Privacidad'), findsOneWidget);
  });

  testWidgets('Registro production muestra creación segura de contraseña', (WidgetTester tester) async {
    await tester.pumpWidget(const TalaEatsApp(testMode: true));
    await tester.pump();

    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('Crea una contraseña'), findsOneWidget);
    expect(find.text('Confirma tu contraseña'), findsOneWidget);
  });

  testWidgets('Recuperación production está disponible sin tocar red', (WidgetTester tester) async {
    await tester.pumpWidget(const TalaEatsApp(testMode: true));
    await tester.pump();

    await tester.ensureVisible(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    expect(find.text('Recupera tu contraseña'), findsOneWidget);
    expect(find.text('Enviar enlace'), findsOneWidget);
  });

  testWidgets('Aviso legal abre términos desde Login', (WidgetTester tester) async {
    await tester.pumpWidget(const TalaEatsApp(testMode: true));
    await tester.pump();

    final Finder termsLink = find.text('Términos y Condiciones');
    expect(termsLink, findsOneWidget);
    await tester.ensureVisible(termsLink);
    await tester.pumpAndSettle();
    await tester.tap(termsLink);
    await tester.pumpAndSettle();

    expect(find.text('Términos y Condiciones de Uso'), findsOneWidget);
  });

  testWidgets('Aviso legal abre privacidad desde Login', (WidgetTester tester) async {
    await tester.pumpWidget(const TalaEatsApp(testMode: true));
    await tester.pump();

    final Finder privacyLink = find.text('Aviso de Privacidad');
    expect(privacyLink, findsOneWidget);
    await tester.ensureVisible(privacyLink);
    await tester.pumpAndSettle();
    await tester.tap(privacyLink);
    await tester.pumpAndSettle();

    expect(find.text('Aviso de Privacidad'), findsWidgets);
    expect(find.text('Datos que podemos tratar'), findsOneWidget);
  });

  // Regression: el carrito nunca debe quedar en blanco cuando el modelo tiene líneas.
  testWidgets('Carrito renderiza productos y total cuando tiene contenido', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    const Restaurant restaurant = Restaurant(
      id: 99,
      name: 'Restaurante QA',
      category: 'QA',
      rating: 4.9,
      eta: '20-30 min',
      deliveryFee: 12,
      image: '',
      description: 'Restaurante para smoke test.',
    );
    const FoodItem item = FoodItem(
      id: 9901,
      restaurantId: 99,
      name: 'Producto QA',
      description: 'Producto de prueba.',
      price: 124,
      image: '',
      category: 'QA',
    );
    model.restaurants.add(restaurant);
    model.menu.add(item);
    model.addToCart(item, 2);
  
    await tester.pumpWidget(MaterialApp(home: CartScreen(model: model)));
    await tester.pumpAndSettle();
  
    expect(find.text('Tu carrito'), findsOneWidget);
    expect(find.text('Producto QA'), findsOneWidget);
    expect(find.text(r'$248'), findsWidgets);
    expect(find.textContaining('Continuar'), findsOneWidget);
  });
  
  testWidgets('Editar perfil expone selector de foto', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.userName = 'Cliente QA';
    model.userEmail = 'qa@example.com';
  
    await tester.pumpWidget(MaterialApp(home: EditProfileScreen(model: model)));
    await tester.pump();
  
    expect(find.text('Elegir foto de perfil'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });
  testWidgets('Carrito flotante no invade pestañas globales', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    const FoodItem item = FoodItem(
      id: 7701,
      restaurantId: 77,
      name: 'Producto flotante QA',
      description: 'QA',
      price: 100,
      image: '',
      category: 'QA',
    );
    model.restaurants.add(const Restaurant(
      id: 77,
      name: 'Restaurante flotante QA',
      category: 'QA',
      rating: 5,
      eta: '10-20 min',
      deliveryFee: 0,
      image: '',
      description: 'QA',
    ));
    model.addToCart(item, 1);
    model.setTab(1);

    await tester.pumpWidget(MaterialApp(home: CustomerShell(model: model)));
    await tester.pump();

    expect(find.text('Ver carrito'), findsNothing);
  });

  // v1.0.9 — Checkout nunca debe quedar en negro/blanco: renderiza su
  // estructura y un estado claro cuando el pago en línea no está disponible.
  testWidgets('Checkout renderiza estado claro sin pago en línea', (WidgetTester tester) async {
    final TalaModel model = TalaModel(apiClient: _CheckoutPaymentMethodsQaApi(cash: false, mercadoPago: false, stripe: false));
    model.restaurants.add(const Restaurant(
      id: 55,
      name: 'Restaurante Checkout QA',
      category: 'QA',
      rating: 4.5,
      eta: '20-30 min',
      deliveryFee: 15,
      image: '',
      description: 'QA',
    ));
    model.addToCart(
      const FoodItem(
        id: 5501,
        restaurantId: 55,
        name: 'Producto Checkout QA',
        description: 'QA',
        price: 100,
        image: '',
        category: 'QA',
      ),
      1,
    );

    await tester.pumpWidget(MaterialApp(home: CheckoutScreen(model: model)));
    await tester.pumpAndSettle();

    expect(find.text('Finalizar pedido'), findsOneWidget);
    expect(find.text('Revisar métodos de pago'), findsOneWidget);
  });

  // v1.0.9 — Home muestra directamente la lista de comercios.
  testWidgets('Home muestra comercios sin carrito global', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.add(const Restaurant(
      id: 66,
      name: 'Comercio Home QA',
      category: 'QA',
      rating: 4.7,
      eta: '15-25 min',
      deliveryFee: 10,
      image: '',
      description: 'QA',
    ));

    await tester.pumpWidget(MaterialApp(home: CustomerShell(model: model)));
    await tester.pump();

    expect(find.text('Restaurantes y comercios'), findsOneWidget);
    expect(find.text('Comercio Home QA'), findsWidgets);
    expect(find.text('Ver carrito'), findsNothing);
  });

  test('Menú efectivo aparece aunque el detalle público todavía venga vacío', () async {
    final TalaModel model = TalaModel(apiClient: _EffectiveMenuWinsApi());

    await model.refreshRestaurantMenu(501);

    final List<FoodItem> items = model.itemsFor(501);
    expect(items, hasLength(2));
    expect(items.map((FoodItem item) => item.name), contains('La Gran Doble Smash con Tocino'));
    expect(items.map((FoodItem item) => item.name), contains('BURGER SUPER STAR'));
    expect(items.first.price, 260);
    expect(model.menuLoadFailed(501), isFalse);
  });

  test('Detalle público funciona como fallback si effective-menu falla', () async {
    final TalaModel model = TalaModel(apiClient: _DetailMenuFallbackApi());

    await model.refreshRestaurantMenu(502);

    final List<FoodItem> items = model.itemsFor(502);
    expect(items, hasLength(1));
    expect(items.single.name, 'Producto desde detalle');
    expect(items.single.price, 99);
    expect(model.menuLoadFailed(502), isFalse);
  });

  testWidgets('Checkout production ofrece efectivo cuando backend lo habilita', (WidgetTester tester) async {
    final _CheckoutPaymentMethodsQaApi api = _CheckoutPaymentMethodsQaApi(cash: true, mercadoPago: false, stripe: false);
    final TalaModel model = TalaModel(apiClient: api);
    model.restaurants.add(const Restaurant(
      id: 88,
      name: 'Comercio Cash QA',
      category: 'QA',
      rating: 4.5,
      eta: '20-30 min',
      deliveryFee: 10,
      image: '',
      description: 'QA',
    ));
    model.addToCart(const FoodItem(
      id: 8801,
      restaurantId: 88,
      name: 'Producto Cash QA',
      description: 'QA',
      price: 120,
      image: '',
      category: 'QA',
    ), 1);

    await tester.pumpWidget(MaterialApp(home: CheckoutScreen(model: model)));
    await tester.pumpAndSettle();
    expect(api.refreshCalls, greaterThanOrEqualTo(1));
    expect(model.cashPayments, isTrue);
    expect(model.mercadoPagoPayments, isFalse);
    expect(model.stripePayments, isFalse);
    await tester.scrollUntilVisible(find.text('Efectivo'), 170, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.textContaining('Confirmar pedido'), findsOneWidget);
    expect(find.text('Mercado Pago'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });


  testWidgets('Checkout muestra Stripe y wallet de plataforma cuando backend lo habilita', (WidgetTester tester) async {
    final _CheckoutPaymentMethodsQaApi api = _CheckoutPaymentMethodsQaApi(cash: false, mercadoPago: true, stripe: true);
    final TalaModel model = TalaModel(apiClient: api);
    model.paymentMethod = 'stripe';
    model.restaurants.add(const Restaurant(
      id: 89,
      name: 'Comercio Stripe QA',
      category: 'QA',
      rating: 4.8,
      eta: '20-30 min',
      deliveryFee: 10,
      image: '',
      description: 'QA',
    ));
    model.addToCart(const FoodItem(
      id: 8901,
      restaurantId: 89,
      name: 'Producto Stripe QA',
      description: 'QA',
      price: 150,
      image: '',
      category: 'QA',
    ), 1);

    await tester.pumpWidget(MaterialApp(home: CheckoutScreen(model: model)));
    await tester.pumpAndSettle();
    expect(api.refreshCalls, greaterThanOrEqualTo(1));
    expect(model.cashPayments, isFalse);
    expect(model.mercadoPagoPayments, isTrue);
    expect(model.stripePayments, isTrue);
    await tester.scrollUntilVisible(find.text('Mercado Pago'), 170, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Mercado Pago'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tarjeta y Google Pay'), 120, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(find.text('Tarjeta y Google Pay'), findsOneWidget);
    expect(find.text('Pago seguro procesado por Stripe'), findsOneWidget);
    // The production CTA deliberately avoids showing a provisional total.
    expect(find.text('Continuar a pago con Stripe'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });


  test('Stripe pendiente se muestra como pago pendiente y no como pedido activo', () async {
    final TalaModel model = TalaModel(apiClient: _PendingStripeOrderApi());

    await model.refreshOrders();

    expect(model.orders, hasLength(1));
    expect(model.orders.single.status, 'Pago pendiente');
    expect(model.orders.single.paymentStatus, 'pending');
    expect(model.activeOrder, isNull);
  });

  test('Cancelar una reserva Stripe pendiente restaura el carrito y cancela el pedido', () async {
    final _PendingStripeOrderApi api = _PendingStripeOrderApi();
    final TalaModel model = TalaModel(apiClient: api);

    await model.refreshOrders();
    final OrderEntry order = model.orders.single;
    final bool cancelled = await model.abandonPendingOnlineOrder(order);

    expect(cancelled, isTrue);
    expect(api.cancelCalled, isTrue);
    expect(order.status, 'Cancelado');
    expect(order.rawStatus, 'cancelled');
    expect(model.cart, hasLength(1));
    expect(model.cart.single.item.name, 'Hamburguesa Stripe QA');
  });

}
