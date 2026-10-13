import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/entities.dart';
import 'qa_scenario.dart';
import 'seed_data.dart';

/// Claves de almacenamiento local. Se conservan las de v0.3.6 para que una
/// actualización no pierda el alta ya realizada en el dispositivo.
abstract final class LocalKeys {
  static const String setupComplete = 'preview_setup_complete';
  static const String loggedIn = 'preview_logged_in';
  static const String ownerName = 'preview_owner_name';
  static const String email = 'preview_email';
  static const String phone = 'preview_phone';
  static const String restaurantName = 'preview_restaurant_name';
  static const String restaurantDescription = 'preview_restaurant_description';
  static const String restaurantCuisine = 'preview_restaurant_cuisine';
  static const String restaurantImage = 'preview_restaurant_image';
  static const String productName = 'preview_product_name';
  static const String productDescription = 'preview_product_description';
  static const String productCategory = 'preview_product_category';
  static const String productPrice = 'preview_product_price';
  static const String productStock = 'preview_product_stock';
  static const String productImage = 'preview_product_image';

  // v0.4.1
  static const String menu = 'local_menu_v1';
  static const String restaurantEta = 'local_restaurant_eta';
  static const String restaurantFee = 'local_restaurant_fee';
  static const String restaurantPickup = 'local_restaurant_pickup';
  static const String restaurantOpen = 'local_restaurant_open';
}

/// Estado compartido por los repositorios locales. Simula una fuente de datos
/// asíncrona con latencia y fallas controladas por [QaFaults].
class LocalBackend {
  LocalBackend({required this.latency, required this.faults});

  final LocalLatency latency;
  final QaFaults faults;

  SharedPreferences? _prefs;
  RestaurantInfo? _restaurant;
  List<MenuProduct>? _menu;
  List<RestaurantOrder>? _orders;
  List<EmployeeInfo>? _team;

  Future<SharedPreferences> prefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> simulateRead() => Future<void>.delayed(latency.read);
  Future<void> simulateWrite() => Future<void>.delayed(latency.write);

  /// Olvida el estado en memoria (cierre de sesión).
  void clearMemory() {
    _restaurant = null;
    _menu = null;
    _orders = null;
    _team = null;
  }

  Future<RestaurantInfo> restaurant() async {
    final cached = _restaurant;
    if (cached != null) return cached;
    final p = await prefs();
    final seed = SeedData.restaurant();
    final restored = seed.copyWith(
      name: p.getString(LocalKeys.restaurantName),
      description: p.getString(LocalKeys.restaurantDescription),
      cuisine: _nonEmpty(p.getString(LocalKeys.restaurantCuisine)),
      imagePath: p.getString(LocalKeys.restaurantImage),
      etaMin: p.getInt(LocalKeys.restaurantEta),
      deliveryFee: p.getDouble(LocalKeys.restaurantFee),
      pickupEnabled: p.getBool(LocalKeys.restaurantPickup),
      isOpen: p.getBool(LocalKeys.restaurantOpen),
    );
    _restaurant = restored;
    return restored;
  }

  Future<void> saveRestaurant(RestaurantInfo value) async {
    _restaurant = value;
    final p = await prefs();
    await p.setString(LocalKeys.restaurantName, value.name);
    await p.setString(LocalKeys.restaurantDescription, value.description);
    await p.setString(LocalKeys.restaurantCuisine, value.cuisine);
    await p.setString(LocalKeys.restaurantImage, value.imagePath);
    await p.setInt(LocalKeys.restaurantEta, value.etaMin);
    await p.setDouble(LocalKeys.restaurantFee, value.deliveryFee);
    await p.setBool(LocalKeys.restaurantPickup, value.pickupEnabled);
    await p.setBool(LocalKeys.restaurantOpen, value.isOpen);
  }

  Future<List<MenuProduct>> menu() async {
    final cached = _menu;
    if (cached != null) return cached;
    final p = await prefs();
    List<MenuProduct> result;
    final raw = p.getString(LocalKeys.menu);
    if (raw != null && raw.isNotEmpty) {
      result = _decodeMenu(raw);
    } else if (p.containsKey(LocalKeys.productName)) {
      result = <MenuProduct>[
        MenuProduct(
          id: 1,
          name: p.getString(LocalKeys.productName) ?? 'Mi primer producto',
          description: p.getString(LocalKeys.productDescription) ?? '',
          category: _nonEmpty(p.getString(LocalKeys.productCategory)) ??
              'General',
          price: p.getDouble(LocalKeys.productPrice) ?? 0,
          isAvailable: true,
          stock: p.getInt(LocalKeys.productStock) ?? 0,
          allergens: '',
          isCombo: false,
          optionsJson: '[]',
          imagePath: p.getString(LocalKeys.productImage) ?? '',
        ),
      ];
    } else {
      result = faults.isEmpty ? <MenuProduct>[] : SeedData.menu();
    }
    _menu = result;
    return result;
  }

  Future<void> saveMenu(List<MenuProduct> value) async {
    _menu = value;
    final p = await prefs();
    await p.setString(
      LocalKeys.menu,
      jsonEncode(value.map((e) => e.toLocalJson()).toList()),
    );
  }

  Future<List<RestaurantOrder>> orders() async {
    final cached = _orders;
    if (cached != null) return cached;
    final menuItems = await menu();
    final result = faults.isEmpty
        ? <RestaurantOrder>[]
        : SeedData.orders(menuItems, DateTime.now());
    _orders = result;
    return result;
  }

  void replaceOrder(RestaurantOrder updated) {
    final current = _orders ?? <RestaurantOrder>[];
    _orders = current
        .map((o) => o.id == updated.id ? updated : o)
        .toList(growable: false);
  }

  List<EmployeeInfo> team() =>
      _team ??= faults.isEmpty ? <EmployeeInfo>[] : SeedData.team();

  void setTeam(List<EmployeeInfo> value) => _team = value;

  static List<MenuProduct> _decodeMenu(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <MenuProduct>[];
      return decoded
          .whereType<Map>()
          .map((e) => MenuProduct.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on FormatException {
      return <MenuProduct>[];
    }
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}
