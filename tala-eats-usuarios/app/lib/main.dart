import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'production_api.dart';
import 'order_submission_guard.dart';
import 'checkout_pricing.dart';
import 'local_markets.dart';
import 'customer_native_push.dart';

part 'ui/design_system.dart';
part 'ui/auth_screens.dart';
part 'ui/discovery_screens.dart';
part 'ui/purchase_screens.dart';
part 'ui/order_screens.dart';
part 'ui/account_screens.dart';
part 'ui/legal_screens.dart';
part 'ui/backend_features_screens.dart';
part 'ui/market_selector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const TalaEatsApp());
}

const Color kBrand = Color(0xFFFF5A1F);
const Color kBrandDeep = Color(0xFFE9470F);
const Color kInk = Color(0xFF171717);
const Color kMuted = Color(0xFF737373);
const Color kBackground = Color(0xFFFAFAF9);
const Color kSurface = Color(0xFFFFFFFF);
const Color kSoftOrange = Color(0xFFFFE9DF);
const Color kSoftPeach = Color(0xFFFFF3EC);
const Color kSoftGreen = Color(0xFFE7F7EE);
const Color kGreen = Color(0xFF168A4A);
const Color kLine = Color(0xFFEAE8E5);
const Color kGold = Color(0xFFFFB000);
const Color kCream = Color(0xFFFFF7F0);
const Color kPlum = Color(0xFF6D3B67);
const Color kSky = Color(0xFFE8F4FF);

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.eta,
    required this.deliveryFee,
    required this.image,
    required this.description,
    this.promo = '',
    this.delivery = true,
    this.pickup = true,
    this.isOpen = true,
    this.imageUrl = '',
  });

  final int id;
  final String name;
  final String category;
  final double rating;
  final String eta;
  final double deliveryFee;
  final String image;
  final String description;
  final String promo;
  final bool delivery;
  final bool pickup;
  final bool isOpen;
  final String imageUrl;
}

class FoodItem {
  const FoodItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.category,
    this.imageUrl = '',
  });

  final int id;
  final int restaurantId;
  final String name;
  final String description;
  final double price;
  final String image;
  final String category;
  final String imageUrl;
}

class CartLine {
  CartLine({required this.item, this.quantity = 1, this.note = ''});

  final FoodItem item;
  int quantity;
  String note;

  double get total => item.price * quantity;
}

class AddressEntry {
  const AddressEntry({required this.id, required this.label, required this.address, this.lat, this.lng, this.isDefault = false});
  final int id;
  final String label;
  final String address;
  final double? lat;
  final double? lng;
  final bool isDefault;
}

class NotificationEntry {
  const NotificationEntry({required this.id, required this.kind, required this.title, required this.message, required this.isRead, required this.createdAt});
  final int id;
  final String kind;
  final String title;
  final String message;
  final bool isRead;
  final String createdAt;
}

class OrderEntry {
  OrderEntry({
    required this.id,
    required this.restaurant,
    required this.total,
    required this.status,
    required this.deliveryMode,
    required this.lines,
    this.eta = 'Calculando…',
    this.pin = '',
    this.paymentStatus = 'pending',
    this.paymentMethod = 'cash',
    this.rawStatus = 'received',
    this.driverName = '',
    this.driverVehicle = '',
    this.driverRating = 0,
  });

  final int id;
  final Restaurant restaurant;
  final double total;
  String status;
  final String deliveryMode;
  final List<CartLine> lines;
  String eta;
  final String pin;
  String paymentStatus;
  final String paymentMethod;
  String rawStatus;
  final String driverName;
  final String driverVehicle;
  final double driverRating;

  bool get isOnlinePayment => paymentMethod == 'stripe' || paymentMethod == 'mercadopago';
  bool get isAwaitingOnlinePayment => isOnlinePayment && paymentStatus != 'paid' && rawStatus != 'cancelled';
}

class TalaModel extends ChangeNotifier {
  TalaModel({TalaApi? apiClient}) : api = apiClient ?? TalaApi();

  final TalaApi api;
  final CustomerNativePush _nativePush = CustomerNativePush();
  bool nativePushActive = false;
  bool nativePushBusy = false;
  String nativePushError = '';

  Future<void> _refreshPushInbox() async {
    if (!signedIn || api.token == null) return;
    try {
      _applyNotifications(await api.notifications());
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> _startPush({required bool askPermission}) async {
    if (!signedIn || userId <= 0 || nativePushBusy) return false;
    nativePushBusy = true;
    nativePushError = '';
    notifyListeners();
    final int initiatingUser = userId;
    try {
      final enabled = await _nativePush.enable(
        api, userId: initiatingUser, marketing: marketing,
        askPermission: askPermission,
        onInbox: () => unawaited(_refreshPushInbox()),
        onOpenOrders: () {
          if (signedIn && initiatingUser == userId) {
            setTab(2);
            unawaited(refreshOrders());
          }
        },
      );
      if (signedIn && userId == initiatingUser) nativePushActive = enabled;
      return enabled;
    } on ApiException catch (e) {
      nativePushError = e.message;
      return false;
    } catch (_) {
      nativePushError = 'No se pudo activar Firebase en este dispositivo.';
      return false;
    } finally {
      nativePushBusy = false;
      notifyListeners();
    }
  }

  void _resumePush() {
    if (signedIn && userId > 0) {
      unawaited(_startPush(askPermission: false));
    }
  }

  Future<bool> enableNativePush() => _startPush(askPermission: true);

  Future<void> disableNativePush() async {
    if (nativePushBusy) return;
    nativePushBusy = true;
    notifyListeners();
    final int owner = userId;
    final bool remote = await _nativePush.disable(api, owner);
    nativePushActive = false;
    nativePushBusy = false;
    nativePushError = remote ? '' : 'Notificaciones desactivadas en el teléfono, '
        'pero el servidor no confirmó la baja. Revisa tu conexión.';
    notifyListeners();
  }

  late final OrderSubmissionGuard _orderSubmissionGuard = OrderSubmissionGuard(
    store: AndroidPendingOrderStore(), accountId: () => userId,
  );
  Future<OrderEntry>? _activePlaceOrder;
  int _orderSessionRevision = 0;
  bool signedIn = false;
  bool loading = false;
  bool online = true;
  String lastError = '';
  String blockedRole = '';
  String userName = '';
  String userEmail = '';
  String userPhone = '';
  String userAvatarUrl = '';
  String userLocalAvatarPath = '';
  int userId = 0;
  int tabIndex = 0;
  int selectedAddress = 0;
  String marketCode = TalaMarket.pilot;
  bool marketChanging = false;
  String deliveryMode = 'delivery';
  double tip = 20;
  String coupon = '';
  int? cartRestaurantId;

  final List<Restaurant> restaurants = <Restaurant>[];
  final List<FoodItem> menu = <FoodItem>[];
  final List<CartLine> cart = <CartLine>[];
  final Set<int> favorites = <int>{};
  final List<OrderEntry> orders = <OrderEntry>[];
  final List<AddressEntry> addresses = <AddressEntry>[];
  final List<NotificationEntry> notifications = <NotificationEntry>[];
  final List<Map<String, dynamic>> promotions = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> coupons = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> walletTransactions = <Map<String, dynamic>>[];
  int _marketCatalogEpoch = 0;
  final Set<int> _menusLoading = <int>{};
  final Set<int> _menuLoadErrors = <int>{};

  double wallet = 0;
  int points = 0;
  bool twoFactor = false;
  bool marketing = true;
  bool orderPush = true;
  bool promoPush = true;
  bool rewardPush = true;
  bool personalizedExperience = true;
  bool analytics = true;
  int unreadNotifications = 0;
  bool onlinePayments = false;
  bool cashPayments = false;
  bool mercadoPagoPayments = false;
  bool stripePayments = false;
  String paymentMethod = 'cash';
  // Configuracion comercial de solo lectura recibida del backend.
  CheckoutPricingPolicy? customerPricingPolicy;

  bool googleSignin = false;
  String supportEmail = 'soporte@talaeats.mx';
  String loyaltyTier = 'BRONZE';
  bool plusMember = false;
  String referralCode = '';
  String pendingResetToken = '';
  int pendingOrderId = 0;

  Future<void> initialize() async {
    // No bloqueamos el arranque por configuración opcional de Google.
    api.get('/auth/google/config').then((dynamic gc) {
      if (gc is Map) {
        googleSignin = gc['enabled'] == true;
        notifyListeners();
      }
    }).catchError((Object _) {});

    final String? uriText = await NativeBridge.initialUri();
    if (uriText != null && uriText.isNotEmpty) {
      final Uri? uri = Uri.tryParse(uriText);
      final String token = uri?.queryParameters['token'] ?? '';
      if (token.length >= 20) pendingResetToken = token;
      if (uri != null) {
        final List<String> segments = uri.pathSegments;
        final int pedidoIndex = segments.indexOf('pedido');
        if (pedidoIndex >= 0 && pedidoIndex + 1 < segments.length) {
          pendingOrderId = int.tryParse(segments[pedidoIndex + 1]) ?? 0;
        }
      }
    }
    final String? market = await NativeBridge.readMarketCode();
    if (market != null && TalaMarket.valid(market)) marketCode = market;
    final String? stored = await NativeBridge.readToken();
    if (stored == null || stored.isEmpty) return;
    api.token = stored;
    try {
      final Map<String, dynamic> me = await api.me();
      if ((me['role'] ?? '') != 'customer') {
        await NativeBridge.clearToken();
        api.token = null;
        return;
      }
      _applyUser(me);
      userLocalAvatarPath = await NativeBridge.profilePhotoPath(userId) ?? '';
      signedIn = true;
      await refreshAll();
      await _recoverPersistedCheckout();
      _resumePush();
      if (pendingOrderId > 0) tabIndex = 2;
    } on ApiException catch (e) {
      signedIn = false;
      lastError = e.message;
      online = e.statusCode != 0;
      // An offline device or a 5xx response is not proof of a revoked token.
      // Keep the encrypted session for a subsequent startup/retry.
      if (e.statusCode == 401 || e.statusCode == 403) {
        await NativeBridge.clearToken();
        api.token = null;
      }
    } catch (_) {
      // An unexpected local failure must not destroy a potentially valid
      // encrypted session. Server-side revocation is checked at next startup.
      signedIn = false;
      lastError = 'No pudimos verificar tu sesión. Inténtalo de nuevo.';
    }
  }

  Future<void> refreshAll() async {
    final int catalogEpoch = _marketCatalogEpoch;
    final String requestedMarket = marketCode;
    loading = true;
    lastError = '';
    notifyListeners();
    try {
      final List<dynamic> core = await Future.wait<dynamic>(<Future<dynamic>>[
        api.bootstrap(),
        api.restaurantsForMarket(marketCode),
        api.addresses(),
        api.orders(),
        api.favorites(),
        api.wallet(),
        api.notifications(),
      ]);
      _applyBootstrap(Map<String, dynamic>.from(core[0] as Map));
      if (catalogEpoch == _marketCatalogEpoch && requestedMarket == marketCode) {
        _applyRestaurants(List<dynamic>.from(core[1] as List));
      }
      _applyAddresses(List<dynamic>.from(core[2] as List));
      _applyOrders(List<dynamic>.from(core[3] as List));
      _applyFavorites(List<dynamic>.from(core[4] as List));
      _applyWallet(Map<String, dynamic>.from(core[5] as Map));
      _applyNotifications(List<dynamic>.from(core[6] as List));
      online = true;

      // Módulos secundarios degradan de forma independiente.
      try { _applyPrivacy(Map<String, dynamic>.from((await api.privacy()) as Map)); } catch (_) {}
      try {
        promotions
          ..clear()
          ..addAll(List<dynamic>.from((await api.get('/platform/promotions')) as List).map((dynamic x) => Map<String, dynamic>.from(x as Map)));
      } catch (_) {}
      try {
        coupons
          ..clear()
          ..addAll(List<dynamic>.from((await api.get('/platform/coupons')) as List).map((dynamic x) => Map<String, dynamic>.from(x as Map)));
      } catch (_) {}
      try { _applyLoyalty(Map<String, dynamic>.from((await api.get('/platform/loyalty')) as Map)); } catch (_) {}
      try { await refreshPaymentMethods(); } catch (_) {}
    } on ApiException catch (e) {
      online = e.statusCode != 0;
      lastError = e.message;
      if (e.statusCode == 401) {
        signedIn = false;
        api.token = null;
        await NativeBridge.clearToken();
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password, {String otp = ''}) async {
    final String normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) return false;
    blockedRole = '';
    lastError = '';
    try {
      final Map<String, dynamic> data = await api.login(normalized, password, otp: otp);
      final Map<String, dynamic> user = Map<String, dynamic>.from(data['user'] as Map);
      final String role = (user['role'] ?? '').toString();
      if (role != 'customer') {
        blockedRole = role;
        api.token = null;
        await NativeBridge.clearToken();
        notifyListeners();
        return false;
      }
      final String token = (data['access_token'] ?? '').toString();
      if (token.isEmpty || token == 'cookie') throw ApiException(500, 'El servidor no devolvió una sesión móvil válida.');
      api.token = token;
      await NativeBridge.writeToken(token);
      _applyUser(user);
      userLocalAvatarPath = await NativeBridge.profilePhotoPath(userId) ?? '';
      signedIn = true;
      await refreshAll();
      await _recoverPersistedCheckout();
      _resumePush();
      notifyListeners();
      return signedIn;
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerCustomer(String name, String email, String password) async {
    lastError = '';
    try {
      final Map<String, dynamic> data = await api.register(name.trim(), email.trim().toLowerCase(), password);
      final Map<String, dynamic> user = Map<String, dynamic>.from(data['user'] as Map);
      final String token = (data['access_token'] ?? '').toString();
      if ((user['role'] ?? '') != 'customer' || token.isEmpty || token == 'cookie') throw ApiException(500, 'No se pudo iniciar la sesión móvil.');
      api.token = token;
      await NativeBridge.writeToken(token);
      _applyUser(user);
      userLocalAvatarPath = await NativeBridge.profilePhotoPath(userId) ?? '';
      signedIn = true;
      await refreshAll();
      await _recoverPersistedCheckout();
      _resumePush();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    if (!email.trim().contains('@')) return false;
    try {
      await api.forgotPassword(email.trim().toLowerCase());
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      return false;
    }
  }

  Future<bool> resetPassword(String token, String password) async {
    try {
      await api.resetPassword(token.trim(), password);
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      return false;
    }
  }

  Future<void> logout() async {
    _orderSessionRevision++;
    _activePlaceOrder = null;
    _orderSubmissionGuard.clearAfterConfirmedResolution();
    try {
      await _nativePush.disable(api, userId).timeout(const Duration(seconds: 10));
    } catch (_) {}
    nativePushActive = false;
    nativePushError = '';
    try {
      await api.post('/auth/logout').timeout(const Duration(seconds: 5));
    } catch (_) {}
    await NativeBridge.clearToken();
    api.token = null;
    signedIn = false;
    blockedRole = '';
    tabIndex = 0;
    restaurants.clear(); menu.clear(); cart.clear(); favorites.clear(); orders.clear(); addresses.clear(); notifications.clear(); _menusLoading.clear(); _menuLoadErrors.clear();
    notifyListeners();
  }

  void setTab(int value) { tabIndex = value; notifyListeners(); }

  /// The market chooses discovery only. Backend checkout validates delivery
  /// coordinates and merchant delivery radius independently of this filter.
  Future<bool> chooseMarket(String code, {bool discardCart = false}) async {
    if (!TalaMarket.valid(code) || marketChanging) return false;
    if (code == marketCode) return true;
    if (cart.isNotEmpty && !discardCart) {
      lastError = 'Confirma el cambio de zona para vaciar el carrito actual.';
      notifyListeners();
      return false;
    }
    marketChanging = true;
    lastError = '';
    notifyListeners();
    try {
      final rows = await api.restaurantsForMarket(code);
      await NativeBridge.writeMarketCode(code);
      // Do not mutate cart, current zone or menu if network/storage fails.
      marketCode = code;
      _applyRestaurants(rows);
      menu.clear();
      _menusLoading.clear();
      _menuLoadErrors.clear();
      cart.clear();
      cartRestaurantId = null;
      coupon = '';
      lastError = '';
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      return false;
    } catch (_) {
      lastError = 'No se pudo cambiar la localidad. Revisa tu conexión.';
      return false;
    } finally {
      marketChanging = false;
      notifyListeners();
    }
  }

  List<FoodItem> itemsFor(int restaurantId) {
    final List<FoodItem> rows = menu.where((FoodItem item) => item.restaurantId == restaurantId).toList();
    if (rows.isEmpty && !_menusLoading.contains(restaurantId)) _loadRestaurantMenu(restaurantId);
    return rows;
  }

  Future<void> _loadRestaurantMenu(int restaurantId) async {
    if (_menusLoading.contains(restaurantId)) return;
    final int catalogEpoch = _marketCatalogEpoch;
    _menusLoading.add(restaurantId);
    _menuLoadErrors.remove(restaurantId);
    notifyListeners();

    Map<String, dynamic>? detail;
    Map<String, dynamic>? effective;

    try {
      detail = await api.restaurant(restaurantId);
    } catch (_) {
      // El catálogo efectivo puede seguir cargando aunque el detalle falle o esté temporalmente cacheado.
    }

    try {
      final dynamic raw = await api.get('/v9/restaurants/$restaurantId/effective-menu');
      if (raw is Map) effective = Map<String, dynamic>.from(raw);
    } catch (_) {
      // El detalle público queda como fallback si el endpoint de disponibilidad no responde.
    }

    try {
      // Ignore stale menu responses after a catalog/market change.
      // Do not require the parent restaurant list here: detail/effective-menu
      // are valid standalone routes while the catalogue is still loading.
      if (catalogEpoch != _marketCatalogEpoch) return;
      if (detail == null && effective == null) {
        _menuLoadErrors.add(restaurantId);
        return;
      }

      final Map<int, Map<String, dynamic>> detailById = <int, Map<String, dynamic>>{};
      if (detail != null) {
        final dynamic rawRows = detail['menu_items'];
        if (rawRows is List) {
          for (final dynamic raw in rawRows) {
            if (raw is! Map) continue;
            final Map<String, dynamic> row = Map<String, dynamic>.from(raw);
            final int id = _asInt(row['id']);
            if (id > 0) detailById[id] = row;
          }
        }
      }

      final List<FoodItem> fresh = <FoodItem>[];

      // Fuente principal: effective-menu. Es el contrato que representa lo que el
      // cliente realmente puede comprar ahora (disponibilidad, stock y precio).
      if (effective != null && effective['items'] is List) {
        for (final dynamic raw in effective['items'] as List) {
          if (raw is! Map) continue;
          final Map<String, dynamic> live = Map<String, dynamic>.from(raw);
          if (!_asBool(live['available_now'])) continue;
          final int id = _asInt(live['id']);
          if (id <= 0) continue;
          final Map<String, dynamic> meta = detailById[id] ?? const <String, dynamic>{};
          final String name = (meta['name'] ?? live['name'] ?? 'Producto').toString().trim();
          final String category = (meta['category'] ?? live['category'] ?? 'Menú').toString().trim();
          final String metaImage = _remoteImageUrl(meta);
          fresh.add(FoodItem(
            id: id,
            restaurantId: restaurantId,
            name: name.isEmpty ? 'Producto' : name,
            description: (meta['description'] ?? live['description'] ?? '').toString(),
            price: _asDouble(live['effective_price'] ?? meta['price'] ?? live['base_price']),
            image: _imageForRestaurant(restaurantId),
            category: category.isEmpty ? 'Menú' : category,
            imageUrl: metaImage.isNotEmpty ? metaImage : _remoteImageUrl(live),
          ));
        }
      } else {
        // Fallback seguro: si effective-menu no responde, el detalle todavía puede
        // mostrar productos explícitamente activos y con stock.
        for (final Map<String, dynamic> item in detailById.values) {
          if (!_asBool(item['is_available'], defaultValue: true)) continue;
          final int stock = _asInt(item['stock']);
          if (item.containsKey('stock') && stock <= 0) continue;
          final int id = _asInt(item['id']);
          if (id <= 0) continue;
          final String name = (item['name'] ?? 'Producto').toString().trim();
          final String category = (item['category'] ?? 'Menú').toString().trim();
          fresh.add(FoodItem(
            id: id,
            restaurantId: restaurantId,
            name: name.isEmpty ? 'Producto' : name,
            description: (item['description'] ?? '').toString(),
            price: _asDouble(item['price']),
            image: _imageForRestaurant(restaurantId),
            category: category.isEmpty ? 'Menú' : category,
            imageUrl: _remoteImageUrl(item),
          ));
        }
      }

      menu.removeWhere((FoodItem item) => item.restaurantId == restaurantId);
      menu.addAll(fresh);
      _menuLoadErrors.remove(restaurantId);
    } finally {
      _menusLoading.remove(restaurantId);
      notifyListeners();
    }
  }

  Future<void> refreshRestaurantMenu(int restaurantId) => _loadRestaurantMenu(restaurantId);
  bool menuLoadFailed(int restaurantId) => _menuLoadErrors.contains(restaurantId);

  void toggleFavorite(int restaurantId) {
    final bool wasFavorite = favorites.contains(restaurantId);
    if (wasFavorite) favorites.remove(restaurantId); else favorites.add(restaurantId);
    notifyListeners();
    api.toggleFavorite(restaurantId).then((bool serverState) {
      if (serverState) favorites.add(restaurantId); else favorites.remove(restaurantId);
      notifyListeners();
    }).catchError((Object _) {
      if (wasFavorite) favorites.add(restaurantId); else favorites.remove(restaurantId);
      notifyListeners();
    });
  }

  void addToCart(FoodItem item, int quantity, {String note = ''}) {
    if (quantity <= 0) return;
    final Restaurant? restaurant = _restaurantById(item.restaurantId);
    if (restaurant == null || !restaurant.isOpen) return;
    // Reject before mutating any existing basket, including unknown old-market shops.
    if (cartRestaurantId != null && cartRestaurantId != item.restaurantId) cart.clear();
    cartRestaurantId = item.restaurantId;
    if (!restaurant.delivery && restaurant.pickup) deliveryMode = 'pickup';
    CartLine? existing;
    for (final CartLine line in cart) { if (line.item.id == item.id) { existing = line; break; } }
    if (existing == null) cart.add(CartLine(item: item, quantity: quantity, note: note));
    else { existing.quantity += quantity; if (note.trim().isNotEmpty) existing.note = note.trim(); }
    notifyListeners();
  }

  void changeQuantity(CartLine line, int delta) {
    line.quantity += delta;
    if (line.quantity <= 0) cart.remove(line);
    if (cart.isEmpty) cartRestaurantId = null;
    notifyListeners();
  }

  double get subtotal => cart.fold<double>(0, (double v, CartLine l) => v + l.total);
  Restaurant? get cartRestaurant => cartRestaurantId == null ? null : _restaurantById(cartRestaurantId!);
  double get deliveryFee => deliveryMode == 'pickup' ? 0 : (cartRestaurant?.deliveryFee ?? 0);
  double get discount => 0; // El servidor calcula cupones y promociones.
  double get total => subtotal + deliveryFee + (deliveryMode == 'delivery' ? tip : 0);
  CheckoutPricingPreview get checkoutPreview => CheckoutPricingPreview(
    policy: customerPricingPolicy,
    merchandiseSubtotal: subtotal,
    restaurantDeliveryFee: cartRestaurant?.deliveryFee ?? 0,
    deliveryMode: deliveryMode,
    tip: tip,
    hasCoupon: coupon.isNotEmpty,
    plusMember: plusMember,
  );


  void setDeliveryMode(String value) { deliveryMode = value; notifyListeners(); }
  void setTip(double value) { tip = value; notifyListeners(); }
  void setCoupon(String value) { coupon = value.trim(); notifyListeners(); }

  bool get hasAvailablePaymentMethod => cashPayments || mercadoPagoPayments || stripePayments;

  bool isPaymentMethodEnabled(String value) {
    if (value == 'cash') return cashPayments;
    if (value == 'mercadopago') return mercadoPagoPayments;
    if (value == 'stripe') return stripePayments;
    return false;
  }

  void setPaymentMethod(String value) {
    if (!isPaymentMethodEnabled(value)) return;
    paymentMethod = value;
    notifyListeners();
  }

  Future<void> refreshPaymentMethods() async {
    final dynamic raw = await api.get('/orders/payment-methods');
    if (raw is! Map) throw ApiException(502, 'El servidor no devolvió métodos de pago válidos.');
    final dynamic rows = raw['methods'];
    bool cash = false;
    bool mp = false;
    bool stripe = false;
    if (rows is List) {
      for (final dynamic value in rows) {
        if (value is! Map) continue;
        final String id = (value['id'] ?? '').toString();
        final bool enabled = value['enabled'] == true;
        if (id == 'cash') cash = enabled;
        if (id == 'mercadopago') mp = enabled;
        if (id == 'stripe') stripe = enabled;
      }
    }
    // Nunca usar constantes 7%/$39 como fuente de cobro: la API expone
    // parametros comerciales configurables, y el pedido final lo determina Kali.
    customerPricingPolicy = CheckoutPricingPolicy.fromPaymentMethods(raw);
    cashPayments = cash;
    mercadoPagoPayments = mp;
    stripePayments = stripe;
    onlinePayments = mp || stripe;
    if (!isPaymentMethodEnabled(paymentMethod)) {
      if (stripePayments) {
        paymentMethod = 'stripe';
      } else if (mercadoPagoPayments) {
        paymentMethod = 'mercadopago';
      } else if (cashPayments) {
        paymentMethod = 'cash';
      }
    }
    notifyListeners();
  }
  void setAddress(int index) { if (index >= 0 && index < addresses.length) { selectedAddress = index; notifyListeners(); } }

  Future<bool> setDefaultAddressRemote(int index) async {
    if (index < 0 || index >= addresses.length) return false;
    try {
      final int id = addresses[index].id;
      await api.updateCustomerAddress(id, <String, dynamic>{'is_default': true});
      _applyAddresses(await api.addresses());
      lastError = '';
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      lastError = 'No se pudo guardar tu dirección predeterminada.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> addAddressRemote(String label, String address, {double? deviceLat, double? deviceLng}) async {
    if (label.trim().isEmpty || address.trim().length < 5) return false;
    try {
      double? lat; double? lng;
      final dynamic geo = await api.post('/v11/maps/geocode', <String, dynamic>{'query': '${address.trim()}, Jalisco, México', 'limit': 1});
      final List<dynamic> results = List<dynamic>.from(((geo as Map)['results'] ?? const <dynamic>[]) as List);
      if (results.isNotEmpty) {
        final Map<String, dynamic> first = Map<String, dynamic>.from(results.first as Map);
        lat = _asNullableDouble(first['lat']); lng = _asNullableDouble(first['lng']);
      }
      if (lat == null || lng == null) { lat=deviceLat; lng=deviceLng; }
      if (lat == null || lng == null) { lastError='No pudimos validar coordenadas. Usa tu ubicación actual e inténtalo otra vez.'; notifyListeners(); return false; }
      final Map<String, dynamic> row = await api.addAddress(<String, dynamic>{'label': label.trim(), 'address': address.trim(), 'lat': lat, 'lng': lng, 'is_default': addresses.isEmpty});
      addresses.add(_addressFromJson(row));
      selectedAddress = addresses.length - 1;
      notifyListeners();
      return true;
    } on ApiException catch (e) { lastError = e.message; notifyListeners(); return false; }
  }

  Future<bool> removeAddressRemote(int index) async {
    if (index < 0 || index >= addresses.length) return false;
    final AddressEntry row = addresses[index];
    try {
      await api.deleteAddress(row.id);
      addresses.removeAt(index);
      if (addresses.isEmpty) selectedAddress = 0; else if (selectedAddress >= addresses.length) selectedAddress = addresses.length - 1;
      notifyListeners();
      return true;
    } on ApiException catch (e) { lastError = e.message; notifyListeners(); return false; }
  }

  Future<void> _recoverPersistedCheckout() async {
    if (!signedIn || userId <= 0) return;
    try {
      final result = await _orderSubmissionGuard.recover(
        (String reference) async => Map<String, dynamic>.from(
          (await api.get('/orders/by-reference/${Uri.encodeComponent(reference)}')) as Map,
        ),
      );
      if (result == null) return;
      final order = _orderFromJson(result);
      if (!orders.any((OrderEntry existing) => existing.id == order.id)) {
        orders.insert(0, order);
        notifyListeners();
      }
    } on ApiException catch (e) {
      // Never send another order automatically and never delete the
      // encrypted journal because an HTTP error could be transient.
      lastError = e.message;
      notifyListeners();
    }
  }

  Future<OrderEntry> placeOrder() {
    // Prevent two simultaneous button taps from inserting or charging twice.
    final Future<OrderEntry>? inProgress = _activePlaceOrder;
    if (inProgress != null) return inProgress;
    final Future<OrderEntry> next = _placeOrderOnce();
    _activePlaceOrder = next;
    return next;
  }

  Future<OrderEntry> _placeOrderOnce() async {
    final int sessionRevision = _orderSessionRevision;
    try {
    final Restaurant restaurant = cartRestaurant!;
    AddressEntry? address;
    if (deliveryMode == 'delivery') {
      if (addresses.isEmpty) throw ApiException(400, 'Agrega una dirección de entrega antes de continuar.');
      address = addresses[selectedAddress.clamp(0, addresses.length - 1).toInt()];
      if (address.lat == null || address.lng == null) throw ApiException(400, 'Esta dirección todavía no tiene ubicación exacta. Edítala o agrégala de nuevo.');
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      'restaurant_id': restaurant.id,
      'address': deliveryMode == 'delivery' ? address!.address : 'Recoger en ${restaurant.name}',
      'notes': '', 'payment_method': paymentMethod, 'tip': deliveryMode == 'delivery' ? tip : 0,
      'items': cart.map((CartLine line) => <String, dynamic>{'menu_item_id': line.item.id, 'quantity': line.quantity, 'options': line.note}).toList(),
      'order_type': deliveryMode, 'coupon_code': coupon,
      'delivery_lat': deliveryMode == 'delivery' ? address!.lat : null,
      'delivery_lng': deliveryMode == 'delivery' ? address!.lng : null,
    };
    final Map<String, dynamic> raw = await _orderSubmissionGuard.submit(
      payload, (Map<String, dynamic> frozen) => api.createOrder(frozen),
    );
    if (_orderSessionRevision != sessionRevision) {
      throw ApiException(401, 'La sesión cambió mientras se registraba el pedido.');
    }
    final OrderEntry order = _orderFromJson(raw);
    orders.insert(0, order);
    cart.clear(); cartRestaurantId = null; coupon = ''; tip = 20;
    notifyListeners();
    return order;
    } finally {
      if (_orderSessionRevision == sessionRevision) _activePlaceOrder = null;
    }
  }

  Future<String?> startMercadoPago(OrderEntry order) async {
    final Map<String, dynamic> data = await api.checkout(order.id);
    if (data['already_paid'] == true) { order.paymentStatus = 'paid'; notifyListeners(); return null; }
    final String? url = (data['checkout_url'] ?? '').toString().isEmpty ? null : data['checkout_url'].toString();
    if (url == null) throw ApiException(502, 'Mercado Pago no devolvió una URL de checkout.');
    await NativeBridge.openExternal(url);
    return url;
  }

  Future<bool> startStripePayment(OrderEntry order) async {
    try {
      final Map<String, dynamic> config = await api.stripeConfig();
      if (config['enabled'] != true) {
        throw ApiException(503, 'Stripe no está disponible en este momento.');
      }
      final Map<String, dynamic> intent = await api.stripePaymentIntent(order.id);
      if (intent['already_paid'] == true || intent['payment_status'] == 'paid') {
        order.paymentStatus = 'paid';
        notifyListeners();
        return true;
      }
      if (intent['payment_status'] == 'pending_confirmation') {
        await refreshOrder(order);
        return true;
      }
      final String clientSecret = (intent['client_secret'] ?? '').toString();
      final String publishableKey = (intent['publishable_key'] ?? config['publishable_key'] ?? '').toString();
      final String merchantCountry = (config['merchant_country'] ?? 'MX').toString();
      final String appleMerchantId = (config['apple_merchant_id'] ?? '').toString();
      if (clientSecret.isEmpty || publishableKey.isEmpty) {
        throw ApiException(502, 'Stripe no devolvió la configuración necesaria para pagar.');
      }

      Stripe.publishableKey = publishableKey;
      Stripe.urlScheme = 'talaeats';
      if (Platform.isIOS && appleMerchantId.isNotEmpty) {
        Stripe.merchantIdentifier = appleMerchantId;
      }
      await Stripe.instance.applySettings();

      final bool testEnv = publishableKey.startsWith('pk_test_');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Tala Eats',
          returnURL: 'talaeats://stripe-redirect',
          style: ThemeMode.system,
          googlePay: Platform.isAndroid
              ? PaymentSheetGooglePay(
                  merchantCountryCode: merchantCountry,
                  currencyCode: 'MXN',
                  testEnv: testEnv,
                  buttonType: PlatformButtonType.pay,
                )
              : null,
          applePay: Platform.isIOS && appleMerchantId.isNotEmpty
              ? PaymentSheetApplePay(
                  merchantCountryCode: merchantCountry,
                  buttonType: PlatformButtonType.order,
                )
              : null,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      // PaymentSheet success is not authoritative. The backend webhook owns
      // payment_status, so refresh and keep pending until the server says paid.
      await refreshOrder(order);
      return true;
    } on StripeException catch (e) {
      // Closing/backing out of Stripe is a user cancellation, not a failed
      // delivery order. The UI will cancel the temporary backend reservation
      // and restore the cart before leaving the payment screen.
      if (e.error.code == FailureCode.Canceled) return false;
      final String message = e.error.localizedMessage?.trim().isNotEmpty == true
          ? e.error.localizedMessage!.trim()
          : 'No pudimos completar el pago con Stripe.';
      throw ApiException(0, message);
    }
  }

  Future<void> refreshOrder(OrderEntry order) async {
    final Map<String, dynamic> live = await api.liveOrder(order.id);
    final Map<String, dynamic> raw = Map<String, dynamic>.from(live['order'] as Map);
    final OrderEntry fresh = _orderFromJson(raw);
    order.status = fresh.status; order.rawStatus = fresh.rawStatus; order.paymentStatus = fresh.paymentStatus; order.eta = fresh.eta;
    notifyListeners();
  }

  Future<void> refreshOrders() async {
    try { _applyOrders(await api.orders()); notifyListeners(); } catch (_) {}
  }

  Future<bool> submitReview(OrderEntry order, int restaurantRating, {String comment = ''}) async {
    try {
      await api.post('/platform/reviews', <String,dynamic>{'order_id':order.id,'restaurant_rating':restaurantRating,'comment':comment.trim()});
      return true;
    } on ApiException catch(e) { lastError=e.message; notifyListeners(); return false; }
  }

  Future<bool> cancelOrder(OrderEntry order) async {
    try {
      final dynamic raw = await api.post('/orders/${order.id}/cancel?reason=${Uri.encodeQueryComponent('Cancelado por el cliente desde Android')}');
      final OrderEntry fresh = _orderFromJson(Map<String,dynamic>.from(raw as Map));
      order.status=fresh.status; order.rawStatus=fresh.rawStatus; order.paymentStatus=fresh.paymentStatus; notifyListeners(); return true;
    } on ApiException catch(e) { lastError=e.message; notifyListeners(); return false; }
  }

  /// Cancels an unpaid provider reservation and restores the user's cart.
  /// A final server refresh prevents cancelling an order that won a race and
  /// was already confirmed as paid by the provider webhook.
  Future<bool> abandonPendingOnlineOrder(OrderEntry order) async {
    if (!order.isOnlinePayment) return false;
    try {
      try {
        await refreshOrder(order);
      } on ApiException {
        // Cancellation remains server-authoritative even if the preflight
        // refresh failed temporarily. The cancel endpoint will reject a paid
        // order, which protects against a payment/webhook race.
      }
      if (order.paymentStatus == 'paid') return false;
      if (order.rawStatus != 'cancelled') {
        final bool cancelled = await cancelOrder(order);
        if (!cancelled) {
          try { await refreshOrder(order); } on ApiException {}
          return false;
        }
      }
      reorder(order);
      return true;
    } catch (_) {
      return false;
    }
  }

  OrderEntry? get activeOrder {
    for (final OrderEntry order in orders) {
      // Provider-backed orders are only operational once the backend confirms
      // payment. A pending Stripe/MP reservation must never look like an active
      // delivery order on Home.
      if (order.isAwaitingOnlinePayment) continue;
      if (!<String>{'Entregado','Recogido','Cancelado'}.contains(order.status)) return order;
    }
    return null;
  }

  void reorder(OrderEntry order) {
    cart.clear(); cartRestaurantId = order.restaurant.id; deliveryMode = order.deliveryMode;
    for (final CartLine line in order.lines) cart.add(CartLine(item: line.item, quantity: line.quantity, note: line.note));
    notifyListeners();
  }

  Future<bool> redeemReward() async {
    try {
      await api.post('/platform/rewards/redeem?points=500');
      _applyWallet(await api.wallet()); notifyListeners(); return true;
    } on ApiException catch (e) { lastError = e.message; return false; }
  }

  void setMarketing(bool value) {
    marketing = value;
    _syncPrivacy();
    unawaited(_nativePush.updateMarketing(api, value).catchError((Object _) {}));
    notifyListeners();
  }
  void setPersonalizedExperience(bool value) { personalizedExperience = value; _syncPrivacy(); notifyListeners(); }
  void setAnalytics(bool value) { analytics = value; _syncPrivacy(); notifyListeners(); }
  void setOrderPush(bool value) { orderPush = value; notifyListeners(); }
  void setPromoPush(bool value) { promoPush = value; notifyListeners(); }
  void setRewardPush(bool value) { rewardPush = value; notifyListeners(); }
  void setTwoFactor(bool value) { twoFactor = value; notifyListeners(); }

  void _syncPrivacy() {
    api.updatePrivacy(<String, dynamic>{'marketing_opt_in': marketing, 'analytics_opt_in': analytics, 'personalization_opt_in': personalizedExperience}).catchError((Object _) => <String, dynamic>{});
  }

  Future<bool> updateProfile(String name, String phone) async {
    try { final dynamic raw=await api.patch('/auth/me',<String,dynamic>{'name':name.trim(),'phone':phone.trim()}); _applyUser(Map<String,dynamic>.from(raw as Map)); notifyListeners(); return true; }
    on ApiException catch(e){lastError=e.message;notifyListeners();return false;}
  }


  Future<bool> pickProfilePhoto() async {
    try {
      final String? path = await NativeBridge.pickProfilePhoto(userId);
      if (path == null || path.trim().isEmpty) return false;
      userLocalAvatarPath = path;
      notifyListeners();
      return true;
    } catch (_) {
      lastError = 'No pudimos abrir tu galería. Revisa los permisos del dispositivo.';
      notifyListeners();
      return false;
    }
  }

  Future<void> removeLocalProfilePhoto() async {
    await NativeBridge.clearProfilePhoto(userId);
    userLocalAvatarPath = '';
    notifyListeners();
  }

  Future<void> markNotificationRead(NotificationEntry notification) async {
    if (notification.isRead) return;
    try {
      await api.patch('/platform/notifications/${notification.id}/read');
      _applyNotifications(await api.notifications());
      notifyListeners();
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await api.post('/platform/notifications/read-all');
      _applyNotifications(await api.notifications());
      notifyListeners();
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
    }
  }

  Future<bool> createSupportTicket(String message, {int? orderId, String category = 'general'}) async {
    if (message.trim().length < 5) return false;
    try {
      await api.post('/platform/support', <String, dynamic>{'order_id': orderId, 'category': category, 'message': message.trim()});
      return true;
    } on ApiException catch (e) { lastError = e.message; return false; }
  }

  void _applyUser(Map<String, dynamic> user) {
    userId = _asInt(user['id']); userName = (user['name'] ?? '').toString(); userEmail = (user['email'] ?? '').toString(); userPhone=(user['phone']??'').toString(); userAvatarUrl=(user['avatar_url']??'').toString();
    twoFactor = user['two_factor_enabled'] == true; marketing = user['marketing_opt_in'] != false;
    analytics = user['analytics_opt_in'] != false; personalizedExperience = user['personalization_opt_in'] != false;
  }

  void _applyBootstrap(Map<String, dynamic> data) {
    if (data['user'] is Map) _applyUser(Map<String, dynamic>.from(data['user'] as Map));
    if (data['wallet'] is Map) { final Map<String, dynamic> w = Map<String, dynamic>.from(data['wallet'] as Map); wallet = _asDouble(w['balance']); points = _asInt(w['points']); }
    unreadNotifications = _asInt(data['unread_notifications']); onlinePayments = data['online_payments'] == true; googleSignin = data['google_signin'] == true;
    supportEmail = (data['support_email'] ?? supportEmail).toString();
  }

  void _applyRestaurants(List<dynamic> rows) {
    _marketCatalogEpoch++;
    restaurants
      ..clear()
      ..addAll(rows.map((dynamic raw) {
        final Map<String, dynamic> r = Map<String, dynamic>.from(raw as Map);
        final int id = _asInt(r['id']); final int eta = _asInt(r['eta_min']);
        return Restaurant(id: id, name: (r['name'] ?? 'Restaurante').toString(), category: (r['cuisine'] ?? 'Comida local').toString(), rating: _asDouble(r['rating']), eta: '$eta-${eta + 10} min', deliveryFee: _asDouble(r['delivery_fee']), image: _imageForRestaurant(id), description: (r['description'] ?? '').toString(), promo: r['sponsored'] == true ? 'Patrocinado' : '', delivery: true, pickup: r['pickup_enabled'] != false, isOpen:r['is_open']!=false, imageUrl:_remoteImageUrl(r));
      }));
    final Set<int> availableIds = restaurants.map((Restaurant r) => r.id).toSet();
    menu.removeWhere((FoodItem item) => !availableIds.contains(item.restaurantId));
  }

  void _applyAddresses(List<dynamic> rows) {
    addresses..clear()..addAll(rows.map((dynamic raw) => _addressFromJson(Map<String, dynamic>.from(raw as Map))));
    if (addresses.isEmpty) selectedAddress = 0; else { final int d = addresses.indexWhere((AddressEntry a) => a.isDefault); selectedAddress = d >= 0 ? d : 0; }
  }

  void _applyOrders(List<dynamic> rows) { orders..clear()..addAll(rows.map((dynamic raw) => _orderFromJson(Map<String, dynamic>.from(raw as Map)))); }
  void _applyFavorites(List<dynamic> rows) { favorites..clear()..addAll(rows.map((dynamic raw) => _asInt((raw as Map)['id']))); }
  void _applyWallet(Map<String, dynamic> row) { wallet = _asDouble(row['balance']); points = _asInt(row['points']); plusMember=row['plus_member']==true; referralCode=(row['referral_code']??referralCode).toString(); walletTransactions..clear()..addAll(List<dynamic>.from((row['transactions']??const <dynamic>[]) as List).map((dynamic x)=>Map<String,dynamic>.from(x as Map))); }
  void _applyLoyalty(Map<String,dynamic> row){points=_asInt(row['points']);wallet=_asDouble(row['wallet_balance']);loyaltyTier=(row['tier']??'BRONZE').toString();plusMember=row['plus_member']==true;referralCode=(row['referral_code']??'').toString();}
  void _applyNotifications(List<dynamic> rows) {
    notifications..clear()..addAll(rows.map((dynamic raw) { final Map<String,dynamic> n=Map<String,dynamic>.from(raw as Map); return NotificationEntry(id:_asInt(n['id']),kind:(n['kind']??'').toString(),title:(n['title']??'').toString(),message:(n['message']??'').toString(),isRead:n['is_read']==true,createdAt:(n['created_at']??'').toString()); }));
    unreadNotifications = notifications.where((NotificationEntry n) => !n.isRead).length;
  }
  void _applyPrivacy(Map<String, dynamic> row) { marketing = row['marketing_opt_in'] != false; analytics = row['analytics_opt_in'] != false; personalizedExperience = row['personalization_opt_in'] != false; }

  AddressEntry _addressFromJson(Map<String, dynamic> r) => AddressEntry(id:_asInt(r['id']),label:(r['label']??'Casa').toString(),address:(r['address']??'').toString(),lat:_asNullableDouble(r['lat']),lng:_asNullableDouble(r['lng']),isDefault:r['is_default']==true);

  OrderEntry _orderFromJson(Map<String, dynamic> raw) {
    final int restaurantId = _asInt(raw['restaurant_id']);
    final Restaurant restaurant = _restaurantById(restaurantId) ?? Restaurant(id: restaurantId, name: 'Restaurante', category: 'Tala Eats', rating: 0, eta: '${_asInt(raw['estimated_minutes'])} min', deliveryFee: _asDouble(raw['delivery_fee']), image: _imageForRestaurant(restaurantId), description: '');
    final List<CartLine> lines = <CartLine>[];
    for (final dynamic value in List<dynamic>.from((raw['items'] ?? const <dynamic>[]) as List)) {
      final Map<String, dynamic> i = Map<String, dynamic>.from(value as Map); final int itemId=_asInt(i['menu_item_id']);
      final FoodItem item = FoodItem(id:itemId,restaurantId:restaurantId,name:(i['name_snapshot']??'Producto').toString(),description:'',price:_asDouble(i['unit_price']),image:_imageForRestaurant(restaurantId),category:'Pedido',imageUrl:_remoteImageUrl(i));
      lines.add(CartLine(item:item,quantity:_asInt(i['quantity']),note:(i['options_snapshot']??'').toString()));
    }
    final String rawStatus=(raw['status']??'received').toString();
    final String paymentStatus=(raw['payment_status']??'pending').toString();
    final String paymentMethod=(raw['payment_method']??'cash').toString();
    final String orderType=(raw['order_type']??'delivery').toString();
    String customerStatus=_statusLabel(rawStatus,orderType);
    if (rawStatus != 'cancelled' &&
        <String>{'stripe','mercadopago'}.contains(paymentMethod) &&
        paymentStatus != 'paid') {
      customerStatus='Pago pendiente';
    }
    final int eta=_asInt(raw['estimated_minutes']);
    final Map<String,dynamic> driver=raw['driver_info'] is Map ? Map<String,dynamic>.from(raw['driver_info'] as Map) : <String,dynamic>{};
    return OrderEntry(id:_asInt(raw['id']),restaurant:restaurant,total:_asDouble(raw['total']),status:customerStatus,deliveryMode:orderType,lines:lines,eta:eta>0?'$eta min':'Calculando…',pin:(raw['delivery_pin']??'').toString(),paymentStatus:paymentStatus,paymentMethod:paymentMethod,rawStatus:rawStatus,driverName:(driver['name']??'').toString(),driverVehicle:(driver['vehicle']??'').toString(),driverRating:_asDouble(driver['rating']));
  }

  Restaurant? _restaurantById(int id) { for (final Restaurant r in restaurants) { if (r.id==id) return r; } return null; }
  String _remoteImageUrl(Map<String, dynamic> row) {
    String normalize(dynamic raw) {
      final String value = (raw ?? '').toString().trim();
      if (value.startsWith('https://')) return value;
      if (value.startsWith('/')) {
        final Uri base = Uri.parse(kProductionApiBase);
        return base.replace(path: value, query: null, fragment: null).toString();
      }
      return '';
    }

    for (final String key in <String>[
      'cover_image_url',
      'image_url',
      'banner_url',
      'photo_url',
      'cover_url',
      'hero_image_url',
    ]) {
      final String value = normalize(row[key]);
      if (value.isNotEmpty) return value;
    }

    for (final String key in <String>['media', 'image', 'photo', 'cover']) {
      final dynamic nested = row[key];
      if (nested is Map) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(nested);
        for (final String child in <String>['url', 'public_url', 'image_url']) {
          final String value = normalize(map[child]);
          if (value.isNotEmpty) return value;
        }
      }
    }
    return '';
  }
  String _imageForRestaurant(int id) => ''; // Production: never substitute a real merchant/dish with demo food media.
  static bool _asBool(dynamic value, {bool defaultValue = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true' || text == '1' || text == 'yes' || text == 'on') return true;
    if (text == 'false' || text == '0' || text == 'no' || text == 'off') return false;
    return defaultValue;
  }
  static int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
  static double _asDouble(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;
  static double? _asNullableDouble(dynamic value) => value == null ? null : double.tryParse(value.toString());
  static String _statusLabel(String raw, String type) {
    const Map<String,String> map=<String,String>{'received':'Recibido','confirmed':'Confirmado','preparing':'Preparando','ready':'Listo','assigned':'Repartidor asignado','picked_up':'Recogido por repartidor','on_the_way':'En camino','delivered':'Entregado','cancelled':'Cancelado'};
    if (type=='pickup' && raw=='delivered') return 'Recogido';
    return map[raw] ?? raw;
  }
}

class TalaEatsApp extends StatefulWidget {
  const TalaEatsApp({super.key, this.testMode = false});

  final bool testMode;

  @override
  State<TalaEatsApp> createState() => _TalaEatsAppState();
}

class _TalaEatsAppState extends State<TalaEatsApp> {
  final TalaModel model = TalaModel();
  bool booted = false;

  @override
  void initState() {
    super.initState();
    if (widget.testMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => booted = true);
      });
      return;
    }
    // The brand moment lasts ~1.1 s and runs in parallel with the real
    // bootstrap; it never delays a slower bootstrap any further.
    Future.wait<void>(<Future<void>>[
      model.initialize(),
      Future<void>.delayed(const Duration(milliseconds: 1100)),
    ]).whenComplete(() {
      if (mounted) setState(() => booted = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tala Eats',
      theme: buildTalaTheme(),
      home: AnimatedBuilder(
        animation: model,
        builder: (BuildContext context, Widget? child) {
          final String stage;
          final Widget screen;
          if (!booted) {
            stage = 'launch';
            screen = const LaunchScreen();
          } else if (!model.signedIn) {
            if (model.pendingResetToken.isNotEmpty) {
              stage = 'reset';
              screen = ResetPasswordScreen(model: model, resetToken: model.pendingResetToken);
            } else {
              stage = 'login';
              screen = LoginScreen(model: model);
            }
          } else {
            stage = 'shell';
            screen = CustomerShell(model: model);
          }
          return AnimatedSwitcher(
            duration: TalaMotion.of(context, const Duration(milliseconds: 420)),
            switchInCurve: TalaMotion.ease,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(key: ValueKey<String>(stage), child: screen),
          );
        },
      ),
    );
  }
}

/// Brand mark: rounded tile with the delivery glyph.
class TalaLogoMark extends StatelessWidget {
  const TalaLogoMark({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFF7A3D), kBrand, kBrandDeep]),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: <BoxShadow>[BoxShadow(color: kBrand.withValues(alpha: 0.28), blurRadius: size * 0.34, offset: Offset(0, size * 0.14))],
      ),
      child: Icon(Icons.delivery_dining_rounded, color: Colors.white, size: size * 0.54),
    );
  }
}

/// Splash: centered brand, one elegant entrance, a quiet loader.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final Animation<double> _mark = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.62, curve: Curves.easeOutCubic));
  late final Animation<double> _word = CurvedAnimation(parent: _controller, curve: const Interval(0.22, 0.85, curve: Curves.easeOutCubic));
  late final Animation<double> _loader = CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1, curve: Curves.easeOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TalaMotion.reduced(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF6),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: AuthBackdrop()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FadeTransition(
                  opacity: _mark,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.86, end: 1).animate(_mark),
                    child: const TalaLogoMark(size: 88),
                  ),
                ),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: _word,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(_word),
                    child: const Column(
                      children: <Widget>[
                        Text('Tala Eats', style: TextStyle(color: kInk, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.1)),
                        SizedBox(height: 6),
                        Text('Tu comida favorita, más cerca.', style: TextStyle(color: kMuted, fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 56,
            child: FadeTransition(
              opacity: _loader,
              child: Center(
                child: SizedBox(
                  width: 64,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const LinearProgressIndicator(minHeight: 3, backgroundColor: kSoftOrange, color: kBrand),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
