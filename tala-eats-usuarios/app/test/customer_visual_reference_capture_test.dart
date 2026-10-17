import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

// Reproducible synthetic catalog. No credentials, external HTTP, production
// customer information, real payment methods or order creation.
const Restaurant sampleShop = Restaurant(
  id: 701,
  name: 'Comercio de demostración',
  category: 'Comida local',
  rating: 4.7,
  eta: '25-35 min',
  deliveryFee: 35,
  image: '',
  description: 'Ejemplo de comercio para revisar el diseño.',
);
const FoodItem sampleItem = FoodItem(
  id: 7001,
  restaurantId: 701,
  name: 'Tacos de ejemplo',
  description: 'Platillo ficticio para revisión visual.',
  price: 80,
  image: '',
  category: 'Tacos',
);

class SyntheticVisualApi extends TalaApi {
  @override
  Future<Map<String, dynamic>> restaurant(int id) async =>
      <String, dynamic>{
        'id': id,
        'menu_items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7001,
            'name': sampleItem.name,
            'category': sampleItem.category,
            'description': sampleItem.description,
            'price': sampleItem.price,
            'is_available': true,
            'stock': 20,
          },
        ],
      };

  @override
  Future<dynamic> get(String path) async {
    if (path.contains('effective-menu')) {
      return <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 7001,
            'available_now': true,
            'effective_price': 80,
          },
        ],
      };
    }
    if (path == '/orders/payment-methods') {
      // Only in-memory test data. Never trigger a payment or order POST.
      return <String, dynamic>{
        'methods': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'cash', 'enabled': true},
        ],
      };
    }
    throw StateError('Synthetic visual capture forbids $path');
  }
}

TalaModel sampleModel() {
  final TalaModel m = TalaModel(apiClient: SyntheticVisualApi());
  m.restaurants.add(sampleShop);
  m.menu.add(sampleItem);
  m.userName = 'Persona de prueba';
  m.userEmail = 'demo@example.invalid';
  m.wallet = 120;
  m.points = 85;
  m.loyaltyTier = 'BRONZE';
  m.addresses.add(const AddressEntry(
    id: 71,
    label: 'Casa de prueba',
    address: 'Domicilio ficticio — sin datos personales',
  ));
  m.addToCart(sampleItem, 2);
  m.deliveryMode = 'pickup';
  m.orders.add(OrderEntry(
    id: 901, restaurant: sampleShop, total: 160,
    status: 'Preparando', rawStatus: 'preparing',
    deliveryMode: 'pickup',
    eta: '25-35 min', lines: <CartLine>[],
  ));
  return m;
}

const bool captureRequested =
    bool.fromEnvironment('TALA_VISUAL_CAPTURE', defaultValue: false);

Future<void> snapshot(WidgetTester tester, Widget page,
    String file, {double width = 390, double textScale = 1.0}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(RepaintBoundary(
    key: const ValueKey<String>('visual-capture-root'),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
          accessibleNavigation: true,
        ),
        child: page,
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 900));
  expect(tester.takeException(), isNull,
      reason: 'Screenshot $file has no layout errors.');
  await expectLater(
    find.byKey(const ValueKey<String>('visual-capture-root')),
    matchesGoldenFile('goldens/$file'),
  );
}

void main() {
  testWidgets('Reference images — seven key screens, isolated mock data',
      (WidgetTester tester) async {
    final TalaModel m = sampleModel();
    final Map<String, Widget> pages = <String, Widget>{
      '01_home_mock_390.png': HomeScreen(model: m),
      '02_search_mock_390.png': SearchScreen(model: m),
      '03_restaurant_mock_390.png': RestaurantScreen(
        model: m, restaurant: sampleShop),
      '04_cart_mock_390.png': CartScreen(model: m),
      '05_checkout_mock_390.png': CheckoutScreen(model: m),
      '06_orders_mock_390.png': OrdersScreen(model: m),
      '07_account_mock_390.png': AccountScreen(model: m),
    };
    for (final MapEntry<String, Widget> page in pages.entries) {
      await snapshot(tester, page.value, page.key);
    }
    await snapshot(tester, HomeScreen(model: m),
        '08_home_accessibility_mock_320.png', width: 320, textScale: 1.3);
    await snapshot(tester, SearchScreen(model: m),
        '09_search_accessibility_mock_320.png', width: 320, textScale: 1.3);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    m.dispose();
  }, skip: !captureRequested);
}
