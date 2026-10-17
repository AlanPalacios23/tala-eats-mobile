import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

Restaurant _merchant(int id, {
  String? name, String category = 'Restaurante', bool open = true,
  double rating = 4.6,
}) => Restaurant(
  id: id,
  name: name ?? 'Restaurante de la localidad',
  category: category,
  rating: rating,
  eta: '20-30 min',
  deliveryFee: 35,
  image: '',
  description: '',
  isOpen: open,
);

void main() {
  testWidgets('Home premium: 320-430 dp, letra 1.3, foto e información real',
      (WidgetTester tester) async {
    final model = TalaModel();
    model.restaurants.addAll(<Restaurant>[
      _merchant(1),
      _merchant(2, name: 'Comercio de verduras'),
    ]);
    for (final width in <double>[320, 360, 390, 430]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTalaTheme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(body: HomeScreen(model: model)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Restaurantes y comercios'), findsOneWidget);
      expect(find.text('Restaurante de la localidad'), findsOneWidget);
      expect(find.text('20-30 min'), findsWidgets);
      expect(find.text('Envío ' + money(35)), findsWidgets);
      expect(find.text('Abierto'), findsNothing,
          reason: 'No repetir una etiqueta de abierto en cada fotografía');
      expect(tester.takeException(), isNull, reason: 'Overflow a $width dp');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Buscar vacío: lista comercios auténticos sin contenido ficticio',
      (WidgetTester tester) async {
    final model = TalaModel();
    model.restaurants.addAll(<Restaurant>[
      _merchant(1, name: 'Taquería local', category: 'Tacos'),
      _merchant(2, name: 'Verduras frescas', category: 'Verduras'),
      _merchant(3, name: 'Comercio cerrado', open: false),
    ]);
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: Scaffold(body: SearchScreen(model: model)),
    ));
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('Explora por categoría'), findsNothing,
        reason: 'Buscar mantiene el foco en encontrar comercios, sin chips decorativos.');
    expect(find.text('Comercios disponibles'), findsOneWidget);
    expect(find.text('Taquería local'), findsOneWidget);
    expect(find.text('Verduras frescas'), findsOneWidget);
    expect(find.text('Comercio cerrado'), findsNothing,
        reason: 'Sugerencias solo de establecimientos abiertos');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Buscar: entrada de usuario filtra nombres locales',
      (WidgetTester tester) async {
    final model = TalaModel();
    model.restaurants.addAll(<Restaurant>[
      _merchant(1, name: 'Taquería El Centro', category: 'Tacos'),
      _merchant(2, name: 'Verduras frescas', category: 'Verduras'),
    ]);
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: Scaffold(body: SearchScreen(model: model)),
    ));
    await tester.enterText(find.byType(TextField), 'verduras');
    await tester.pumpAndSettle();
    expect(find.text('Verduras frescas'), findsOneWidget);
    expect(find.text('Taquería El Centro'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Home: mercado sin negocios muestra mensaje contextual',
      (WidgetTester tester) async {
    final model = TalaModel()..marketCode = 'AMECA-JAL';
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: Scaffold(body: HomeScreen(model: model)),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Aún no hay comercios disponibles'), findsOneWidget);
    expect(find.textContaining('Ameca'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
