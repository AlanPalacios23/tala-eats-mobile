import '../../core/failures.dart';
import '../../models/entities.dart';
import '../repositories.dart';
import 'local_backend.dart';
import 'seed_data.dart';

/// Implementaciones locales de los repositorios. Sirven para QA sin servidor
/// y como referencia de comportamiento esperado para la implementación real.

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this.backend);
  final LocalBackend backend;

  @override
  Future<UserSession?> restoreSession() async {
    final p = await backend.prefs();
    final setup = p.getBool(LocalKeys.setupComplete) ?? false;
    final logged = p.getBool(LocalKeys.loggedIn) ?? false;
    if (!setup || !logged) return null;
    return UserSession(
      id: 9100,
      name: p.getString(LocalKeys.ownerName) ?? 'Propietario',
      email: p.getString(LocalKeys.email) ?? '',
      phone: p.getString(LocalKeys.phone) ?? '',
      role: 'owner',
    );
  }

  @override
  Future<void> requestPasswordRecovery(String email) async {
    await backend.simulateWrite();
    if (!email.contains('@')) {
      throw const AppFailure(FailureKind.invalidCredentials);
    }
  }

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    String otp = '',
  }) async {
    await backend.simulateWrite();
    backend.faults.onSignIn();
    final cleanEmail = email.trim();
    if (!cleanEmail.contains('@') || password.isEmpty) {
      throw const AppFailure(FailureKind.invalidCredentials);
    }
    final p = await backend.prefs();
    final storedName = p.getString(LocalKeys.ownerName);
    await p.setBool(LocalKeys.setupComplete, true);
    await p.setBool(LocalKeys.loggedIn, true);
    if (storedName == null) {
      await p.setString(LocalKeys.email, cleanEmail);
    }
    backend.clearMemory();
    return storedName == null
        ? SeedData.owner(email: cleanEmail)
        : UserSession(
            id: 9100,
            name: storedName,
            email: cleanEmail,
            phone: p.getString(LocalKeys.phone) ?? '',
            role: 'owner',
          );
  }

  @override
  Future<TwoFactorSetup> beginTwoFactorSetup() async =>
      const TwoFactorSetup(secret: 'LOCALDEMO2FA', otpauthUri: 'otpauth://totp/TalaEats');

  @override
  Future<UserSession> confirmTwoFactor(String code) async {
    final current = await restoreSession();
    return UserSession(
      id: current?.id ?? 9100,
      name: current?.name ?? 'Propietario',
      email: current?.email ?? '',
      phone: current?.phone ?? '',
      role: current?.role ?? 'restaurant',
      twoFactorEnabled: true,
    );
  }

  @override
  Future<void> signOut() async {
    final p = await backend.prefs();
    await p.setBool(LocalKeys.loggedIn, false);
    backend.clearMemory();
  }
}

class LocalOnboardingRepository implements OnboardingRepository {
  LocalOnboardingRepository(this.backend);
  final LocalBackend backend;

  @override
  Future<bool> isSetupComplete() async {
    final p = await backend.prefs();
    return p.getBool(LocalKeys.setupComplete) ?? false;
  }

  @override
  Future<UserSession> createRestaurant(OnboardingDraft draft) async {
    await backend.simulateWrite();
    await backend.simulateWrite();
    final product = draft.product;
    if (product.imagePath.trim().isEmpty) {
      throw const AppFailure(
        FailureKind.validation,
        'Agrega la foto de tu primer producto.',
      );
    }
    final p = await backend.prefs();
    await p.setString(LocalKeys.ownerName, draft.ownerName.trim());
    await p.setString(LocalKeys.email, draft.email.trim());
    await p.setString(LocalKeys.phone, draft.phone.trim());
    await p.setString(LocalKeys.productName, product.name.trim());
    await p.setString(LocalKeys.productDescription, product.description.trim());
    await p.setString(LocalKeys.productCategory, product.category.trim());
    await p.setDouble(LocalKeys.productPrice, product.price);
    await p.setInt(LocalKeys.productStock, product.stock);
    await p.setString(LocalKeys.productImage, product.imagePath);

    backend.clearMemory();
    final seed = SeedData.restaurant();
    await backend.saveRestaurant(
      seed.copyWith(
        name: draft.restaurantName.trim(),
        cuisine: draft.cuisine.trim(),
        description: draft.description.trim(),
        imagePath: draft.restaurantImage,
        isOpen: true,
      ),
    );
    await backend.saveMenu(<MenuProduct>[
      MenuProduct(
        id: 1,
        name: product.name.trim(),
        description: product.description.trim(),
        category: product.category.trim().isEmpty
            ? 'General'
            : product.category.trim(),
        price: product.price,
        isAvailable: true,
        stock: product.stock,
        allergens: product.allergens.trim(),
        isCombo: false,
        optionsJson: '[]',
        imagePath: product.imagePath,
      ),
    ]);

    await p.setBool(LocalKeys.setupComplete, true);
    await p.setBool(LocalKeys.loggedIn, true);

    return UserSession(
      id: 9100,
      name: draft.ownerName.trim(),
      email: draft.email.trim(),
      phone: draft.phone.trim(),
      role: 'owner',
    );
  }

  @override
  Future<OnboardingApplication?> latestApplication() async {
    final p = await backend.prefs();
    final setup = p.getBool(LocalKeys.setupComplete) ?? false;
    if (!setup) return null;
    return const OnboardingApplication(
      id: 1,
      businessName: 'Restaurante demo',
      status: 'approved',
      notes: '',
    );
  }

  @override
  Future<void> syncPendingProductIfNeeded() async {}
}

class LocalRestaurantRepository implements RestaurantRepository {
  LocalRestaurantRepository(this.backend);
  final LocalBackend backend;

  @override
  Future<RestaurantInfo> fetchRestaurant() async {
    await backend.simulateRead();
    backend.faults.onRead('restaurant');
    return backend.restaurant();
  }

  @override
  Future<RestaurantInfo> updateProfile(RestaurantProfileInput input) async {
    await backend.simulateWrite();
    final current = await backend.restaurant();
    final updated = current.copyWith(
      name: input.name.trim(),
      cuisine: input.cuisine.trim(),
      description: input.description.trim(),
      etaMin: input.etaMin,
      deliveryFee: input.deliveryFee,
      pickupEnabled: input.pickupEnabled,
      imagePath: input.imagePath,
    );
    await backend.saveRestaurant(updated);
    return updated;
  }

  @override
  Future<bool> setRestaurantOpen(bool open) async {
    await backend.simulateWrite();
    final current = await backend.restaurant();
    await backend.saveRestaurant(current.copyWith(isOpen: open));
    return open;
  }

  @override
  Future<List<EmployeeInfo>> fetchTeam() async {
    await backend.simulateRead();
    return backend.team();
  }

  @override
  Future<EmployeeInfo> inviteEmployee({
    required String email,
    required String role,
  }) async {
    await backend.simulateWrite();
    final team = backend.team();
    final clean = email.trim().toLowerCase();
    if (team.any((e) => e.email.toLowerCase() == clean)) {
      throw const AppFailure(
        FailureKind.conflict,
        'Esta persona ya forma parte de tu equipo.',
      );
    }
    final nextId = team.fold<int>(0, (m, e) => e.id > m ? e.id : m) + 1;
    final employee = EmployeeInfo(
      id: nextId,
      userId: 6000 + nextId,
      name: clean.split('@').first,
      email: clean,
      role: role,
    );
    backend.setTeam(<EmployeeInfo>[...team, employee]);
    return employee;
  }
}

class LocalMenuRepository implements MenuRepository {
  LocalMenuRepository(this.backend);
  final LocalBackend backend;

  @override
  Future<List<MenuProduct>> fetchMenu() async {
    await backend.simulateRead();
    backend.faults.onRead('menu');
    return backend.menu();
  }

  @override
  Future<MenuProduct> saveProduct(ProductDraft draft) async {
    await backend.simulateWrite();
    backend.faults.onAction('product');
    final items = List<MenuProduct>.from(await backend.menu());
    final existingIndex =
        draft.id == null ? -1 : items.indexWhere((e) => e.id == draft.id);
    final nextId = items.fold<int>(0, (m, e) => e.id > m ? e.id : m) + 1;
    final product = MenuProduct(
      id: existingIndex >= 0 ? items[existingIndex].id : nextId,
      name: draft.name.trim(),
      description: draft.description.trim(),
      category: draft.category.trim().isEmpty ? 'General' : draft.category.trim(),
      price: draft.price,
      isAvailable: draft.isAvailable,
      stock: draft.stock,
      allergens: draft.allergens.trim(),
      isCombo: draft.isCombo,
      optionsJson:
          existingIndex >= 0 ? items[existingIndex].optionsJson : '[]',
      imagePath: draft.imagePath,
    );
    if (existingIndex >= 0) {
      items[existingIndex] = product;
    } else {
      items.insert(0, product);
    }
    await backend.saveMenu(items);
    return product;
  }

  @override
  Future<MenuProduct> setProductAvailability(
    int productId,
    bool available,
  ) async {
    await backend.simulateWrite();
    backend.faults.onAction('product');
    final items = List<MenuProduct>.from(await backend.menu());
    final index = items.indexWhere((e) => e.id == productId);
    if (index < 0) throw const AppFailure(FailureKind.notFound);
    final updated = items[index].copyWith(isAvailable: available);
    items[index] = updated;
    await backend.saveMenu(items);
    return updated;
  }

  @override
  Future<void> deleteProduct(int productId) async {
    await backend.simulateWrite();
    final items = List<MenuProduct>.from(await backend.menu())
      ..removeWhere((e) => e.id == productId);
    await backend.saveMenu(items);
  }
}

class LocalOrdersRepository implements OrdersRepository {
  LocalOrdersRepository(this.backend);
  final LocalBackend backend;

  @override
  Future<List<RestaurantOrder>> fetchOrders() async {
    await backend.simulateRead();
    backend.faults.onRead('orders');
    return backend.orders();
  }

  Future<RestaurantOrder> _transition(
    int orderId,
    Set<String> from,
    String to,
  ) async {
    await backend.simulateWrite();
    backend.faults.onAction('order');
    final orders = await backend.orders();
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index < 0) throw const AppFailure(FailureKind.notFound);
    final current = orders[index];
    if (!from.contains(current.status)) {
      throw const AppFailure(FailureKind.conflict);
    }
    final updated = current.copyWith(status: to);
    backend.replaceOrder(updated);
    return updated;
  }

  @override
  Future<RestaurantOrder> acceptOrder(int orderId) =>
      _transition(orderId, <String>{'received'}, 'confirmed');

  @override
  Future<RestaurantOrder> startPreparation(int orderId) =>
      _transition(orderId, <String>{'confirmed'}, 'preparing');

  @override
  Future<RestaurantOrder> markReady(int orderId) =>
      _transition(orderId, <String>{'confirmed', 'preparing'}, 'ready');

  @override
  Future<RestaurantOrder> rejectOrder(int orderId) =>
      _transition(orderId, <String>{'received'}, 'cancelled');
}

class LocalFinanceRepository implements FinanceRepository {
  LocalFinanceRepository(this.backend);
  final LocalBackend backend;

  @override
  Future<FinanceSummary> fetchSummary(FinancePeriod period) async {
    await backend.simulateRead();
    backend.faults.onRead('finance:${period.name}');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final orders = await backend.orders();
    final todays = orders
        .where((o) => !o.createdAt.isBefore(today))
        .toList(growable: false);
    final deliveredToday =
        todays.where((o) => o.status == 'delivered').toList(growable: false);
    final cancelledToday = todays.where((o) => o.status == 'cancelled').length;

    if (backend.faults.isEmpty) {
      final days = period == FinancePeriod.today
          ? 1
          : period == FinancePeriod.week
              ? 7
              : 30;
      return FinanceSummary(
        period: period,
        grossSales: 0,
        netToRestaurant: 0,
        orders: 0,
        delivered: 0,
        cancelled: 0,
        daily: List<DailySales>.generate(
          days,
          (i) => DailySales(
            day: today.subtract(Duration(days: days - 1 - i)),
            gross: 0,
            orders: 0,
          ),
        ),
        movements: const <RestaurantOrder>[],
      );
    }

    final todayGross =
        deliveredToday.fold<double>(0, (s, o) => s + o.total);
    final todayNet =
        deliveredToday.fold<double>(0, (s, o) => s + o.restaurantPayout);

    if (period == FinancePeriod.today) {
      return FinanceSummary(
        period: period,
        grossSales: todayGross,
        netToRestaurant: todayNet,
        orders: todays.length,
        delivered: deliveredToday.length,
        cancelled: cancelledToday,
        daily: <DailySales>[
          DailySales(
            day: today,
            gross: todayGross,
            orders: deliveredToday.length,
          ),
        ],
        movements: deliveredToday,
      );
    }

    final days = period == FinancePeriod.week ? 7 : 30;
    final menu = await backend.menu();
    final avgPrice = menu.isEmpty
        ? 180.0
        : menu.fold<double>(0, (s, p) => s + p.price) / menu.length * 2.2;
    final history = SeedData.dailyHistory(
      today: today,
      days: days - 1,
      avgTicket: avgPrice,
    ).map((d) => DailySales(
          day: d.day.subtract(const Duration(days: 1)),
          gross: d.gross,
          orders: d.orders,
        ));
    final daily = <DailySales>[
      ...history,
      DailySales(day: today, gross: todayGross, orders: deliveredToday.length),
    ];
    final gross = daily.fold<double>(0, (s, d) => s + d.gross);
    final delivered = daily.fold<int>(0, (s, d) => s + d.orders);
    final ratio = todayGross == 0 ? 0.85 : todayNet / todayGross;
    return FinanceSummary(
      period: period,
      grossSales: gross,
      netToRestaurant: double.parse((gross * ratio).toStringAsFixed(2)),
      orders: delivered + cancelledToday + (todays.length - deliveredToday.length - cancelledToday),
      delivered: delivered,
      cancelled: cancelledToday,
      daily: daily,
      movements: deliveredToday,
    );
  }
}
