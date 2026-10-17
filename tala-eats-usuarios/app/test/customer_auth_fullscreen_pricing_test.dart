import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void verifyFullBackground(WidgetTester tester, String file) {
  final images = tester.widgetList<Image>(find.byType(Image)).toList();
  expect(images.any((i) =>
      i.image is AssetImage &&
      (i.image as AssetImage).assetName == file &&
      i.fit == BoxFit.cover), isTrue,
      reason: 'La imagen original debe cubrir TODO el viewport, no sólo la cabecera.');
}

void main() {
  testWidgets('Login: foto full-screen sin icono ni título de marca duplicados',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: LoginScreen(model: model),
    ));
    await tester.pumpAndSettle();
    verifyFullBackground(tester, 'assets/branding/login_food.png');
    expect(find.byType(TalaLogoMark), findsNothing);
    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
    expect(find.text('Tala Eats'), findsNothing);
    expect(find.byKey(const ValueKey<String>('login-otp')), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    await tester.ensureVisible(find.text('Aviso de Privacidad'));
    expect(find.text('Términos y Condiciones'), findsOneWidget);
    expect(find.text('Aviso de Privacidad'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Registro usa segunda foto de fondo y mantiene campos funcionales',
      (WidgetTester tester) async {
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: SignUpScreen(model: model),
    ));
    await tester.pumpAndSettle();
    verifyFullBackground(tester, 'assets/branding/auth_secondary.jpg');
    expect(find.byType(TalaLogoMark), findsNothing);
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    await tester.ensureVisible(find.byType(TextField).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Crear una contraseña'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Recuperar y cambiar contraseña usan segunda foto',
      (WidgetTester tester) async {
    final model = TalaModel();
    for (final Widget screen in <Widget>[
      ForgotPasswordScreen(model: model),
      ChangePasswordScreen(model: model),
    ]) {
      await tester.pumpWidget(MaterialApp(
        theme: buildTalaTheme(), home: screen,
      ));
      await tester.pumpAndSettle();
      verifyFullBackground(tester, 'assets/branding/auth_secondary.jpg');
      expect(find.byType(TalaLogoMark), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    model.dispose();
  });

  testWidgets('Tarifa mercantil \$15 nunca se anuncia como envio cliente',
      (WidgetTester tester) async {
    const Restaurant restaurant = Restaurant(
      id: 42, name: 'Tienda QA', category: 'Hamburguesas',
      rating: 4.8, eta: '25-35 min', deliveryFee: 15,
      image: '', description: 'Tienda simulada', delivery: true,
    );
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RestaurantCard(
            model: model,
            restaurant: restaurant,
            onTap: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Envío según distancia'), findsOneWidget);
    expect(find.textContaining('Envío \$15'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
