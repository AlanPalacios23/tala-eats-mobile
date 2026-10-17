import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

const Restaurant mockShop = Restaurant(
  id: 72, name: 'Restaurante de prueba con nombre largo',
  category: 'Comida mexicana', rating: 4.5, eta: '30-45 min',
  deliveryFee: 35, image: '', description: '',
);
const FoodItem mockItem = FoodItem(
  id: 721, restaurantId: 72, name: 'Platillo de prueba',
  description: '', price: 100, image: '', category: 'Comida',
);

class MockKeyboardApi extends TalaApi {
  int unsafeCalls = 0;
  @override
  Future<dynamic> get(String path) async {
    if (path == '/orders/payment-methods') {
      return <String, dynamic>{
        'methods': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'cash', 'enabled': true},
        ],
      };
    }
    unsafeCalls++;
    throw StateError('Unsupported in keyboard QA: $path');
  }
}

Future<void> showMobileView(WidgetTester tester, Widget widget,
    double width, {double inset = 290, bool reducedMotion = false}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(
    theme: buildTalaTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: const TextScaler.linear(1.3),
        viewInsets: EdgeInsets.only(bottom: inset),
        disableAnimations: reducedMotion,
        accessibleNavigation: reducedMotion,
      ),
      child: widget,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('Buscar con teclado simulado: 320/360/390/430 dp, texto 1.3',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel()..restaurants.add(mockShop);
    for (final double width in <double>[320, 360, 390, 430]) {
      await showMobileView(tester, Scaffold(body: SearchScreen(model: model)),
          width, reducedMotion: true);
      await tester.enterText(find.byType(TextField), 'comida');
      await tester.pumpAndSettle();
      expect(find.text(mockShop.name), findsOneWidget);
      expect(find.text('Sin resultados'), findsNothing);
      expect(tester.takeException(), isNull,
          reason: 'Search overflow with simulated keyboard at $width dp');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Cupón con teclado simulado: no confirma cobro ni pedido',
      (WidgetTester tester) async {
    final MockKeyboardApi api = MockKeyboardApi();
    final TalaModel model = TalaModel(apiClient: api)
      ..restaurants.add(mockShop);
    model.addToCart(mockItem, 1);
    model.setDeliveryMode('pickup');
    for (final double width in <double>[320, 360, 390, 430]) {
      await showMobileView(tester, CheckoutScreen(model: model),
          width, reducedMotion: true);
      await tester.pumpAndSettle();
      final Finder field = find.byType(TextField);
      await tester.ensureVisible(field);
      await tester.enterText(field, 'PRUEBA');
      await tester.pumpAndSettle();
      final Finder apply = find.text('Aplicar');
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(model.coupon, 'PRUEBA');
      expect(find.textContaining('se validará al pagar'), findsWidgets);
      expect(model.orders, isEmpty,
          reason: 'A coupon interaction must not submit an order.');
      expect(api.unsafeCalls, 0);
      expect(tester.takeException(), isNull,
          reason: 'Coupon and apply action must fit at $width dp x1.3');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Android Reduce Motion disables app motion durations',
      (WidgetTester tester) async {
    Duration? effective;
    await showMobileView(tester,
      Builder(builder: (BuildContext context) {
        effective = TalaMotion.of(
            context, const Duration(milliseconds: 300));
        return const Scaffold(
          body: Center(child: Text('Interfaz sin animaciones')),
        );
      }),
      320, inset: 0, reducedMotion: true,
    );
    expect(effective, Duration.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
