import 'dart:math' as math;

import '../../models/entities.dart';

/// Datos semilla para el modo local (QA sin servidor).
///
/// Solo la implementación local de repositorios usa esta clase; ninguna
/// pantalla la importa.
abstract final class SeedData {
  static RestaurantInfo restaurant() => RestaurantInfo(
        id: 101,
        name: 'Tacos El Centro',
        description: 'Tacos, quesadillas y especialidades al momento.',
        cuisine: 'Tacos',
        emoji: '🌮',
        etaMin: 24,
        deliveryFee: 29,
        isOpen: true,
        pickupEnabled: true,
        rating: 4.8,
        commissionRate: 0,
        menuItems: const <MenuProduct>[],
      );

  static UserSession owner({String? email}) => UserSession(
        id: 9001,
        name: 'Propietario',
        email: email ?? 'propietario@tacoselcentro.mx',
        role: 'owner',
      );

  static List<MenuProduct> menu() => <MenuProduct>[
        MenuProduct(
          id: 1,
          name: 'Orden de tacos al pastor',
          description: '5 tacos con cebolla, cilantro, piña y salsa de la casa.',
          category: 'Tacos',
          price: 92,
          isAvailable: true,
          stock: 38,
          allergens: '',
          isCombo: false,
          optionsJson: '[]',
        ),
        MenuProduct(
          id: 2,
          name: 'Quesadilla especial',
          description: 'Tortilla grande de maíz, queso Oaxaca y carne a elegir.',
          category: 'Quesadillas',
          price: 78,
          isAvailable: true,
          stock: 15,
          allergens: 'Lácteos',
          isCombo: false,
          optionsJson: '[]',
        ),
        MenuProduct(
          id: 3,
          name: 'Gringa al pastor',
          description: 'Tortilla de harina, queso, pastor y piña asada.',
          category: 'Especialidades',
          price: 86,
          isAvailable: true,
          stock: 9,
          allergens: 'Gluten, lácteos',
          isCombo: false,
          optionsJson: '[]',
        ),
        MenuProduct(
          id: 4,
          name: 'Combo pareja',
          description: '10 tacos, 2 bebidas y 2 órdenes de cebollitas.',
          category: 'Combos',
          price: 249,
          isAvailable: true,
          stock: 8,
          allergens: '',
          isCombo: true,
          optionsJson: '[]',
        ),
        MenuProduct(
          id: 5,
          name: 'Agua fresca 500 ml',
          description: 'Horchata, jamaica o limón con chía.',
          category: 'Bebidas',
          price: 35,
          isAvailable: true,
          stock: 26,
          allergens: '',
          isCombo: false,
          optionsJson: '[]',
        ),
        MenuProduct(
          id: 6,
          name: 'Volcán de asada',
          description: 'Tostada crujiente, queso gratinado y asada.',
          category: 'Especialidades',
          price: 62,
          isAvailable: false,
          stock: 0,
          allergens: 'Lácteos',
          isCombo: false,
          optionsJson: '[]',
        ),
      ];

  static List<EmployeeInfo> team() => <EmployeeInfo>[
        EmployeeInfo(
          id: 1,
          userId: 5001,
          name: 'Ana López',
          email: 'ana.lopez@correo.mx',
          role: 'manager',
        ),
        EmployeeInfo(
          id: 2,
          userId: 5002,
          name: 'José Medina',
          email: 'jose.medina@correo.mx',
          role: 'kitchen',
        ),
      ];

  /// Pedidos coherentes con el menú real del restaurante: las líneas se
  /// construyen con sus productos para que el panel no muestre platillos
  /// ajenos.
  static List<RestaurantOrder> orders(List<MenuProduct> menu, DateTime now) {
    final products = menu.isEmpty ? SeedData.menu() : menu;
    MenuProduct pick(int index) => products[index % products.length];

    var lineId = 0;
    OrderLine line(int index, int qty, {String options = ''}) {
      final p = pick(index);
      lineId += 1;
      return OrderLine(
        id: lineId,
        menuItemId: p.id,
        name: p.name,
        quantity: qty,
        unitPrice: p.price,
        options: options,
      );
    }

    RestaurantOrder order({
      required int id,
      required String status,
      required int minutesAgo,
      required List<OrderLine> lines,
      required String recipient,
      required String phone,
      required String address,
      String notes = '',
      String type = 'delivery',
      String payment = 'card',
      int? driverId,
    }) {
      final total = lines.fold<double>(0, (sum, l) => sum + l.subtotal);
      return RestaurantOrder(
        id: id,
        status: status,
        paymentMethod: payment,
        paymentStatus: 'paid',
        total: total,
        subtotal: total,
        restaurantPayout: double.parse((total * 0.85).toStringAsFixed(2)),
        address: address,
        notes: notes,
        orderType: type,
        createdAt: now.subtract(Duration(minutes: minutesAgo)),
        items: lines,
        driverId: driverId,
        recipientName: recipient,
        recipientPhone: phone,
      );
    }

    return <RestaurantOrder>[
      order(
        id: 1842,
        status: 'received',
        minutesAgo: 3,
        recipient: 'Mariana López',
        phone: '33 1111 9082',
        address: 'Av. Juárez 184, Centro, Tala',
        notes: 'Sin cebolla en dos tacos. Salsa aparte.',
        lines: <OrderLine>[
          line(0, 2),
          line(4, 2, options: 'Horchata, jamaica'),
          line(1, 1),
        ],
      ),
      order(
        id: 1843,
        status: 'received',
        minutesAgo: 1,
        recipient: 'Ricardo Peña',
        phone: '33 7777 1290',
        address: 'Recoge en restaurante',
        type: 'pickup',
        payment: 'cash',
        lines: <OrderLine>[
          line(2, 1),
          line(4, 1, options: 'Limón con chía'),
        ],
      ),
      order(
        id: 1841,
        status: 'confirmed',
        minutesAgo: 9,
        recipient: 'Carlos Ramírez',
        phone: '33 2222 1077',
        address: 'Recoge en restaurante',
        notes: 'Llega en 20 minutos.',
        type: 'pickup',
        lines: <OrderLine>[line(3, 1)],
      ),
      order(
        id: 1839,
        status: 'preparing',
        minutesAgo: 22,
        recipient: 'Fernanda Ruiz',
        phone: '33 3333 2228',
        address: 'C. Hidalgo 52, Tala',
        notes: 'Salsa muy picante aparte.',
        lines: <OrderLine>[line(2, 1), line(1, 1)],
      ),
      order(
        id: 1837,
        status: 'ready',
        minutesAgo: 27,
        recipient: 'Diego Navarro',
        phone: '33 4444 5656',
        address: 'Col. La Higuera, Tala',
        driverId: 77,
        lines: <OrderLine>[line(0, 2), line(4, 1)],
      ),
      order(
        id: 1831,
        status: 'delivered',
        minutesAgo: 83,
        recipient: 'Sofía Martínez',
        phone: '33 5555 0404',
        address: 'Fracc. Los Ruiseñores, Tala',
        driverId: 66,
        lines: <OrderLine>[line(3, 1), line(4, 1), line(1, 1)],
      ),
      order(
        id: 1828,
        status: 'delivered',
        minutesAgo: 135,
        recipient: 'Luis Ortega',
        phone: '33 6666 7171',
        address: 'Centro, Tala',
        driverId: 61,
        lines: <OrderLine>[line(0, 2)],
      ),
      order(
        id: 1825,
        status: 'cancelled',
        minutesAgo: 190,
        recipient: 'Paola Ibarra',
        phone: '33 8888 3131',
        address: 'Col. El Refugio, Tala',
        lines: <OrderLine>[line(1, 2)],
      ),
    ];
  }

  /// Serie diaria determinística para gráficas en modo local.
  static List<DailySales> dailyHistory({
    required DateTime today,
    required int days,
    required double avgTicket,
  }) {
    final random = math.Random(today.year * 1000 + today.month * 40 + today.day);
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: days - 1));
    return List<DailySales>.generate(days, (i) {
      final day = start.add(Duration(days: i));
      final weekend = day.weekday >= DateTime.friday;
      final base = weekend ? 34 : 22;
      final count = base + random.nextInt(12);
      final gross = count * avgTicket * (0.9 + random.nextDouble() * 0.2);
      return DailySales(
        day: day,
        gross: double.parse(gross.toStringAsFixed(2)),
        orders: count,
      );
    });
  }
}
