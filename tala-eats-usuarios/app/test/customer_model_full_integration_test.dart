import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

Map<String, dynamic> merchant(int id, String market, {bool open = true}) =>
    <String, dynamic>{
      'id': id, 'name': 'Comercio $id', 'cuisine': 'Comida local',
      'rating': 4.5, 'eta_min': 20, 'delivery_fee': 35.0,
      'is_open': open, 'pickup_enabled': true, 'market_code': market,
    };

Restaurant restaurant(int id, {bool open = true}) => Restaurant(
    id: id, name: 'Comercio $id', category: 'Comida local',
    rating: 4.5, eta: '20 min', deliveryFee: 35.0,
    image: '', description: '', isOpen: open);

FoodItem food(int id, int shop) => FoodItem(
    id: id, restaurantId: shop, name: 'Producto $id',
    description: '', price: 100, image: '', category: 'Comida');

class _IntegrationApi extends TalaApi {
  final List<String> calls = <String>[];
  Completer<Map<String, dynamic>>? delayedDetail;
  Completer<List<dynamic>>? delayedPilotCatalog;
  bool failMarket = false;

  @override
  Future<List<dynamic>> restaurantsForMarket(String code) async {
    calls.add('market ' + code);
    if (failMarket) throw ApiException(503, 'Catálogo no disponible');
    if (code == 'TALA-JAL' && delayedPilotCatalog != null) {
      return delayedPilotCatalog!.future;
    }
    return <dynamic>[merchant(code == 'AMECA-JAL' ? 2 : 1, code)];
  }

  @override
  Future<Map<String, dynamic>> restaurant(int id) {
    calls.add('detail ' + id.toString());
    if (delayedDetail != null) return delayedDetail!.future;
    return Future<Map<String, dynamic>>.value(
        <String, dynamic>{'id': id, 'menu_items': <dynamic>[]});
  }

  @override
  Future<dynamic> get(String path) async {
    calls.add('GET ' + path);
    if (path.startsWith('/v9/restaurants/') &&
        path.endsWith('/effective-menu')) {
      return <String, dynamic>{'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 11, 'name': 'Platillo tardío', 'available_now': true,
          'effective_price': 100, 'category': 'Comida'
        },
      ]};
    }
    if (path == '/platform/promotions' || path == '/platform/coupons') {
      return <dynamic>[];
    }
    if (path == '/platform/loyalty') {
      return <String, dynamic>{'points': 0, 'wallet_balance': 0};
    }
    if (path == '/orders/payment-methods') return <dynamic>[];
    throw StateError('GET inesperado: ' + path);
  }

  @override
  Future<Map<String, dynamic>> bootstrap() async =>
      <String, dynamic>{
        'user': <String, dynamic>{'id': 9, 'name': 'Persona QA',
            'email': 'qa@example.invalid', 'role': 'customer'},
        'wallet': <String, dynamic>{'balance': 0, 'points': 0},
        'unread_notifications': 0,
      };
  @override
  Future<List<dynamic>> addresses() async => <dynamic>[];
  @override
  Future<List<dynamic>> orders() async => <dynamic>[];
  @override
  Future<List<dynamic>> favorites() async => <dynamic>[];
  @override
  Future<Map<String, dynamic>> wallet() async =>
      <String, dynamic>{'balance': 0, 'points': 0, 'transactions': <dynamic>[]};
  @override
  Future<List<dynamic>> notifications() async => <dynamic>[];
  @override
  Future<Map<String, dynamic>> privacy() async => <String, dynamic>{
    'marketing_opt_in': false, 'analytics_opt_in': false,
    'personalization_opt_in': false
  };

  @override
  Future<Map<String, dynamic>> updateCustomerAddress(
      int id, Map<String, dynamic> changes) async {
    calls.add('PATCH-address ' + id.toString());
    if (failMarket) throw ApiException(503, 'Cambio no guardado');
    return <String, dynamic>{
      'id': id, 'label': 'Casa', 'address': 'Calle QA',
      'lat': 20.65, 'lng': -103.70, 'is_default': true,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.talaeats.app/native');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final nativeCalls = <String>[];

  setUp(() {
    nativeCalls.clear();
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      nativeCalls.add(call.method);
      if (call.method == 'readMarketCode') return 'TALA-JAL';
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Carrito: comercio cerrado y producto ajeno no borran pedido actual', () {
    final model = TalaModel(apiClient: _IntegrationApi());
    model.restaurants.addAll(<Restaurant>[restaurant(1), restaurant(2, open: false)]);
    model.addToCart(food(10, 1), 2);
    expect(model.cart.single.item.id, 10);
    expect(model.cartRestaurantId, 1);
    model.addToCart(food(99, 2), 1);
    expect(model.cart.single.item.id, 10);
    expect(model.cartRestaurantId, 1);
    model.addToCart(food(98, 999), 1);
    expect(model.cart.single.item.id, 10);
    expect(model.cartRestaurantId, 1);
    model.addToCart(food(11, 1), 0);
    expect(model.cart.length, 1);
    model.dispose();
  });

  test('Mercado: carrito necesita consentimiento y se conserva ante error API', () async {
    final api = _IntegrationApi();
    final model = TalaModel(apiClient: api);
    model.restaurants.add(restaurant(1));
    model.addToCart(food(10, 1), 1);
    final before = model.cart.single;
    expect(await model.chooseMarket('AMECA-JAL'), false);
    expect(model.marketCode, 'TALA-JAL');
    expect(model.cart.single, same(before));
    expect(nativeCalls, isNot(contains('writeMarketCode')));
    api.failMarket = true;
    expect(await model.chooseMarket('AMECA-JAL', discardCart: true), false);
    expect(model.marketCode, 'TALA-JAL');
    expect(model.cart.single, same(before));
    expect(nativeCalls, isNot(contains('writeMarketCode')));
    api.failMarket = false;
    expect(await model.chooseMarket('AMECA-JAL', discardCart: true), true);
    expect(model.marketCode, 'AMECA-JAL');
    expect(model.cart, isEmpty);
    expect(model.cartRestaurantId, null);
    expect(model.restaurants.single.id, 2);
    expect(nativeCalls.where((e) => e == 'writeMarketCode').length, 1);
    model.dispose();
  });

  test('Mercado: menú pendiente del piloto no contamina la localidad nueva', () async {
    final api = _IntegrationApi();
    api.delayedDetail = Completer<Map<String, dynamic>>();
    final model = TalaModel(apiClient: api);
    model.restaurants.add(restaurant(1));
    final loadingMenu = model.refreshRestaurantMenu(1);
    expect(api.calls, contains('detail 1'));
    expect(await model.chooseMarket('AMECA-JAL'), true);
    api.delayedDetail!.complete(<String, dynamic>{
      'id': 1, 'menu_items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 11, 'name': 'Platillo tardío', 'category': 'Comida',
          'price': 100, 'stock': 8, 'is_available': true,
        },
      ],
    });
    await loadingMenu;
    expect(model.marketCode, 'AMECA-JAL');
    expect(model.restaurants.single.id, 2);
    expect(model.menu, isEmpty,
      reason: 'Las búsquedas no deben mostrar productos de otro municipio.');
    model.dispose();
  });

  test('Refresh antigua no sobreescribe cambio de localidad más reciente', () async {
    final api = _IntegrationApi()..delayedPilotCatalog = Completer<List<dynamic>>();
    final model = TalaModel(apiClient: api);
    final staleRefresh = model.refreshAll();
    expect(await model.chooseMarket('AMECA-JAL'), true);
    api.delayedPilotCatalog!.complete(<dynamic>[merchant(1, 'TALA-JAL')]);
    await staleRefresh;
    expect(model.marketCode, 'AMECA-JAL');
    expect(model.restaurants.single.id, 2);
    model.dispose();
  });

  test('Direcciones: no se marca éxito local si el PATCH del servidor falla', () async {
    final api = _IntegrationApi()..failMarket = true;
    final model = TalaModel(apiClient: api);
    model.addresses.add(const AddressEntry(
        id: 31, label: 'Casa', address: 'Calle QA',
        lat: 20.65, lng: -103.70));
    expect(await model.setDefaultAddressRemote(0), false);
    expect(model.addresses.single.isDefault, false);
    expect(api.calls, contains('PATCH-address 31'));
    model.dispose();
  });
}
