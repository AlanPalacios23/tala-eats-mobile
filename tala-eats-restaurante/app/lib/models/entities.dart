// Modelos de dominio del restaurante.
//
// Los `fromJson` se conservan de la baseline v0.3.6 (mapeo existente). Las
// implementaciones remotas deben usarlos o reemplazarlos según el contrato
// real; la UI solo depende de los campos tipados.

class UserSession {
  UserSession({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.twoFactorEnabled = false,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String phone;
  final bool twoFactorEnabled;

  factory UserSession.fromJson(Map<String, dynamic> j) => UserSession(
        id: _i(j['id']),
        name: '${j['name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        role: '${j['role'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        twoFactorEnabled: j['two_factor_enabled'] == true,
      );

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? name : parts.first;
  }
}

class RestaurantInfo {
  RestaurantInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisine,
    required this.emoji,
    required this.etaMin,
    required this.deliveryFee,
    required this.isOpen,
    required this.pickupEnabled,
    required this.rating,
    required this.commissionRate,
    required this.menuItems,
    this.imagePath = '',
  });

  final int id;
  final String name;
  final String description;
  final String cuisine;
  final String emoji;
  final int etaMin;
  final double deliveryFee;
  final bool isOpen;
  final bool pickupEnabled;
  final double rating;
  final double commissionRate;
  final List<MenuProduct> menuItems;

  /// Referencia de imagen: ruta local hoy; URL remota después.
  final String imagePath;

  factory RestaurantInfo.fromJson(Map<String, dynamic> j) => RestaurantInfo(
        id: _i(j['id']),
        name: '${j['name'] ?? 'Mi restaurante'}',
        description: '${j['description'] ?? ''}',
        cuisine: '${j['cuisine'] ?? 'Comida local'}',
        emoji: '${j['emoji'] ?? '🍽️'}',
        etaMin: _i(j['eta_min'], 30),
        deliveryFee: _d(j['delivery_fee']),
        isOpen: j['is_open'] == true,
        pickupEnabled: j['pickup_enabled'] != false,
        rating: _d(j['rating'], 5),
        commissionRate: _d(j['commission_rate']),
        imagePath: _nonEmptyImage(j['cover_image_url'], j['image_path']),
        menuItems: (j['menu_items'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => MenuProduct.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  RestaurantInfo copyWith({
    String? name,
    String? description,
    String? cuisine,
    int? etaMin,
    double? deliveryFee,
    bool? isOpen,
    bool? pickupEnabled,
    List<MenuProduct>? menuItems,
    String? imagePath,
  }) =>
      RestaurantInfo(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        cuisine: cuisine ?? this.cuisine,
        emoji: emoji,
        etaMin: etaMin ?? this.etaMin,
        deliveryFee: deliveryFee ?? this.deliveryFee,
        isOpen: isOpen ?? this.isOpen,
        pickupEnabled: pickupEnabled ?? this.pickupEnabled,
        rating: rating,
        commissionRate: commissionRate,
        imagePath: imagePath ?? this.imagePath,
        menuItems: menuItems ?? this.menuItems,
      );
}

/// Umbral visual de stock bajo. La regla final puede venir del backend.
const int kLowStockThreshold = 10;

enum StockLevel { ok, low, soldOut, paused }

class MenuProduct {
  MenuProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isAvailable,
    required this.stock,
    required this.allergens,
    required this.isCombo,
    required this.optionsJson,
    this.imagePath = '',
  });

  final int id;
  final String name;
  final String description;
  final String category;
  final double price;
  final bool isAvailable;
  final int stock;
  final String allergens;
  final bool isCombo;
  final String optionsJson;
  final String imagePath;

  factory MenuProduct.fromJson(Map<String, dynamic> j) => MenuProduct(
        id: _i(j['id']),
        name: '${j['name'] ?? ''}',
        description: '${j['description'] ?? ''}',
        category: '${j['category'] ?? 'General'}',
        price: _d(j['price']),
        isAvailable: j['is_available'] != false,
        stock: _i(j['stock'], 100),
        allergens: '${j['allergens'] ?? ''}',
        isCombo: j['is_combo'] == true,
        optionsJson: '${j['options_json'] ?? '[]'}',
        imagePath: _nonEmptyImage(j['image_url'], j['image_path']),
      );

  /// Serialización usada únicamente por el almacenamiento local.
  Map<String, dynamic> toLocalJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'price': price,
        'is_available': isAvailable,
        'stock': stock,
        'allergens': allergens,
        'is_combo': isCombo,
        'options_json': optionsJson,
        'image_path': imagePath,
      };

  StockLevel get stockLevel {
    if (!isAvailable) return StockLevel.paused;
    if (stock <= 0) return StockLevel.soldOut;
    if (stock <= kLowStockThreshold) return StockLevel.low;
    return StockLevel.ok;
  }

  bool get needsAttention => stockLevel != StockLevel.ok;

  MenuProduct copyWith({
    String? name,
    String? description,
    String? category,
    double? price,
    bool? isAvailable,
    int? stock,
    String? allergens,
    bool? isCombo,
    String? imagePath,
  }) =>
      MenuProduct(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        price: price ?? this.price,
        isAvailable: isAvailable ?? this.isAvailable,
        stock: stock ?? this.stock,
        allergens: allergens ?? this.allergens,
        isCombo: isCombo ?? this.isCombo,
        optionsJson: optionsJson,
        imagePath: imagePath ?? this.imagePath,
      );
}

class OrderLine {
  OrderLine({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.options,
  });

  final int id;
  final int? menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final String options;

  double get subtotal => unitPrice * quantity;

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        id: _i(j['id']),
        menuItemId: j['menu_item_id'] == null ? null : _i(j['menu_item_id']),
        name: '${j['name_snapshot'] ?? 'Producto'}',
        quantity: _i(j['quantity'], 1),
        unitPrice: _d(j['unit_price']),
        options: '${j['options_snapshot'] ?? ''}',
      );
}

/// Etapa operativa derivada del `status` de pedido.
enum OrderStage {
  /// Nuevo, esperando que el restaurante lo acepte.
  incoming,

  /// Aceptado o en preparación.
  kitchen,

  /// Listo para entregar o recoger.
  ready,

  /// En manos del repartidor.
  outbound,

  /// Entregado o cancelado.
  closed,
}

/// Siguiente acción del restaurante sobre un pedido.
enum OrderAction { accept, startPreparation, markReady, reject }

class RestaurantOrder {
  RestaurantOrder({
    required this.id,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.total,
    required this.subtotal,
    required this.restaurantPayout,
    required this.address,
    required this.notes,
    required this.orderType,
    required this.createdAt,
    required this.items,
    required this.driverId,
    required this.recipientName,
    required this.recipientPhone,
  });

  final int id;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double total;
  final double subtotal;
  final double restaurantPayout;
  final String address;
  final String notes;
  final String orderType;
  final DateTime createdAt;
  final List<OrderLine> items;
  final int? driverId;
  final String recipientName;
  final String recipientPhone;

  factory RestaurantOrder.fromJson(Map<String, dynamic> j) => RestaurantOrder(
        id: _i(j['id']),
        status: '${j['status'] ?? 'received'}',
        paymentMethod: '${j['payment_method'] ?? ''}',
        paymentStatus: '${j['payment_status'] ?? ''}',
        total: _d(j['total']),
        subtotal: _d(j['subtotal'], _d(j['total'])),
        restaurantPayout: _d(j['restaurant_payout']),
        address: '${j['address'] ?? ''}',
        notes: '${j['notes'] ?? ''}',
        orderType: '${j['order_type'] ?? 'delivery'}',
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal() ??
            DateTime.now(),
        items: (j['items'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        driverId: j['driver_id'] == null ? null : _i(j['driver_id']),
        recipientName: '${j['recipient_name'] ?? ''}',
        recipientPhone: '${j['recipient_phone'] ?? ''}',
      );

  bool get isActive => !<String>{'delivered', 'cancelled'}.contains(status);
  bool get isPickup => orderType == 'pickup';
  bool get isPaid => paymentStatus == 'paid';
  int get itemCount => items.fold<int>(0, (a, b) => a + b.quantity);

  OrderStage get stage {
    switch (status) {
      case 'received':
        return OrderStage.incoming;
      case 'confirmed':
      case 'preparing':
        return OrderStage.kitchen;
      case 'ready':
      case 'assigned':
        return OrderStage.ready;
      case 'picked_up':
      case 'on_the_way':
        return OrderStage.outbound;
      default:
        return OrderStage.closed;
    }
  }

  /// Acción principal disponible para el restaurante, si existe.
  OrderAction? get nextAction {
    switch (status) {
      case 'received':
        return OrderAction.accept;
      case 'confirmed':
        return OrderAction.startPreparation;
      case 'preparing':
        return OrderAction.markReady;
      default:
        return null;
    }
  }

  bool get canReject =>
      status == 'received' &&
      !(<String>{'mercadopago', 'stripe'}.contains(paymentMethod) && isPaid);

  RestaurantOrder copyWith({String? status}) => RestaurantOrder(
        id: id,
        status: status ?? this.status,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        total: total,
        subtotal: subtotal,
        restaurantPayout: restaurantPayout,
        address: address,
        notes: notes,
        orderType: orderType,
        createdAt: createdAt,
        items: items,
        driverId: driverId,
        recipientName: recipientName,
        recipientPhone: recipientPhone,
      );
}

class RestaurantAnalytics {
  RestaurantAnalytics({
    required this.orders,
    required this.delivered,
    required this.grossSales,
    required this.avgTicket,
    required this.inventoryLow,
  });

  final int orders;
  final int delivered;
  final double grossSales;
  final double avgTicket;
  final int inventoryLow;

  factory RestaurantAnalytics.fromJson(Map<String, dynamic> j) =>
      RestaurantAnalytics(
        orders: _i(j['orders']),
        delivered: _i(j['delivered']),
        grossSales: _d(j['gross_sales']),
        avgTicket: _d(j['avg_ticket']),
        inventoryLow: _i(j['inventory_low']),
      );

  static RestaurantAnalytics empty() => RestaurantAnalytics(
        orders: 0,
        delivered: 0,
        grossSales: 0,
        avgTicket: 0,
        inventoryLow: 0,
      );
}

enum FinancePeriod { today, week, month }

extension FinancePeriodLabel on FinancePeriod {
  String get label {
    switch (this) {
      case FinancePeriod.today:
        return 'Hoy';
      case FinancePeriod.week:
        return '7 días';
      case FinancePeriod.month:
        return '30 días';
    }
  }
}

class DailySales {
  const DailySales({
    required this.day,
    required this.gross,
    required this.orders,
  });

  final DateTime day;
  final double gross;
  final int orders;
}

/// Resumen financiero de un periodo. Todos los montos provienen de la fuente
/// de datos; la UI no calcula comisiones ni liquidaciones.
class FinanceSummary {
  const FinanceSummary({
    required this.period,
    required this.grossSales,
    required this.netToRestaurant,
    required this.orders,
    required this.delivered,
    required this.cancelled,
    required this.daily,
    required this.movements,
  });

  final FinancePeriod period;
  final double grossSales;
  final double netToRestaurant;
  final int orders;
  final int delivered;
  final int cancelled;
  final List<DailySales> daily;
  final List<RestaurantOrder> movements;

  double get avgTicket => delivered == 0 ? 0 : grossSales / delivered;
  bool get isEmpty => orders == 0 && grossSales == 0;
}

class EmployeeInfo {
  EmployeeInfo({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  final int id;
  final int userId;
  final String name;
  final String email;
  final String role;

  factory EmployeeInfo.fromJson(Map<String, dynamic> j) => EmployeeInfo(
        id: _i(j['id']),
        userId: _i(j['user_id']),
        name: '${j['name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        role: '${j['role'] ?? ''}',
      );
}

String employeeRoleLabel(String role) {
  switch (role) {
    case 'manager':
      return 'Gerente';
    case 'cashier':
      return 'Caja';
    case 'kitchen':
      return 'Cocina';
    case 'owner':
      return 'Propietario';
    default:
      return role;
  }
}

class KdsSnapshot {
  KdsSnapshot({
    required this.lanes,
    required this.stationCounts,
    required this.oldestMin,
    required this.avgPrepMin,
  });

  final Map<String, List<Map<String, dynamic>>> lanes;
  final Map<String, int> stationCounts;
  final int oldestMin;
  final double? avgPrepMin;

  factory KdsSnapshot.fromJson(Map<String, dynamic> j) {
    final lanes = <String, List<Map<String, dynamic>>>{};
    final rawLanes = Map<String, dynamic>.from(
        j['lanes'] as Map? ?? const <String, dynamic>{});
    for (final e in rawLanes.entries) {
      lanes[e.key] = (e.value as List? ?? const <dynamic>[])
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
    }
    final stations = <String, int>{};
    final rawStations = Map<String, dynamic>.from(
        j['stations'] as Map? ?? const <String, dynamic>{});
    for (final e in rawStations.entries) {
      stations[e.key] = _i(e.value);
    }
    final sla =
        Map<String, dynamic>.from(j['sla'] as Map? ?? const <String, dynamic>{});
    return KdsSnapshot(
      lanes: lanes,
      stationCounts: stations,
      oldestMin: _i(sla['oldest_min']),
      avgPrepMin:
          sla['avg_prep_min'] == null ? null : _d(sla['avg_prep_min']),
    );
  }

  static KdsSnapshot empty() => KdsSnapshot(
        lanes: const <String, List<Map<String, dynamic>>>{},
        stationCounts: const <String, int>{},
        oldestMin: 0,
        avgPrepMin: null,
      );
}

class TwoFactorSetup {
  const TwoFactorSetup({required this.secret, required this.otpauthUri});

  final String secret;
  final String otpauthUri;
}

class OnboardingApplication {
  const OnboardingApplication({
    required this.id,
    required this.businessName,
    required this.status,
    required this.notes,
  });

  final int id;
  final String businessName;
  final String status;
  final String notes;

  factory OnboardingApplication.fromJson(Map<String, dynamic> j) =>
      OnboardingApplication(
        id: _i(j['id']),
        businessName: '${j['business_name'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        notes: '${j['notes'] ?? ''}',
      );

  bool get isPending => status == 'pending' || status == 'needs_info';
}

/// Datos capturados en el alta guiada (propietario → restaurante → producto).
class OnboardingDraft {
  const OnboardingDraft({
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.password,
    required this.restaurantName,
    required this.cuisine,
    required this.description,
    required this.restaurantImage,
    required this.product,
  });

  final String ownerName;
  final String email;
  final String phone;
  final String password;
  final String restaurantName;
  final String cuisine;
  final String description;
  final String restaurantImage;
  final ProductDraft product;
}

/// Producto a crear o actualizar (`id == null` → nuevo).
class ProductDraft {
  const ProductDraft({
    this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.isAvailable,
    required this.allergens,
    required this.isCombo,
    required this.imagePath,
  });

  final int? id;
  final String name;
  final String description;
  final String category;
  final double price;
  final int stock;
  final bool isAvailable;
  final String allergens;
  final bool isCombo;
  final String imagePath;
}

/// Cambios editables del perfil del restaurante.
class RestaurantProfileInput {
  const RestaurantProfileInput({
    required this.name,
    required this.cuisine,
    required this.description,
    required this.etaMin,
    required this.deliveryFee,
    required this.pickupEnabled,
    required this.imagePath,
  });

  final String name;
  final String cuisine;
  final String description;
  final int etaMin;
  final double deliveryFee;
  final bool pickupEnabled;
  final String imagePath;
}

int _i(dynamic v, [int fallback = 0]) => int.tryParse('$v') ?? fallback;
double _d(dynamic v, [double fallback = 0]) =>
    double.tryParse('$v') ?? fallback;

// Preferir una URL remota solo cuando realmente existe; conservar la foto
// privada de Android hasta que el backend confirme la migración.
String _nonEmptyImage(Object? remote, Object? local) {
  final server = (remote ?? '').toString().trim();
  return server.isNotEmpty ? server : (local ?? '').toString().trim();
}
