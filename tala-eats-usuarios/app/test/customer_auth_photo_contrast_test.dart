import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  test('Hero mantiene foto original y degrada solo el encabezado', () {
    final src = File('lib/ui/auth_screens.dart').readAsStringSync();
    expect(src, contains('fit: BoxFit.cover'));
    expect(src, contains('assets/branding/login_food.png'));
    expect(src, contains('assets/branding/auth_secondary.jpg'));
    expect(src, isNot(contains('Color(0x88FFFFFF)')));
    expect(src, contains('auth-surface'));
  });

  testWidgets('Login: hero blanco sobre foto y panel único con dos campos',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: LoginScreen(model: model),
    ));
    await tester.pumpAndSettle();
    final image = tester.widgetList<Image>(find.byType(Image)).firstWhere(
        (Image i) => i.image is AssetImage &&
            (i.image as AssetImage).assetName == 'assets/branding/login_food.png');
    expect(image.fit, BoxFit.cover);
    final heading = tester.widget<Text>(find.text('Bienvenido de vuelta'));
    expect(heading.style!.color, Colors.white);
    expect(heading.style!.fontWeight, FontWeight.w800);
    final inputs = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(inputs.length, 2);
    expect(inputs.first.decoration!.labelText, 'Correo electrónico');
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    model.dispose();
  });

  testWidgets('Login vacío se valida antes de hacer peticiones de autenticación',
      (WidgetTester tester) async {
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: LoginScreen(model: model),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un correo electrónico válido.'), findsOneWidget);
    expect(model.signedIn, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Recuperación inválida no dice correo enviado ni llama servidor',
      (WidgetTester tester) async {
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: ForgotPasswordScreen(model: model),
    ));
    await tester.pumpAndSettle();
    final image = tester.widgetList<Image>(find.byType(Image)).firstWhere(
      (Image i) => i.image is AssetImage &&
          (i.image as AssetImage).assetName == 'assets/branding/auth_secondary.jpg');
    expect(image.fit, BoxFit.cover);
    expect(tester.widget<Text>(find.text('Recupera tu contraseña'))
        .style!.fontWeight, FontWeight.w800);
    await tester.ensureVisible(find.text('Enviar enlace'));
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe un correo electrónico válido.'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
