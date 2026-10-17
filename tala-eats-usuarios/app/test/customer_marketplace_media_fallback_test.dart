import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  test('Fallback de productos reales conserva íconos según comercio', () {
    expect(DishThumb.iconFor('Ferretería · tornillos'),
        Icons.handyman_rounded);
    expect(DishThumb.iconFor('Papelería · cuaderno'),
        Icons.edit_note_rounded);
    expect(DishThumb.iconFor('Florería · ramo de flores'),
        Icons.local_florist_rounded);
    expect(DishThumb.iconFor('Regalos · obsequio'),
        Icons.card_giftcard_rounded);
    expect(DishThumb.iconFor('Frutería · fruta fresca'),
        Icons.eco_rounded);
    expect(DishThumb.iconFor('Carnicería · carne de res'),
        Icons.outdoor_grill_rounded);
    expect(DishThumb.iconFor('Abarrotes · despensa'),
        Icons.local_grocery_store_rounded);
    expect(DishThumb.iconFor('Comida · tacos'),
        Icons.local_fire_department_rounded,
        reason: 'No alterar ilustraciones ya conocidas de comida');
  });

  testWidgets('Ferretería sin imagen muestra fallback neutro, no foto ficticia',
      (tester) async {
    const product = FoodItem(
      id: 44, restaurantId: 22, name: 'Tornillos 500 g',
      category: 'Ferretería', description: '', price: 38, image: '',
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: DishThumb(item: product, size: 80))),
    ));
    expect(find.byIcon(Icons.handyman_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
