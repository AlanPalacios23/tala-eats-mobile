import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

const _shop = Restaurant(
  id: 551, name: 'Ferretería de la localidad', category: 'Ferretería',
  rating: 0, eta: '30 min', deliveryFee: 39,
  image: '', description: '', delivery: true, pickup: true,
);
const _screws = FoodItem(
  id: 552, restaurantId: 551, name: 'Tornillos 1 kg',
  description: 'Presentación fija de 1 kg', price: 90,
  image: '', category: 'Ferretería',
);

void main() {
  test('Editor de carrito conserva nota si no se cambia y puede borrarla', () {
    final model = TalaModel()..restaurants.add(_shop);
    model.addToCart(_screws, 2, note: 'Entregar en bolsa');
    model.setCartItemQuantity(_screws, 3);
    expect(model.cart.single.note, 'Entregar en bolsa');
    model.setCartItemQuantity(_screws, 3, note: '  Sin empaque extra  ');
    expect(model.cart.single.note, 'Sin empaque extra');
    model.setCartItemQuantity(_screws, 3, note: '');
    expect(model.cart.single.note, isEmpty);
    expect(model.cart.single.quantity, 3);
    model.dispose();
  });

  testWidgets('Ficha ferretería: nota opcional sin opciones de comida inventadas',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    final model = TalaModel()..restaurants.add(_shop);
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Builder(builder: (context) => Scaffold(
          body: Center(child: FilledButton(
            onPressed: () => showProductSheet(context, model, _screws),
            child: const Text('Ver producto'),
          )),
        )),
      ),
    ));
    await tester.tap(find.text('Ver producto'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('Tornillos 1 kg'), findsOneWidget);
    expect(find.text('Nota para el comercio'), findsOneWidget);
    expect(find.text('Sin cebolla'), findsNothing);
    expect(find.text('Extra salsa'), findsNothing);
    final note = find.byKey(const ValueKey<String>('product-merchant-note'));
    expect(note, findsOneWidget);
    expect(tester.widget<TextField>(note).maxLength, 180);
    await tester.enterText(note, 'Entregar en bolsa separada');
    await tester.pump();
    final button = find.textContaining('Agregar ·');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 500));
    expect(model.cart.single.quantity, 1);
    expect(model.cart.single.note, 'Entregar en bolsa separada');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
