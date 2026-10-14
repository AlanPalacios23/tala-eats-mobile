import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

const Restaurant _restaurant = Restaurant(
  id: 302,
  name: 'Comidas de Tala',
  category: 'Comida local',
  rating: 4.8,
  eta: '25-35 min',
  deliveryFee: 35,
  image: '',
  description: 'Comida casera',
);

const FoodItem _food = FoodItem(
  id: 3021,
  restaurantId: 302,
  name: 'Torta ahogada',
  description: 'Torta de prueba',
  price: 95,
  image: '',
  category: 'Tortas',
);

class _MethodsStub extends TalaApi {
  @override
  Future<dynamic> get(String path) async {
    if (path != '/orders/payment-methods') {
      throw StateError('Request inesperada: $path');
    }
    return <String, dynamic>{
      'methods': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'cash', 'enabled': true},
        <String, dynamic>{'id': 'stripe', 'enabled': false},
        <String, dynamic>{'id': 'mercadopago', 'enabled': false},
      ],
    };
  }
}

OrderEntry _order(int id, {required String status, required String rawStatus,
  String method = 'cash', String paymentStatus = 'pending'}) =>
    OrderEntry(
      id: id,
      restaurant: _restaurant,
      total: 195,
      status: status,
      rawStatus: rawStatus,
      deliveryMode: 'delivery',
      paymentMethod: method,
      paymentStatus: paymentStatus,
      lines: <CartLine>[],
    );

void main() {
  testWidgets('Pedidos separa pago sin confirmar de entrega en curso', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.add(_restaurant);
    model.orders.addAll(<OrderEntry>[
      _order(11, status: 'Pago pendiente', rawStatus: 'received', method: 'stripe'),
      _order(12, status: 'Preparando', rawStatus: 'preparing'),
      _order(13, status: 'Entregado', rawStatus: 'delivered'),
    ]);
    await tester.pumpWidget(MaterialApp(home: OrdersScreen(model: model)));
    await tester.pumpAndSettle();
    expect(find.text('Pendientes de pago'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('Anteriores'), findsOneWidget);
    expect(find.text('Pago sin confirmar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Detalle online pendiente no ofrece seguimiento de entrega', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.add(_restaurant);
    final OrderEntry pending = _order(17, status: 'Pago pendiente',
      rawStatus: 'received', method: 'stripe');
    await tester.pumpWidget(MaterialApp(home: OrderDetailScreen(model: model, order: pending)));
    await tester.pumpAndSettle();
    expect(find.text('Revisar estado del pago'), findsOneWidget);
    expect(find.text('Seguir pedido'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Checkout sin dirección pide dirección antes de confirmar', (WidgetTester tester) async {
    final TalaModel model = TalaModel(apiClient: _MethodsStub());
    model.restaurants.add(_restaurant);
    model.addToCart(_food, 1);
    await tester.pumpWidget(MaterialApp(home: CheckoutScreen(model: model)));
    await tester.pumpAndSettle();
    expect(find.text('Agregar dirección de entrega'), findsOneWidget);
    expect(find.text('Confirmar pedido'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Checkout muestra aviso cuando dirección carece de GPS', (WidgetTester tester) async {
    final TalaModel model = TalaModel(apiClient: _MethodsStub());
    model.restaurants.add(_restaurant);
    model.addToCart(_food, 1);
    model.addresses.add(const AddressEntry(
      id: 1, label: 'Casa', address: 'Centro de Tala, Jalisco',
    ));
    await tester.pumpWidget(MaterialApp(home: CheckoutScreen(model: model)));
    await tester.pumpAndSettle();
    expect(find.text('Actualizar ubicación de entrega'), findsOneWidget);
    final Finder warning = find.textContaining('no tiene un punto GPS válido');
    await tester.scrollUntilVisible(warning, 130,
      scrollable: find.byType(Scrollable).first);
    expect(warning, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Checkout habilita confirmar si ubicación GPS es válida', (WidgetTester tester) async {
    final TalaModel model = TalaModel(apiClient: _MethodsStub());
    model.restaurants.add(_restaurant);
    model.addToCart(_food, 1);
    model.addresses.add(const AddressEntry(
      id: 2, label: 'Casa', address: 'Centro de Tala, Jalisco',
      lat: 20.65, lng: -103.70,
    ));
    await tester.pumpWidget(MaterialApp(home: CheckoutScreen(model: model)));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar pedido'), findsOneWidget);
    expect(find.text('Actualizar ubicación de entrega'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Cuenta abre Pedidos usando la navegación existente', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: AccountScreen(model: model)));
    await tester.pumpAndSettle();
    final Finder link = find.text('Mis pedidos');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();
    expect(model.tabIndex, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Seguimiento informa actualización periódica, no GPS instantáneo',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LiveBadge())));
    await tester.pump();
    expect(find.text('Actualización periódica'), findsOneWidget);
    expect(find.text('En vivo'), findsNothing);
  });
}
