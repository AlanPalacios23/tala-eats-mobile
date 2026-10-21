import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  testWidgets('Splash blanco conserva nombre y slogan con animacion reducida',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true, accessibleNavigation: true),
        child: LaunchScreen(),
      ),
    ));
    await tester.pump();
    expect(find.text('Pide, disfruta y repite.'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bienvenida usa solo foto B, branding libre y boton glass',
      (WidgetTester tester) async {
    int presses = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: TalaWelcomeScreen(onContinue: () => presses++),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('welcomePhotoB')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('welcomeWordmark')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('loginPhotoA')), findsNothing);
    expect(find.text('Bienvenido\na Tala Eats'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final Finder button = find.byKey(const ValueKey<String>('talaWelcomeContinue'));
    await tester.tap(button);
    await tester.tap(button);
    expect(presses, 1, reason: 'No debe continuar dos veces');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Metodos usa solo foto A y tres opciones sin logo central',
      (WidgetTester tester) async {
    int emailRequests = 0;
    int backRequests = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: TalaLoginMethodsScreen(
          onEmail: () => emailRequests++,
          onBack: () => backRequests++,
        ),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('loginPhotoA')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('welcomePhotoB')), findsNothing);
    expect(find.byKey(const ValueKey<String>('welcomeWordmark')), findsNothing);
    expect(find.byKey(const ValueKey<String>('signInGoogle')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('signInPhone')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('signInEmail')), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Continuar con tu celular'), findsOneWidget);
    expect(find.text('Continuar con tu correo'), findsOneWidget);
    expect(find.textContaining('Tala Eats'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey<String>('signInEmail')));
    expect(emailRequests, 1);
    await tester.tap(find.byKey(const ValueKey<String>('methodsBack')));
    expect(backRequests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Google ofrece opciones honestas: registro propio o correo',
      (WidgetTester tester) async {
    int emails = 0;
    int registrations = 0;
    await tester.pumpWidget(MaterialApp(
      home: TalaLoginMethodsScreen(
        onEmail: () => emails++,
        onRegister: () => registrations++,
        onBack: () {},
      ),
    ));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('signInGoogle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google todavía no está conectado'), findsOneWidget);
    expect(emails, 0);
    await tester.tap(find.byKey(const ValueKey<String>('createTalaAccount')));
    await tester.pumpAndSettle();
    expect(registrations, 1);
    expect(emails, 0);
    await tester.tap(find.byKey(const ValueKey<String>('signInGoogle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('existingTalaAccount')));
    await tester.pumpAndSettle();
    expect(emails, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Bienvenida y metodos son responsive con accesibilidad x1.3',
      (WidgetTester tester) async {
    for (final double width in <double>[320, 360, 390, 430]) {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      for (final Widget page in <Widget>[
        TalaWelcomeScreen(onContinue: () {}),
        TalaLoginMethodsScreen(onEmail: () {}, onBack: () {}),
      ]) {
        await tester.pumpWidget(MaterialApp(
          theme: buildTalaTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 780),
              textScaler: const TextScaler.linear(1.3),
              disableAnimations: true,
              accessibleNavigation: true,
            ),
            child: page,
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Sin overflow a ${width}dp y texto grande');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
