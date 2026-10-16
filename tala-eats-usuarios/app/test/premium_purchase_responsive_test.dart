import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

Restaurant _shop() => const Restaurant(
  id: 7,
  name: 'Comercio de Tala con nombre amplio y legible',
  category: 'Comida mexicana',
  rating: 4.5,
  eta: '30-45 min',
  deliveryFee: 35,
  image: '',
  description: '',
  isOpen: true,
  delivery: true,
  pickup: true,
);

FoodItem _food() => const FoodItem(
  id: 71,
  restaurantId: 7,
  name: 'Hamburguesa especial doble con papas y vegetales frescos',
  description: 'Incluye aderezos y guarnición',
  price: 189.50,
  image: '',
  category: 'Hamburguesas',
);

Future<void> _layout(WidgetTester tester, Widget child, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 820);
  await tester.pumpWidget(MaterialApp(
    theme: buildTalaTheme(),
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: Scaffold(body: child),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 450));
}

void main() {
  testWidgets('Carrito 320/360/390/430 dp: precio y controles nunca desaparecen',
      (WidgetTester tester) async {
    final model = TalaModel()..restaurants.add(_shop());
    model.addToCart(_food(), 2, note: 'Sin cebolla y sin salsa picante');
    for (final width in <double>[320, 360, 390, 430]) {
      await _layout(tester, CartLineCard(model: model, line: model.cart.single), width);
      expect(find.textContaining('Hamburguesa especial'), findsOneWidget);
      expect(find.text(money(379.0)), findsOneWidget);
      expect(find.byTooltip('Más'), findsOneWidget);
      expect(find.byTooltip('Menos'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Render overflow de carrito $width dp x1.3');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Totales referencia: sin precio definitivo inventado y sin overflow',
      (WidgetTester tester) async {
    final model = TalaModel()..restaurants.add(_shop());
    model.addToCart(_food(), 2);
    for (final width in <double>[320, 360, 390, 430]) {
      // Checkout renders this card inside a scrollable ListView; mirror that
      // real viewport so expanded fare explanations can scroll vertically.
      await _layout(tester, ListView(children: <Widget>[
        SummaryCard(model: model),
      ]), width);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Total de referencia'), findsOneWidget);
      expect(find.textContaining('Por confirmar'), findsWidgets);
      expect(tester.takeException(), isNull,
          reason: 'Desglose de dinero no cabe a $width dp');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Modalidad de entrega no trunca elección con letra 1.3',
      (WidgetTester tester) async {
    for (final width in <double>[320, 360, 390, 430]) {
      await _layout(tester, ListView(children: <Widget>[
        DeliveryModeCard(
          icon: Icons.two_wheeler_rounded, title: 'A domicilio',
          subtitle: 'Entrega estimada 30-45 min', selected: true,
          onTap: () {},
        ),
        DeliveryModeCard(
          icon: Icons.storefront_rounded, title: 'Recoger',
          subtitle: 'Sin costo de envío', selected: false,
          onTap: () {},
        ),
      ]), width);
      expect(find.text('A domicilio'), findsOneWidget);
      expect(find.text('Recoger'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Pedido activo 320-430 dp: estado del servidor visible y accesible',
      (WidgetTester tester) async {
    final order = OrderEntry(
      id: 998, restaurant: _shop(), total: 432.50,
      status: 'Preparando', rawStatus: 'preparing',
      deliveryMode: 'delivery', lines: <CartLine>[],
      eta: '30-45 min',
    );
    for (final width in <double>[320, 360, 390, 430]) {
      await _layout(tester, ActiveOrderCard(order: order, onTap: () {}), width);
      expect(find.text('Preparando'), findsOneWidget);
      expect(find.textContaining('Pedido #998'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'Estado de pedido se solapa a $width dp');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Ficha de producto conserva botón y precio sin inventar stock',
      (WidgetTester tester) async {
    final model = TalaModel()..restaurants.add(_shop());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Builder(builder: (BuildContext context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showProductSheet(context, model, _food()),
              child: const Text('Ver producto'),
            ),
          ),
        )),
      ),
    ));
    await tester.tap(find.text('Ver producto'));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.textContaining('Hamburguesa especial'), findsOneWidget);
    expect(find.textContaining('Agregar ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
