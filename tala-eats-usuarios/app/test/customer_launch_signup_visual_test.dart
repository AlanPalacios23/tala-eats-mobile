import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  testWidgets('Splash ofrece estado accesible mientras prepara la aplicación',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 680));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: LaunchScreen()));
    // The loading indicator is deliberately indeterminate; it never settles.
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Pide, disfruta y repite.'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Preparando Tala Eats'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inicio permite crear cuenta sin pasar por un login innecesario',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int signIns = 0;
    int registrations = 0;
    await tester.pumpWidget(MaterialApp(
      home: TalaLoginMethodsScreen(
        onEmail: () => signIns++,
        onBack: () {},
        onRegister: () => registrations++,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Continuar con tu correo'), findsOneWidget);
    expect(find.text('¿Aún no tienes cuenta? Crear cuenta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('registerFromMethods')));
    expect(registrations, 1);
    expect(signIns, 0);
    expect(tester.takeException(), isNull);
  });
}
