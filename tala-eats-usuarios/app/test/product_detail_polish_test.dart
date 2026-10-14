import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

const Restaurant _openRestaurant = Restaurant(
  id: 81,
  name: 'Comida casera',
  category: 'Comida local',
  rating: 4.8,
  eta: '25 min',
  deliveryFee: 35,
  image: '',
  description: 'Platillos al momento',
);
const Restaurant _closedRestaurant = Restaurant(
  id: 82,
  name: 'Cocina cerrada',
  category: 'Comida local',
  rating: 0,
  eta: '35 min',
  deliveryFee: 35,
  image: '',
  description: '',
  isOpen: false,
);
const FoodItem _dish = FoodItem(
  id: 8101,
  restaurantId: 81,
  name: 'Tacos dorados',
  description: 'Orden de tacos dorados',
  price: 85,
  image: '',
  category: 'Tacos',
);
const FoodItem _closedDish = FoodItem(
  id: 8201,
  restaurantId: 82,
  name: 'Platillo cerrado',
  description: '',
  price: 90,
  image: '',
  category: 'Comida',
);

void main() {
  test('Mismo producto con notas distintas mantiene dos líneas independientes', () {
    final TalaModel model = TalaModel();
    model.restaurants.add(_openRestaurant);
    model.addToCart(_dish, 1, note: 'Sin cebolla');
    model.addToCart(_dish, 2, note: 'Extra limón');
    expect(model.cart, hasLength(2));
    expect(model.cart[0].note, 'Sin cebolla');
    expect(model.cart[0].quantity, 1);
    expect(model.cart[1].note, 'Extra limón');
    expect(model.cart[1].quantity, 2);
    expect(model.subtotal, 255);
    model.dispose();
  });

  test('Misma indicación agrupa cantidades sin sustituir notas', () {
    final TalaModel model = TalaModel();
    model.restaurants.add(_openRestaurant);
    model.addToCart(_dish, 1, note: '  Sin cebolla  ');
    model.addToCart(_dish, 2, note: 'Sin cebolla');
    expect(model.cart, hasLength(1));
    expect(model.cart.single.quantity, 3);
    expect(model.cart.single.note, 'Sin cebolla');
    model.dispose();
  });

  test('El carrito no se destruye al intentar agregar desde un comercio cerrado', () {
    final TalaModel model = TalaModel();
    model.restaurants.addAll(<Restaurant>[_openRestaurant, _closedRestaurant]);
    model.addToCart(_dish, 1);
    model.addToCart(_closedDish, 2);
    expect(model.cart, hasLength(1));
    expect(model.cartRestaurantId, 81);
    expect(model.cart.single.item.id, 8101);
    model.dispose();
  });

  test('Cantidad mínima y máxima protegen el resumen visual', () {
    final TalaModel model = TalaModel();
    model.restaurants.add(_openRestaurant);
    model.addToCart(_dish, 999);
    expect(model.cart.single.quantity, 99);
    model.changeQuantity(model.cart.single, 1);
    expect(model.cart.single.quantity, 99);
    model.changeQuantity(model.cart.single, -1);
    expect(model.cart.single.quantity, 98);
    model.dispose();
  });

  testWidgets('Detalle ofrece nota libre y no extras inventados', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.add(_openRestaurant);
    model.menu.add(_dish);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showProductSheet(context, model, _dish),
              child: const Text('Abrir producto'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir producto'));
    await tester.pumpAndSettle();
    expect(find.text(_dish.name), findsOneWidget);
    expect(find.text('Fotografía no disponible'), findsOneWidget);
    expect(find.text('Indicaciones para la cocina'), findsOneWidget);
    expect(find.text('Extra salsa'), findsNothing);
    final Finder field = find.byKey(const ValueKey<String>('product-instructions'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Sin cebolla, por favor');

    final Finder addButton = find.textContaining('Agregar ·');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(model.cart, hasLength(1));
    expect(model.cart.single.note, 'Sin cebolla, por favor');
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Ficha retirada mientras estaba abierta no agrega producto', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.add(_openRestaurant);
    model.menu.add(_dish);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (BuildContext context) => TextButton(
          onPressed: () => showProductSheet(context, model, _dish),
          child: const Text('Abrir detalle'),
        )),
      ),
    ));
    await tester.tap(find.text('Abrir detalle'));
    await tester.pumpAndSettle();
    model.menu.clear();

    final Finder action = find.textContaining('Agregar ·');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(model.cart, isEmpty);
    expect(find.textContaining('Actualiza el menú'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Precio actualizado impide sumar importes desactualizados', (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    model.restaurants.add(_openRestaurant);
    model.menu.add(_dish);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (BuildContext context) => TextButton(
          onPressed: () => showProductSheet(context, model, _dish),
          child: const Text('Abrir detalle'),
        )),
      ),
    ));
    await tester.tap(find.text('Abrir detalle'));
    await tester.pumpAndSettle();
    model.menu
      ..clear()
      ..add(const FoodItem(
        id: 8101,
        restaurantId: 81,
        name: 'Tacos dorados',
        description: 'Orden de tacos dorados',
        price: 110,
        image: '',
        category: 'Tacos',
      ));

    final Finder action = find.textContaining('Agregar ·');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(model.cart, isEmpty);
    expect(find.textContaining('Actualiza el menú'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Detalle compacto 320dp y texto largo no causa overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final TalaModel model = TalaModel();
    model.restaurants.add(_openRestaurant);
    model.menu.add(_dish);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () => showProductSheet(context, model, _dish),
              child: const Text('Producto'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Producto'));
    await tester.pumpAndSettle();
    expect(find.text('Indicaciones para la cocina'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
