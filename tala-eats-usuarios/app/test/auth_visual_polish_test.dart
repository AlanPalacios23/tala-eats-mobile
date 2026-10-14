import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

String currentPhoto(WidgetTester tester) {
  final Image image = tester.widget<Image>(
    find.byKey(const ValueKey<String>('auth-food-photo')),
  );
  return (image.image as AssetImage).assetName;
}

String? placeholder(WidgetTester tester, String key) {
  final TextField field = tester.widget<TextField>(
    find.byKey(ValueKey<String>(key)),
  );
  expect(field.decoration?.labelText, isNull,
      reason: 'No debe mostrarse ni elevarse un label naranja.');
  return field.decoration?.hintText;
}

void main() {
  testWidgets('Pantalla de carga usa el arte original sin logo ni barra extra',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LaunchScreen()));
    await tester.pump();

    final Image image = tester.widget<Image>(
      find.byKey(const ValueKey<String>('tala-launch-image')),
    );
    expect((image.image as AssetImage).assetName,
        'assets/images/launch_cover.jpg');
    expect(image.fit, BoxFit.cover);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(TalaLogoMark), findsNothing);
  });

  testWidgets('Login y recuperación usan foto original de alta resolución',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(model: model)));
    await tester.pump();
    expect(currentPhoto(tester), 'assets/images/auth_login.jpg');
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();
    expect(currentPhoto(tester), 'assets/images/auth_login.jpg');
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Crear cuenta usa fotografía independiente del login',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(model: model)));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(currentPhoto(tester), 'assets/images/auth_register.jpg');
    expect(placeholder(tester, 'signup-name'), 'Nombre');
    expect(placeholder(tester, 'signup-email'), 'Correo electrónico');
    expect(placeholder(tester, 'signup-password'), 'Contraseña');
    expect(placeholder(tester, 'signup-confirm-password'),
        'Confirmar contraseña');
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Correo oculta placeholder al enfocarse y lo recupera si queda vacío',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(model: model)));
    await tester.pump();
    expect(placeholder(tester, 'login-email'), 'Correo electrónico');

    final Finder email = find.byKey(const ValueKey<String>('login-email'));
    await tester.tap(email);
    await tester.pump();
    expect(placeholder(tester, 'login-email'), isNull);

    await tester.enterText(email, 'prueba@correo.com');
    await tester.pump();
    expect(placeholder(tester, 'login-email'), isNull);

    await tester.enterText(email, '');
    await tester.pump();
    expect(placeholder(tester, 'login-email'), isNull);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(placeholder(tester, 'login-email'), 'Correo electrónico');
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Contraseña conserva texto sin etiqueta flotante naranja',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(model: model)));
    await tester.pump();

    final Finder password = find.byKey(const ValueKey<String>('login-password'));
    expect(placeholder(tester, 'login-password'), 'Contraseña');
    await tester.tap(password);
    await tester.pump();
    expect(placeholder(tester, 'login-password'), isNull);
    await tester.enterText(password, 'S3guraP4ss');
    await tester.pump();
    expect(placeholder(tester, 'login-password'), isNull);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(placeholder(tester, 'login-password'), isNull,
        reason: 'No duplicar placeholder encima de una contraseña capturada.');
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
