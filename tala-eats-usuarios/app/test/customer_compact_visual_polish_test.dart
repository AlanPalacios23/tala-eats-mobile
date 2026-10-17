import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

const _merchant = Restaurant(
  id: 801,
  name: 'Restaurante de comida tradicional de nuestra localidad',
  category: 'Comida local',
  rating: 4.8,
  eta: '30-45 min',
  deliveryFee: 39,
  image: '',
  description: '',
  delivery: true,
  pickup: true,
);

const _dish = FoodItem(
  id: 802, restaurantId: 801, name: 'Taco auténtico',
  description: 'Producto QA', price: 49, image: '', category: 'Tacos',
);

class _OfflinePaymentApi extends TalaApi {
  @override
  Future<dynamic> get(String path) async =>
      throw ApiException(503, 'Servicio de prueba sin conexión');
}

Future<void> _render(WidgetTester tester, Widget screen,
    {required double width, double textScale = 1.3}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 820);
  await tester.pumpWidget(MaterialApp(
    theme: buildTalaTheme(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: screen,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('Carrito mantiene nombre y Agregar más a 320-430dp y texto grande',
      (tester) async {
    final model = TalaModel()..restaurants.add(_merchant);
    model.addToCart(_dish, 2);
    for (final width in <double>[320, 360, 390, 430]) {
      await _render(tester, CartScreen(model: model), width: width);
      final title = tester.widget<Text>(find.text(_merchant.name));
      expect(title.maxLines, 2,
          reason: 'El nombre del comercio no debe comprimirse a $width dp');
      expect(find.text('Agregar más'), findsOneWidget);
      expect(find.textContaining('2 productos'), findsOneWidget);
      expect(find.text('Continuar al pago'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Carrito sin overflow a $width dp, escala 1.3');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Checkout apila modalidades de entrega sin truncar en móvil',
      (tester) async {
    final model = TalaModel(apiClient: _OfflinePaymentApi())
      ..restaurants.add(_merchant);
    model.addToCart(_dish, 1);
    for (final width in <double>[320, 360, 390, 430]) {
      await _render(tester, CheckoutScreen(model: model), width: width);
      final choices = find.byType(DeliveryModeCard);
      expect(choices, findsNWidgets(2));
      final first = tester.getTopLeft(choices.at(0));
      final second = tester.getTopLeft(choices.at(1));
      expect(second.dy, greaterThan(first.dy),
          reason: 'Las dos modalidades deben estar completas a $width dp x1.3');
      final pickup = tester.widget<Text>(find.text('Sin costo de envío'));
      expect(pickup.maxLines, 2);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Buscar no anuncia productos de otro mercado sin comercio activo',
      (tester) async {
    final model = TalaModel()
      ..restaurants.add(_merchant)
      ..menu.addAll(<FoodItem>[
        _dish,
        const FoodItem(
          id: 900, restaurantId: 999, name: 'Taco de otra localidad',
          description: 'No corresponde al mercado actual',
          price: 70, image: '', category: 'Tacos',
        ),
      ]);
    await _render(tester, SearchScreen(model: model), width: 320);
    await tester.enterText(find.byType(TextField), 'taco');
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Taco auténtico'), findsOneWidget);
    expect(find.text('Taco de otra localidad'), findsNothing);
    expect(find.byType(AddToCartButton), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
