import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  testWidgets('Android Back desde Buscar, Pedidos o Cuenta regresa a Inicio',
      (WidgetTester tester) async {
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: AnimatedBuilder(
        animation: model,
        builder: (BuildContext context, Widget? child) =>
            CustomerShell(model: model),
      ),
    ));
    for (final int tab in <int>[1, 2, 3]) {
      model.setTab(tab);
      await tester.pumpAndSettle();
      expect(model.tabIndex, tab);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(model.tabIndex, 0,
          reason: 'Back de pestaña $tab debe conservar la sesión en Inicio.');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Banner offline impide reintentos superpuestos y permite reintento',
      (WidgetTester tester) async {
    int retries = 0;
    Future<void> retry() async { retries++; }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    Future<void> showBanner(bool busy) async {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(body: Align(
            alignment: Alignment.topCenter,
            child: OfflineBanner(onRetry: retry, busy: busy),
          )),
        ),
      ));
      await tester.pump();
    }
    await showBanner(true);
    expect(find.text('Reintentando…'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await showBanner(false);
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    expect(retries, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Imágenes remotas inseguras o ausentes usan fallback sin crashear',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: RestaurantMedia(
            assetPath: '',
            imageUrl: 'http://images.example.invalid/insecure.jpg',
            width: 170,
            height: 120,
            radius: 16,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing,
        reason: 'No cargar imagen HTTP insegura.');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: RestaurantMedia(
            assetPath: 'assets/missing_test_reference.png',
            width: 170,
            height: 120,
            radius: 16,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Imagen HTTPS fallida presenta fallback en lugar de error visible',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: RestaurantMedia(
          assetPath: '',
          imageUrl: 'https://images.example.invalid/missing-404.jpg',
          width: 180, height: 110,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
