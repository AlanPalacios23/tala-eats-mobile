import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/failures.dart';
import '../data/app_services.dart';
import '../models/entities.dart';

enum LoadStatus { initial, loading, ready, failure }

/// Estado operativo del panel (restaurante, pedidos, menú, finanzas, equipo).
///
/// Cada acción expone su propio estado pendiente para que la UI muestre
/// progreso puntual (por pedido / por producto) sin bloquear la pantalla.
/// Las acciones devuelven `null` en éxito o un [AppFailure] listo para UI.
class OperationsController extends ChangeNotifier {
  OperationsController(this.services, {this.onSessionExpired});

  final AppServices services;
  final Future<void> Function()? onSessionExpired;
  bool _disposed = false;
  Timer? _ordersTimer;
  bool _pollBusy = false;

  // ---- Carga general -------------------------------------------------------
  LoadStatus status = LoadStatus.initial;
  AppFailure? loadFailure;
  bool refreshing = false;

  /// Falla de la última sincronización cuando sí había datos previos.
  AppFailure? syncFailure;
  DateTime? lastSyncAt;

  RestaurantInfo? restaurant;
  List<RestaurantOrder> orders = const <RestaurantOrder>[];
  List<MenuProduct> menu = const <MenuProduct>[];
  FinanceSummary? today;

  // ---- Finanzas -----------------------------------------------------------
  FinancePeriod financePeriod = FinancePeriod.today;
  FinanceSummary? finance;
  LoadStatus financeStatus = LoadStatus.initial;
  AppFailure? financeFailure;

  // ---- Equipo -------------------------------------------------------------
  List<EmployeeInfo> team = const <EmployeeInfo>[];
  LoadStatus teamStatus = LoadStatus.initial;
  AppFailure? teamFailure;

  // ---- Acciones pendientes -----------------------------------------------
  final Map<int, OrderAction> _pendingOrders = <int, OrderAction>{};
  final Set<int> _pendingProducts = <int>{};
  bool savingOpenState = false;
  final Set<int> _seenIncoming = <int>{};

  // ---- Derivados ----------------------------------------------------------
  bool get hasData => restaurant != null;
  bool get isOffline =>
      (syncFailure?.isConnectivity ?? false) ||
      (status == LoadStatus.failure && (loadFailure?.isConnectivity ?? false));

  List<RestaurantOrder> _where(bool Function(RestaurantOrder o) test) =>
      orders.where(test).toList(growable: false);

  List<RestaurantOrder> get incomingOrders =>
      _sortedOldestFirst(_where((o) => o.stage == OrderStage.incoming));
  List<RestaurantOrder> get kitchenOrders =>
      _sortedOldestFirst(_where((o) => o.stage == OrderStage.kitchen));
  List<RestaurantOrder> get readyOrders =>
      _sortedOldestFirst(_where((o) => o.stage == OrderStage.ready));
  List<RestaurantOrder> get activeOrders =>
      _sortedOldestFirst(_where((o) => o.isActive));
  List<RestaurantOrder> get historyOrders {
    final list = _where((o) => !o.isActive);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<MenuProduct> get lowStockProducts => menu
      .where((p) => p.stockLevel == StockLevel.low)
      .toList(growable: false);
  List<MenuProduct> get unavailableProducts => menu
      .where((p) =>
          p.stockLevel == StockLevel.soldOut ||
          p.stockLevel == StockLevel.paused)
      .toList(growable: false);

  int get unseenIncoming =>
      incomingOrders.where((o) => !_seenIncoming.contains(o.id)).length;

  /// Pedido activo más antiguo (minutos) para el resumen de cocina.
  RestaurantOrder? get oldestKitchenOrder {
    final list = kitchenOrders;
    return list.isEmpty ? null : list.first;
  }

  bool isOrderPending(int id) => _pendingOrders.containsKey(id);
  OrderAction? pendingActionFor(int id) => _pendingOrders[id];
  bool isProductPending(int id) => _pendingProducts.contains(id);

  static List<RestaurantOrder> _sortedOldestFirst(List<RestaurantOrder> list) {
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  // ---- Carga ----------------------------------------------------------------

  Future<void> load() async {
    if (status == LoadStatus.loading) return;
    status = LoadStatus.loading;
    loadFailure = null;
    _notify();
    final failure = await _fetchAll();
    if (failure == null) {
      status = LoadStatus.ready;
    } else if (hasData) {
      status = LoadStatus.ready;
      syncFailure = failure;
    } else {
      status = LoadStatus.failure;
      loadFailure = failure;
    }
    _notify();
  }

  /// Actualización manual o pull-to-refresh. Conserva los datos visibles.
  Future<AppFailure?> refresh() async {
    if (!hasData) {
      await load();
      return loadFailure;
    }
    if (refreshing) return null;
    refreshing = true;
    _notify();
    final failure = await _fetchAll();
    refreshing = false;
    syncFailure = failure;
    _notify();
    return failure;
  }

  Future<void> retry() => hasData ? refresh() : load();

  Future<AppFailure?> _fetchAll() async {
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        services.restaurant.fetchRestaurant(),
        services.orders.fetchOrders(),
        services.menu.fetchMenu(),
        services.finance.fetchSummary(FinancePeriod.today),
      ]);
      restaurant = results[0] as RestaurantInfo;
      orders = List<RestaurantOrder>.unmodifiable(
        results[1] as List<RestaurantOrder>,
      );
      menu = List<MenuProduct>.unmodifiable(results[2] as List<MenuProduct>);
      today = results[3] as FinanceSummary;
      if (financePeriod == FinancePeriod.today) {
        finance = today;
        financeStatus = LoadStatus.ready;
        financeFailure = null;
      }
      lastSyncAt = DateTime.now();
      syncFailure = null;
      _startLiveSync();
      return null;
    } catch (error) {
      return _mapFailure(error);
    }
  }


  // ---- Sincronización ligera ---------------------------------------------

  void _startLiveSync() {
    if (!services.isRemote || _ordersTimer != null || _disposed) return;
    _ordersTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _pollOrders(),
    );
  }

  Future<void> _pollOrders() async {
    if (_pollBusy || _disposed || status != LoadStatus.ready) return;
    _pollBusy = true;
    try {
      final fresh = await services.orders.fetchOrders();
      orders = List<RestaurantOrder>.unmodifiable(fresh);
      lastSyncAt = DateTime.now();
      syncFailure = null;
      _notify();
    } catch (error) {
      syncFailure = _mapFailure(error);
      _notify();
    } finally {
      _pollBusy = false;
    }
  }

  void pauseLiveSync() {
    _ordersTimer?.cancel();
    _ordersTimer = null;
  }

  void resumeLiveSync() {
    _startLiveSync();
    if (services.isRemote) _pollOrders();
  }

  // ---- Pedidos -------------------------------------------------------------

  void markIncomingSeen() {
    final before = _seenIncoming.length;
    _seenIncoming.addAll(incomingOrders.map((o) => o.id));
    if (_seenIncoming.length != before) _notify();
  }

  Future<AppFailure?> runOrderAction(
    RestaurantOrder order,
    OrderAction action,
  ) async {
    if (_pendingOrders.containsKey(order.id)) return null;
    _pendingOrders[order.id] = action;
    _notify();
    try {
      final RestaurantOrder updated;
      switch (action) {
        case OrderAction.accept:
          updated = await services.orders.acceptOrder(order.id);
          break;
        case OrderAction.startPreparation:
          updated = await services.orders.startPreparation(order.id);
          break;
        case OrderAction.markReady:
          updated = await services.orders.markReady(order.id);
          break;
        case OrderAction.reject:
          updated = await services.orders.rejectOrder(order.id);
          break;
      }
      orders = List<RestaurantOrder>.unmodifiable(
        orders.map((o) => o.id == updated.id ? updated : o),
      );
      _seenIncoming.add(updated.id);
      return null;
    } catch (error) {
      return _mapFailure(error);
    } finally {
      _pendingOrders.remove(order.id);
      _notify();
    }
  }

  // ---- Restaurante -----------------------------------------------------------

  Future<AppFailure?> setRestaurantOpen(bool open) async {
    final current = restaurant;
    if (current == null || savingOpenState) return null;
    savingOpenState = true;
    _notify();
    try {
      final confirmed = await services.restaurant.setRestaurantOpen(open);
      restaurant = (restaurant ?? current).copyWith(isOpen: confirmed);
      return null;
    } catch (error) {
      return _mapFailure(error);
    } finally {
      savingOpenState = false;
      _notify();
    }
  }

  Future<AppFailure?> updateProfile(RestaurantProfileInput input) async {
    try {
      restaurant = await services.restaurant.updateProfile(input);
      _notify();
      return null;
    } catch (error) {
      return _mapFailure(error);
    }
  }

  // ---- Menú ------------------------------------------------------------------

  Future<AppFailure?> saveProduct(ProductDraft draft) async {
    try {
      final saved = await services.menu.saveProduct(draft);
      final exists = menu.any((p) => p.id == saved.id);
      menu = List<MenuProduct>.unmodifiable(
        exists
            ? menu.map((p) => p.id == saved.id ? saved : p)
            : <MenuProduct>[saved, ...menu],
      );
      _notify();
      return null;
    } catch (error) {
      return _mapFailure(error);
    }
  }

  /// Cambio optimista con reversión si la fuente de datos falla.
  Future<AppFailure?> setProductAvailability(
    MenuProduct product,
    bool available,
  ) async {
    if (_pendingProducts.contains(product.id)) return null;
    final previous = menu;
    _pendingProducts.add(product.id);
    menu = List<MenuProduct>.unmodifiable(
      menu.map((p) =>
          p.id == product.id ? p.copyWith(isAvailable: available) : p),
    );
    _notify();
    try {
      final saved =
          await services.menu.setProductAvailability(product.id, available);
      menu = List<MenuProduct>.unmodifiable(
        menu.map((p) => p.id == saved.id ? saved : p),
      );
      return null;
    } catch (error) {
      menu = previous;
      return _mapFailure(error);
    } finally {
      _pendingProducts.remove(product.id);
      _notify();
    }
  }

  Future<AppFailure?> deleteProduct(MenuProduct product) async {
    try {
      await services.menu.deleteProduct(product.id);
      menu = List<MenuProduct>.unmodifiable(
        menu.where((p) => p.id != product.id),
      );
      _notify();
      return null;
    } catch (error) {
      return _mapFailure(error);
    }
  }

  // ---- Finanzas --------------------------------------------------------------

  Future<void> loadFinance([FinancePeriod? period]) async {
    final target = period ?? financePeriod;
    financePeriod = target;
    financeStatus = LoadStatus.loading;
    financeFailure = null;
    _notify();
    try {
      final summary = await services.finance.fetchSummary(target);
      if (financePeriod != target) return;
      finance = summary;
      if (target == FinancePeriod.today) today = summary;
      financeStatus = LoadStatus.ready;
    } catch (error) {
      if (financePeriod != target) return;
      financeFailure = _mapFailure(error);
      financeStatus = LoadStatus.failure;
    }
    _notify();
  }

  // ---- Equipo ------------------------------------------------------------------

  Future<void> loadTeam() async {
    teamStatus = LoadStatus.loading;
    teamFailure = null;
    _notify();
    try {
      team = List<EmployeeInfo>.unmodifiable(
        await services.restaurant.fetchTeam(),
      );
      teamStatus = LoadStatus.ready;
    } catch (error) {
      teamFailure = _mapFailure(error);
      teamStatus = LoadStatus.failure;
    }
    _notify();
  }

  Future<AppFailure?> inviteEmployee(String email, String role) async {
    try {
      final employee = await services.restaurant.inviteEmployee(
        email: email,
        role: role,
      );
      team = List<EmployeeInfo>.unmodifiable(<EmployeeInfo>[...team, employee]);
      _notify();
      return null;
    } catch (error) {
      return _mapFailure(error);
    }
  }

  // ---------------------------------------------------------------------------

  AppFailure _mapFailure(Object error) {
    final failure = AppFailure.from(error);
    if (failure.kind == FailureKind.sessionExpired && onSessionExpired != null) {
      Future<void>.microtask(onSessionExpired!);
    }
    return failure;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _ordersTimer?.cancel();
    _ordersTimer = null;
    _disposed = true;
    super.dispose();
  }
}
