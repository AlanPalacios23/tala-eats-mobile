import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

Restaurant shop(int id, String name, {String category = 'Tacos',
    bool open = true, bool pickup = true, String promo = ''}) =>
    Restaurant(id: id, name: name, category: category, rating: 4.8,
      eta: '25 min', deliveryFee: 35, image: '',
      description: '', isOpen: open, pickup: pickup, promo: promo);

class QuietApi extends TalaApi {
  @override
  Future<Map<String, dynamic>> restaurant(int id) async =>
      <String, dynamic>{'id': id, 'menu_items': <dynamic>[]};
  @override
  Future<dynamic> get(String path) async {
    if (path.contains('effective-menu')) {
      return <String, dynamic>{'items': <dynamic>[]};
    }
    throw StateError('Unrequested route: ' + path);
  }
}

Future<void> pumpQuiet(WidgetTester tester, Widget child,
    {double width = 390}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  await tester.pumpWidget(MaterialApp(
    theme: buildTalaTheme(),
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: Scaffold(body: child),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('Inicio elimina contadores decorativos, conserva acceso y negocios',
      (WidgetTester tester) async {
    final model = TalaModel()
      ..restaurants.addAll(<Restaurant>[
        shop(1, 'Taquería real'),
        shop(2, 'Verduras del mercado', category: 'Verduras'),
      ]);
    for (final width in <double>[320, 360, 390, 430]) {
      await pumpQuiet(tester, HomeScreen(model: model), width: width);
      expect(find.text('Restaurantes y comercios'), findsOneWidget);
      expect(find.text('Taquería real'), findsOneWidget);
      expect(find.text('Comprar en Tala'), findsOneWidget);
      expect(find.text('2'), findsNothing,
          reason: 'No mostrar un contador de comercios junto al título.');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Buscar no muestra chips y permite buscar por categoría con texto',
      (WidgetTester tester) async {
    final model = TalaModel()
      ..restaurants.addAll(<Restaurant>[
        shop(1, 'Taquería local'),
        shop(2, 'Verduras frescas', category: 'Verduras'),
      ]);
    await pumpQuiet(tester, SearchScreen(model: model), width: 320);
    expect(find.text('Explora por categoría'), findsNothing);
    expect(find.byType(TalaChoicePill), findsNothing);
    expect(find.text('Comercios disponibles'), findsOneWidget);
    expect(find.text('Verduras frescas'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'VERDURAS');
    await tester.pumpAndSettle();
    expect(find.text('Verduras frescas'), findsOneWidget);
    expect(find.text('Taquería local'), findsNothing);
    expect(find.text('Platillos'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Buscar diferencia carga, error y mercado realmente vacío',
      (WidgetTester tester) async {
    final model = TalaModel();
    model.loading = true;
    await pumpQuiet(tester, SearchScreen(model: model), width: 320);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    model.loading = false;
    model.lastError = 'Fallo de red simulado';
    await pumpQuiet(tester, SearchScreen(model: model), width: 320);
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar los comercios'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    model.lastError = '';
    await pumpQuiet(tester, SearchScreen(model: model), width: 320);
    await tester.pumpAndSettle();
    expect(find.text('Aún no hay comercios para explorar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Cuenta elimina tarjeta publicitaria, conserva Tala Club y saldo',
      (WidgetTester tester) async {
    final model = TalaModel();
    await pumpQuiet(tester, TalaClubAccountCard(model: model), width: 320);
    expect(find.text('Tala Club'), findsOneWidget);
    expect(find.textContaining('de saldo'), findsOneWidget);
    expect(find.textContaining('puntos'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Tala Club'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletScreen), findsOneWidget,
        reason: 'La limpieza visual no debe perder el acceso a la billetera.');
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Restaurante: información real sin muro de badges ni scorecard',
      (WidgetTester tester) async {
    final api = QuietApi();
    final model = TalaModel(apiClient: api);
    final merchant = shop(1, 'Taquería Real',
        pickup: true, promo: 'Promoción del comercio');
    model.restaurants.add(merchant);
    model.menu.add(const FoodItem(
      id: 11, restaurantId: 1, name: 'Taco de asada',
      description: '', price: 29, image: '', category: 'Tacos',
    ));
    await pumpQuiet(tester,
        RestaurantScreen(model: model, restaurant: merchant), width: 320);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Taquería Real'), findsWidgets);
    expect(find.text('Abierto'), findsNothing);
    expect(find.text('También para recoger'), findsNothing);
    expect(find.text('Para recoger'), findsWidgets);
    expect(find.text('Promoción del comercio'), findsOneWidget,
        reason: 'Mantener promociones reales del comercio.');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
