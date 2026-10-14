import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  testWidgets('Login muestra foto del cliente y solo controles esenciales',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(model: model)));
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('auth-food-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('login-email')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('login-password')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('login-submit')), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Términos'), findsOneWidget);
    expect(find.text('Privacidad'), findsOneWidget);
    expect(find.text('Bienvenido de vuelta'), findsNothing);
    expect(find.textContaining('sigue tu pedido en tiempo real'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Foto acompaña Crear cuenta sin eliminar validaciones legales',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(model: model)));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('auth-food-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('signup-name')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('signup-email')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('signup-password')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('signup-confirm-password')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('signup-legal-accept')), findsOneWidget);
    expect(find.text('Términos'), findsOneWidget);
    expect(find.text('Privacidad'), findsOneWidget);
    expect(find.text('Nunca compartas tu contraseña'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('signup-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Escribe tu nombre.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Recuperar contraseña reutiliza exactamente el mismo fondo',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(model: model)));
    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('auth-food-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('recover-email')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('recover-submit')), findsOneWidget);
    expect(find.text('Enviar enlace'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Login cabe a 320dp y no se desborda con teclado abierto',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(model: model)));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.showKeyboard(find.byKey(const ValueKey<String>('login-email')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });

  testWidgets('Políticas y privacidad siguen accesibles desde el login',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(model: model)));
    await tester.tap(find.text('Privacidad'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso de Privacidad'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
