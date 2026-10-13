import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'optional_image_cache.dart';

import '../../core/failures.dart';
import '../../models/entities.dart';
import '../repositories.dart';
import 'remote_api.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this.api);

  final RemoteApi api;

  Future<UserSession> registerAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await api.post(
      '/auth/register',
      auth: false,
      body: <String, dynamic>{
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
    return await _consumeAuth(data);
  }

  Future<UserSession> _consumeAuth(dynamic data) async {
    if (data is! Map) throw const AppFailure(FailureKind.server);
    final map = Map<String, dynamic>.from(data);
    final token = '${map['access_token'] ?? ''}';
    final deviceToken = '${map['device_token'] ?? ''}';
    final rawUser = map['user'];
    if (token.isEmpty || token == 'cookie' || rawUser is! Map) {
      throw const AppFailure(
        FailureKind.server,
        'El servidor no devolvió una sesión móvil válida. No se guardó ninguna credencial.',
      );
    }
    final parsed = UserSession.fromJson(Map<String, dynamic>.from(rawUser));
    if (parsed.id <= 0 || parsed.role.isEmpty) {
      throw const AppFailure(
        FailureKind.server,
        'La respuesta de autenticación no contiene una cuenta válida.',
      );
    }
    await api.session.saveTokens(accessToken: token, deviceToken: deviceToken);
    return parsed;
  }

  @override
  Future<UserSession?> restoreSession() async {
    final token = await api.session.accessToken();
    if (token == null || token.isEmpty) return null;
    try {
      final data = await api.get('/auth/me');
      if (data is! Map) throw const AppFailure(FailureKind.server);
      return UserSession.fromJson(Map<String, dynamic>.from(data));
    } on AppFailure catch (failure) {
      if (failure.kind == FailureKind.sessionExpired) {
        await api.session.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    String otp = '',
  }) async {
    final data = await api.post(
      '/auth/login',
      auth: false,
      body: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': password,
        'otp': otp.trim(),
      },
    );
    return await _consumeAuth(data);
  }

  @override
  Future<void> signOut() async {
    try {
      await api.post('/auth/logout', body: const <String, dynamic>{});
    } finally {
      await api.session.clear();
    }
  }

  @override
  Future<TwoFactorSetup> beginTwoFactorSetup() async {
    final data = await api.post('/v9/security/2fa/setup');
    if (data is! Map) throw const AppFailure(FailureKind.server);
    final map = Map<String, dynamic>.from(data);
    return TwoFactorSetup(
      secret: '${map['secret'] ?? ''}',
      otpauthUri: '${map['otpauth_uri'] ?? ''}',
    );
  }

  @override
  Future<UserSession> confirmTwoFactor(String code) async {
    await api.post(
      '/v9/security/2fa/confirm',
      body: <String, dynamic>{'code': code.trim()},
    );
    final data = await api.get('/auth/me');
    if (data is! Map) throw const AppFailure(FailureKind.server);
    return UserSession.fromJson(Map<String, dynamic>.from(data));
  }
}

class RemoteOnboardingRepository implements OnboardingRepository {
  RemoteOnboardingRepository(this.api, this.auth);

  final RemoteApi api;
  final RemoteAuthRepository auth;

  static const _started = 'remote_restaurant_onboarding_started_v1';
  static const _pendingDraft = 'remote_pending_product_draft_v1';
  static const _pendingSynced = 'remote_pending_product_synced_v1';
  static const _restaurantImage = 'remote_restaurant_image_local_v1';
  static const _productImages = 'remote_product_images_local_v1';

  @override
  Future<bool> isSetupComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_started) ?? false;
  }

  @override
  Future<UserSession> createRestaurant(OnboardingDraft draft) async {
    UserSession session;
    try {
      session = await auth.registerAccount(
        name: draft.ownerName,
        email: draft.email,
        password: draft.password,
      );
    } on AppFailure catch (failure) {
      if (failure.kind != FailureKind.conflict) rethrow;
      session = await auth.signIn(
        email: draft.email,
        password: draft.password,
      );
    }

    if (draft.phone.trim().isNotEmpty) {
      final updated = await api.patch(
        '/auth/me',
        body: <String, dynamic>{'phone': draft.phone.trim()},
      );
      if (updated is Map) {
        session = UserSession.fromJson(Map<String, dynamic>.from(updated));
      }
    }

    final documents = <String>[];
    if (draft.restaurantImage.trim().isNotEmpty) {
      documents.add(await api.uploadOnboardingFile(draft.restaurantImage));
    }
    if (draft.product.imagePath.trim().isNotEmpty) {
      documents.add(await api.uploadOnboardingFile(draft.product.imagePath));
    }

    try {
      await api.post(
        '/operations/onboarding',
        body: <String, dynamic>{
          'entity_type': 'restaurant',
          'business_name': draft.restaurantName.trim(),
          'tax_id': '',
          'vehicle': '',
          'payout_account_ref': '',
          'documents': documents,
        },
      );
    } on AppFailure catch (failure) {
      if (failure.kind != FailureKind.conflict) rethrow;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_started, true);
    await prefs.setBool(_pendingSynced, false);
    await prefs.setString(_restaurantImage, draft.restaurantImage);
    await prefs.setString(
      _pendingDraft,
      jsonEncode(<String, dynamic>{
        'restaurant_name': draft.restaurantName.trim(),
        'cuisine': draft.cuisine.trim(),
        'restaurant_description': draft.description.trim(),
        'name': draft.product.name.trim(),
        'description': draft.product.description.trim(),
        'category': draft.product.category.trim(),
        'price': draft.product.price,
        'stock': draft.product.stock,
        'is_available': draft.product.isAvailable,
        'allergens': draft.product.allergens.trim(),
        'is_combo': draft.product.isCombo,
        'image_path': draft.product.imagePath,
      }),
    );
    return session;
  }

  @override
  Future<OnboardingApplication?> latestApplication() async {
    final data = await api.get('/operations/onboarding/mine');
    if (data is! List || data.isEmpty) return null;
    for (final item in data) {
      if (item is Map && '${item['entity_type'] ?? ''}' == 'restaurant') {
        return OnboardingApplication.fromJson(Map<String, dynamic>.from(item));
      }
    }
    return null;
  }

  @override
  Future<void> syncPendingProductIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_pendingSynced) == true) return;
    final raw = prefs.getString(_pendingDraft);
    if (raw == null || raw.isEmpty) return;
    final draft = Map<String, dynamic>.from(jsonDecode(raw) as Map);

    final restaurantData = await api.patch(
      '/owner/restaurant',
      body: <String, dynamic>{
        'name': '${draft['restaurant_name'] ?? ''}',
        'cuisine': '${draft['cuisine'] ?? 'Comida local'}',
        'description': '${draft['restaurant_description'] ?? ''}',
      },
    );
    if (restaurantData is! Map) throw const AppFailure(FailureKind.server);
    final legacyRestaurantImage = prefs.getString(_restaurantImage) ?? '';
    if (legacyRestaurantImage.isNotEmpty &&
        !legacyRestaurantImage.startsWith('http://') &&
        !legacyRestaurantImage.startsWith('https://')) {
      try {
        final url = await api.uploadCatalogImage(legacyRestaurantImage, '/uploads/catalog/restaurant-cover');
        await prefs.setString(_restaurantImage, url);
      } on AppFailure {
        // Se conserva la foto local y se reintentará al cargar/editar el perfil.
      }
    }

    final detail = await api.get('/owner/restaurant');
    final current = detail is Map
        ? (detail['menu_items'] as List? ?? const <dynamic>[])
        : const <dynamic>[];
    final wantedName = '${draft['name'] ?? ''}'.trim().toLowerCase();
    Map<String, dynamic>? created;
    for (final item in current) {
      if (item is Map && '${item['name'] ?? ''}'.trim().toLowerCase() == wantedName) {
        created = Map<String, dynamic>.from(item);
        break;
      }
    }
    created ??= Map<String, dynamic>.from(
      await api.post(
        '/owner/menu',
        body: <String, dynamic>{
          'name': '${draft['name'] ?? ''}',
          'description': '${draft['description'] ?? ''}',
          'category': '${draft['category'] ?? 'General'}',
          'price': draft['price'] ?? 0,
          'is_available': draft['is_available'] != false,
          'stock': draft['stock'] ?? 0,
          'dietary_tags': '',
          'allergens': '${draft['allergens'] ?? ''}',
          'is_combo': draft['is_combo'] == true,
          'options_json': '[]',
          'availability_schedule_json': '{}',
          'price_schedule_json': '{}',
        },
      ) as Map,
    );

    final imagePath = '${draft['image_path'] ?? ''}';
    if (imagePath.isNotEmpty) {
      final imageMap = _decodeImageMap(prefs.getString(_productImages));
      var finalImage = imagePath;
      if (!imagePath.startsWith('http://') && !imagePath.startsWith('https://')) {
        try {
          finalImage = await api.uploadCatalogImage(imagePath, '/uploads/catalog/menu/${created['id']}');
        } on AppFailure {
          // Mantener la referencia local hasta poder sincronizarla.
        }
      }
      imageMap['${created['id']}'] = finalImage;
      await prefs.setString(_productImages, jsonEncode(imageMap));
    }
    await prefs.setBool(_pendingSynced, true);
  }

  static Map<String, dynamic> _decodeImageMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

class RemoteRestaurantRepository implements RestaurantRepository {
  RemoteRestaurantRepository(this.api, {OptionalImageCache? cache})
      : _cache = cache ?? OptionalImageCache();
  final RemoteApi api;
  final OptionalImageCache _cache;

  static const _restaurantImage = 'remote_restaurant_image_local_v1';

  @override
  Future<RestaurantInfo> fetchRestaurant() async {
    final data = await api.get('/owner/restaurant');
    if (data is! Map) throw const AppFailure(FailureKind.server);
    final map = Map<String, dynamic>.from(data);
    // Los datos de negocio vienen del servidor. Si falla el cache del
    // dispositivo, nunca convertir una respuesta valida en error de panel.
    var info = RestaurantInfo.fromJson(map);
    final legacy = await _cache.read(_restaurantImage) ?? '';
    if (info.imagePath.trim().isEmpty && legacy.trim().isNotEmpty) {
      var migrated = legacy;
      if (!legacy.startsWith('http://') && !legacy.startsWith('https://')) {
        try {
          migrated = await api.uploadCatalogImage(legacy, '/uploads/catalog/restaurant-cover');
          await _cache.write(_restaurantImage, migrated);
        } on AppFailure {
          // Mantener compatibilidad local; una edición futura vuelve a intentar.
        }
      }
      info = info.copyWith(imagePath: migrated);
    } else if (info.imagePath.trim().isNotEmpty) {
      await _cache.write(_restaurantImage, info.imagePath);
    }
    return info;
  }

  @override
  Future<RestaurantInfo> updateProfile(RestaurantProfileInput input) async {
    final data = await api.patch(
      '/owner/restaurant',
      body: <String, dynamic>{
        'name': input.name.trim(),
        'cuisine': input.cuisine.trim(),
        'description': input.description.trim(),
        'eta_min': input.etaMin,
        'delivery_fee': input.deliveryFee,
        'pickup_enabled': input.pickupEnabled,
      },
    );
    if (data is! Map) throw const AppFailure(FailureKind.server);
    var image = input.imagePath.trim();
    if (image.isNotEmpty && !image.startsWith('http://') && !image.startsWith('https://')) {
      image = await api.uploadCatalogImage(image, '/uploads/catalog/restaurant-cover');
      final confirmed = await api.get('/owner/restaurant');
      if (confirmed is! Map || '${confirmed['cover_image_url'] ?? ''}'.trim() != image) {
        throw const AppFailure(FailureKind.server,
            'La portada se envió, pero no aparece guardada en el servidor. Actualiza antes de repetir.');
      }
    }
    if (image.isNotEmpty) await _cache.write(_restaurantImage, image);
    final info = RestaurantInfo.fromJson(Map<String, dynamic>.from(data));
    return info.copyWith(imagePath: image.isNotEmpty ? image : info.imagePath);
  }

  @override
  Future<bool> setRestaurantOpen(bool open) async {
    final data = await api.patch(
      '/owner/restaurant',
      body: <String, dynamic>{'is_open': open},
    );
    if (data is! Map) throw const AppFailure(FailureKind.server);
    return data['is_open'] == true;
  }

  @override
  Future<List<EmployeeInfo>> fetchTeam() async {
    final data = await api.get('/owner/employees');
    if (data is! List) throw const AppFailure(FailureKind.server);
    return data
        .whereType<Map>()
        .map((e) => EmployeeInfo.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  Future<EmployeeInfo> inviteEmployee({
    required String email,
    required String role,
  }) async {
    final data = await api.post(
      '/owner/employees',
      query: <String, String>{
        'email': email.trim().toLowerCase(),
        'role': role,
      },
    );
    if (data is! Map) throw const AppFailure(FailureKind.server);
    return EmployeeInfo.fromJson(Map<String, dynamic>.from(data));
  }
}

class RemoteMenuRepository implements MenuRepository {
  RemoteMenuRepository(this.api, {OptionalImageCache? cache})
      : _cache = cache ?? OptionalImageCache();
  final RemoteApi api;
  final OptionalImageCache _cache;

  static const _productImages = 'remote_product_images_local_v1';

  Future<Map<String, dynamic>> _images() async {
    final raw = await _cache.read(_productImages);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveImage(int id, String path) async {
    if (path.trim().isEmpty) return;
    final map = await _images();
    map['$id'] = path;
    await _cache.write(_productImages, jsonEncode(map));
  }

  MenuProduct _withImage(Map<String, dynamic> raw, Map<String, dynamic> images) {
    final server = '${raw['image_url'] ?? ''}'.trim();
    return MenuProduct.fromJson(<String, dynamic>{
      ...raw,
      'image_path': server.isNotEmpty ? server : '${images['${raw['id']}'] ?? ''}',
    });
  }

  @override
  Future<List<MenuProduct>> fetchMenu() async {
    final data = await api.get('/owner/restaurant');
    if (data is! Map) throw const AppFailure(FailureKind.server);
    final images = await _images();
    var changed = false;
    final result = <MenuProduct>[];
    for (final e in (data['menu_items'] as List? ?? const <dynamic>[]).whereType<Map>()) {
      final raw = Map<String, dynamic>.from(e);
      final id = int.tryParse('${raw['id']}') ?? 0;
      final server = '${raw['image_url'] ?? ''}'.trim();
      final legacy = '${images['$id'] ?? ''}'.trim();
      if (server.isEmpty && legacy.isNotEmpty &&
          !legacy.startsWith('http://') && !legacy.startsWith('https://')) {
        try {
          final url = await api.uploadCatalogImage(legacy, '/uploads/catalog/menu/$id');
          raw['image_url'] = url;
          images['$id'] = url;
          changed = true;
        } on AppFailure {
          // Sigue visible localmente y se reintentará en la siguiente sincronización.
        }
      } else if (server.isNotEmpty && images['$id'] != server) {
        images['$id'] = server;
        changed = true;
      }
      result.add(_withImage(raw, images));
    }
    if (changed) {
      await _cache.write(_productImages, jsonEncode(images));
    }
    return result;
  }

  @override
  Future<MenuProduct> saveProduct(ProductDraft draft) async {
    final body = <String, dynamic>{
      'name': draft.name.trim(),
      'description': draft.description.trim(),
      'category': draft.category.trim().isEmpty ? 'General' : draft.category.trim(),
      'price': draft.price,
      'is_available': draft.isAvailable,
      'stock': draft.stock,
      'allergens': draft.allergens.trim(),
      'is_combo': draft.isCombo,
    };
    final dynamic data = draft.id == null
        ? await api.post('/owner/menu', body: body)
        : await api.patch('/owner/menu/${draft.id}', body: body);
    if (data is! Map) throw const AppFailure(FailureKind.server);
    final raw = Map<String, dynamic>.from(data);
    final id = int.tryParse('${raw['id']}') ?? 0;
    var image = draft.imagePath.trim();
    if (image.isNotEmpty && !image.startsWith('http://') && !image.startsWith('https://')) {
      image = await api.uploadCatalogImage(image, '/uploads/catalog/menu/$id');
      final confirmed = await api.get('/owner/restaurant');
      final items = confirmed is Map ? confirmed['menu_items'] : null;
      final synced = items is List && items.whereType<Map>().any((row) =>
          int.tryParse('${row['id']}') == id &&
          '${row['image_url'] ?? ''}'.trim() == image);
      if (!synced) {
        throw const AppFailure(FailureKind.server,
            'La foto se envió, pero no aparece guardada en el catálogo. Actualiza antes de repetir.');
      }
    }
    if (image.isNotEmpty) {
      raw['image_url'] = image;
      await _saveImage(id, image);
    }
    return _withImage(raw, await _images());
  }

  @override
  Future<MenuProduct> setProductAvailability(int productId, bool available) async {
    final data = await api.patch(
      '/owner/menu/$productId',
      body: <String, dynamic>{'is_available': available},
    );
    if (data is! Map) throw const AppFailure(FailureKind.server);
    return _withImage(Map<String, dynamic>.from(data), await _images());
  }

  @override
  Future<void> deleteProduct(int productId) async {
    await api.delete('/owner/menu/$productId');
    final prefs = await SharedPreferences.getInstance();
    final images = await _images()..remove('$productId');
    await prefs.setString(_productImages, jsonEncode(images));
  }
}

class RemoteOrdersRepository implements OrdersRepository {
  RemoteOrdersRepository(this.api);
  final RemoteApi api;

  @override
  Future<List<RestaurantOrder>> fetchOrders() async {
    final data = await api.get('/owner/orders', query: <String, String>{'limit': '200'});
    if (data is! List) throw const AppFailure(FailureKind.server);
    return data
        .whereType<Map>()
        .map((e) => RestaurantOrder.fromJson(Map<String, dynamic>.from(e)))
        .where((order) =>
            !order.isActive ||
            order.paymentMethod == 'cash' ||
            order.paymentStatus == 'paid')
        .toList(growable: false);
  }

  Future<RestaurantOrder> _status(int id, String status) async {
    final data = await api.patch(
      '/owner/orders/$id/status',
      body: <String, dynamic>{'status': status},
    );
    if (data is! Map) throw const AppFailure(FailureKind.server);
    return RestaurantOrder.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<RestaurantOrder> acceptOrder(int orderId) => _status(orderId, 'confirmed');

  @override
  Future<RestaurantOrder> startPreparation(int orderId) => _status(orderId, 'preparing');

  @override
  Future<RestaurantOrder> markReady(int orderId) => _status(orderId, 'ready');

  @override
  Future<RestaurantOrder> rejectOrder(int orderId) => _status(orderId, 'cancelled');
}

class RemoteFinanceRepository implements FinanceRepository {
  RemoteFinanceRepository(this.api);
  final RemoteApi api;

  Future<List<RestaurantOrder>> _ordersForPeriod(FinancePeriod period) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = switch (period) {
      FinancePeriod.today => 1,
      FinancePeriod.week => 7,
      FinancePeriod.month => 30,
    };
    final start = today.subtract(Duration(days: days - 1));
    final rows = <RestaurantOrder>[];
    var offset = 0;
    const pageSize = 200;
    for (var page = 0; page < 10; page++) {
      final data = await api.get(
        '/owner/orders',
        query: <String, String>{
          'limit': '$pageSize',
          'offset': '$offset',
        },
      );
      if (data is! List) throw const AppFailure(FailureKind.server);
      final pageRows = data
          .whereType<Map>()
          .map((e) => RestaurantOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      rows.addAll(pageRows);
      if (pageRows.length < pageSize) break;
      if (pageRows.isNotEmpty && pageRows.last.createdAt.isBefore(start)) break;
      offset += pageSize;
    }
    return rows;
  }

  @override
  Future<FinanceSummary> fetchSummary(FinancePeriod period) async {
    final all = await _ordersForPeriod(period);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = switch (period) {
      FinancePeriod.today => 1,
      FinancePeriod.week => 7,
      FinancePeriod.month => 30,
    };
    final start = today.subtract(Duration(days: days - 1));
    final scoped = all.where((o) => !o.createdAt.isBefore(start)).toList(growable: false);
    final delivered = scoped.where((o) => o.status == 'delivered').toList(growable: false);
    final cancelled = scoped.where((o) => o.status == 'cancelled').length;
    final daily = <DailySales>[];
    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      final rows = delivered.where(
        (o) => !o.createdAt.isBefore(day) && o.createdAt.isBefore(next),
      );
      daily.add(
        DailySales(
          day: day,
          gross: rows.fold<double>(0, (sum, order) => sum + order.subtotal),
          orders: rows.length,
        ),
      );
    }
    return FinanceSummary(
      period: period,
      grossSales: delivered.fold<double>(0, (sum, order) => sum + order.subtotal),
      netToRestaurant: delivered.fold<double>(
        0,
        (sum, order) => sum + order.restaurantPayout,
      ),
      orders: scoped.length,
      delivered: delivered.length,
      cancelled: cancelled,
      daily: daily,
      movements: delivered,
    );
  }
}
