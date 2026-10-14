import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

const Restaurant _pizza = Restaurant(
  id: 11,
  name: 'Pizzería El Rincón',
  category: 'Pizza',
  rating: 4.5,
  eta: '20-30 min',
  deliveryFee: 0,
  image: '',
  description: 'Pizza artesanal',
  delivery: true,
  pickup: true,
  isOpen: true,
);
const Restaurant _tacos = Restaurant(
  id: 12,
  name: 'Tacos La Estación',
  category: 'Tacos',
  rating: 0,
  eta: '15-25 min',
  deliveryFee: 0,
  image: '',
  description: 'Taquería local',
  delivery: false,
  pickup: true,
  isOpen: false,
);
const Restaurant _burger = Restaurant(
  id: 13,
  name: 'Hamburguesas Centro',
  category: 'Hamburguesas',
  rating: 0,
  eta: '25-35 min',
  deliveryFee: 39,
  image: '',
  description: 'Smash burger',
  delivery: true,
  pickup: false,
  isOpen: true,
);

void main() {
  test('Filtros con catálogo real conservan orden y no inventan negocios', () {
    final List<Restaurant> catalog = <Restaurant>[_pizza, _tacos, _burger];
    final Set<int> favorites = <int>{12};
    expect(filterDiscoveryRestaurants(restaurants: catalog, favorites: favorites).map((r) => r.id), <int>[11, 12, 13]);
    expect(filterDiscoveryRestaurants(restaurants: catalog, favorites: favorites, filter: DiscoveryFilter.open).map((r) => r.id), <int>[11, 13]);
    expect(filterDiscoveryRestaurants(restaurants: catalog, favorites: favorites, filter: DiscoveryFilter.delivery).map((r) => r.id), <int>[11, 13]);
    expect(filterDiscoveryRestaurants(restaurants: catalog, favorites: favorites, filter: DiscoveryFilter.pickup).map((r) => r.id), <int>[11, 12]);
    expect(filterDiscoveryRestaurants(restaurants: catalog, favorites: favorites, filter: DiscoveryFilter.favorites).map((r) => r.id), <int>[12]);
  });

  test('Búsqueda ignora acentos y consulta nombre, categoría y descripción', () {
    final List<Restaurant> catalog = <Restaurant>[_pizza, _tacos, _burger];
    const Set<int> favorites = <int>{};
    expect(filterDiscoveryRestaurants(restaurants: catalog, favorites: favorites, term: 'PIZZERIA').map((r) => r.id), <int>[11]);
    expect(filterDiscoveryRestaurants(restaurants: catalog, favorites: favorites, term: 'taqueria').map((r) => r.id), <int>[12]);
    expect(filterDiscoveryRestaurants(restaurants: catalog, favorites: favorites, term: 'Smash').map((r) => r.id), <int>[13]);
    expect(filterDiscoveryRestaurants(restaurants: catalog, favorites: favorites, term: 'inexistente'), isEmpty);
  });

  testWidgets('Buscar descubre comercios reales sin escribir', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.addAll(<Restaurant>[_pizza, _tacos, _burger]);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SearchScreen(model: model))));
    await tester.pump();

    expect(find.text('Explorar comercios'), findsOneWidget);
    expect(find.text(_pizza.name), findsOneWidget);
    expect(find.text(_tacos.name), findsOneWidget);
    expect(find.text(_burger.name), findsOneWidget);
    expect(find.text('Buscar restaurantes o comida…'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Abiertos oculta cerrados; filtros no dependen del backend', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.addAll(<Restaurant>[_pizza, _tacos, _burger]);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SearchScreen(model: model))));
    await tester.pump();
    await tester.tap(find.text('Abiertos'));
    await tester.pumpAndSettle();

    expect(find.text(_pizza.name), findsOneWidget);
    expect(find.text(_burger.name), findsOneWidget);
    expect(find.text(_tacos.name), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Búsqueda combina texto con filtros, limpiar restaura resultados', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.addAll(<Restaurant>[_pizza, _tacos, _burger]);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SearchScreen(model: model))));
    await tester.enterText(find.byKey(const ValueKey<String>('discovery-search-field')), 'tacos');
    await tester.pumpAndSettle();
    expect(find.text(_tacos.name), findsOneWidget);

    await tester.tap(find.text('Abiertos'));
    await tester.pumpAndSettle();
    expect(find.text(_tacos.name), findsNothing);
    expect(find.text('Sin resultados para esta búsqueda'), findsOneWidget);

    await tester.ensureVisible(find.text('Limpiar búsqueda y filtros'));
    await tester.tap(find.text('Limpiar búsqueda y filtros'));
    await tester.pumpAndSettle();
    expect(find.text(_tacos.name), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Inicio ofrece seguimiento de pedido activo sin banner permanente', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.add(_pizza);
    model.orders.add(OrderEntry(
      id: 700,
      restaurant: _pizza,
      total: 249,
      status: 'Preparando',
      deliveryMode: 'delivery',
      lines: <CartLine>[],
      rawStatus: 'preparing',
      paymentMethod: 'cash',
    ));
    await tester.pumpWidget(MaterialApp(home: HomeScreen(model: model)));
    await tester.pump();
    expect(find.text('TU PEDIDO EN CURSO'), findsOneWidget);
    expect(find.text('Preparando'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Inicio NO confunde pago Stripe pendiente con reparto activo', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.add(_pizza);
    model.orders.add(OrderEntry(
      id: 701,
      restaurant: _pizza,
      total: 249,
      status: 'Pago pendiente',
      deliveryMode: 'delivery',
      lines: <CartLine>[],
      rawStatus: 'received',
      paymentMethod: 'stripe',
      paymentStatus: 'pending',
    ));
    await tester.pumpWidget(MaterialApp(home: HomeScreen(model: model)));
    await tester.pump();
    expect(find.text('TU PEDIDO EN CURSO'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Pantalla 320dp mantiene filtros desplazables sin overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TalaModel model = TalaModel();
    model.restaurants.addAll(<Restaurant>[_pizza, _tacos, _burger]);
    model.favorites.add(11);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SearchScreen(model: model))));
    await tester.pump();
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
