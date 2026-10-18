import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

const _restaurant = Restaurant(
  id: 745,
  name: 'Restaurante tradicional de la localidad con un nombre largo',
  category: 'Comida regional',
  rating: 4.8,
  eta: '35-50 min',
  deliveryFee: 39,
  image: '',
  description: '',
);

const _food = FoodItem(
  id: 746, restaurantId: 745, name: 'Enchiladas tradicionales',
  description: 'Producto sintético QA', price: 115,
  image: '', category: 'Mexicana',
);

OrderEntry _order({required bool complete}) => OrderEntry(
  id: complete ? 8901 : 8902,
  restaurant: _restaurant,
  total: 230,
  status: complete ? 'Entregado' : 'Preparando',
  rawStatus: complete ? 'delivered' : 'preparing',
  deliveryMode: 'delivery',
  lines: <CartLine>[CartLine(item: _food, quantity: 2)],
  paymentStatus: complete ? 'paid' : 'pending',
  eta: '35-50 min',
);

Future<void> _render(WidgetTester tester, Widget child, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 960);
  await tester.pumpWidget(MaterialApp(
    theme: buildTalaTheme(),
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: child,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 550));
}

void main() {
  testWidgets('Pedidos activos y anteriores conservan nombre, estado y acceso a 320-430dp',
      (tester) async {
    final active = _order(complete: false);
    final past = _order(complete: true);
    for (final width in <double>[320, 360, 390, 430]) {
      await _render(tester, Scaffold(
        body: ListView(children: <Widget>[
          ActiveOrderCard(order: active, onTap: () {}),
          PastOrderTile(order: past, onTap: () {}),
        ]),
      ), width);
      expect(find.text('Preparando'), findsOneWidget);
      expect(find.text('Entregado'), findsOneWidget);
      expect(find.text('Ver pedido'), findsOneWidget);
      expect(find.textContaining('#8901'), findsOneWidget);
      final pastTitle = tester.widget<Text>(
        find.descendant(of: find.byType(PastOrderTile),
          matching: find.text(_restaurant.name)));
      expect(pastTitle.maxLines, 2);
      final progress = tester.widget<Semantics>(
        find.byWidgetPredicate((Widget widget) =>
          widget is Semantics &&
          (widget.properties.label ?? '').startsWith('Progreso del pedido:')));
      expect(progress.properties.label, contains('etapa 3 de 6'));
      expect(tester.takeException(), isNull,
        reason: 'Tarjetas de pedidos x1.3 sin overflow a $width dp');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Detalle de pedido deja leer comercio y estado de pago a 320-430dp',
      (tester) async {
    final model = TalaModel()..restaurants.add(_restaurant);
    final order = _order(complete: true);
    for (final width in <double>[320, 360, 390, 430]) {
      await _render(tester,
        OrderDetailScreen(model: model, order: order), width);
      final heading = tester.widget<Text>(find.text(_restaurant.name).first);
      expect(heading.maxLines, 2);
      expect(find.text('Entregado'), findsWidgets);
      expect(find.text('Productos'), findsOneWidget);
      expect(tester.takeException(), isNull,
        reason: 'Detalle de pedido x1.3 sin overflow a $width dp');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });
}
