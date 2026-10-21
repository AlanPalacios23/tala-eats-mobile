import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  testWidgets('Bienvenida pantalla completa y Continuar abre flujo real',
      (WidgetTester tester) async {
    bool pressed = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: MediaQuery(
        data: const MediaQueryData(
          disableAnimations: true,
          accessibleNavigation: true,
        ),
        child: TalaWelcomeScreen(onContinue: () => pressed = true),
      ),
    ));
    await tester.pump();
    expect(find.text('Comienza a pedir lo que más te gusta.'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('talaWelcomeContinue')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey<String>('talaWelcomeContinue')));
    await tester.pump();
    expect(pressed, isTrue);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Continuar es idempotente ante un doble toque rapido',
      (WidgetTester tester) async {
    int navigations = 0;
    await tester.pumpWidget(MaterialApp(
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true, accessibleNavigation: true),
        child: SizedBox.shrink(),
      ),
    ));
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          disableAnimations: true,
          accessibleNavigation: true,
        ),
        child: TalaWelcomeScreen(onContinue: () => navigations++),
      ),
    ));
    await tester.pump();
    final Finder cta = find.byKey(const ValueKey<String>('talaWelcomeContinue'));
    await tester.tap(cta);
    await tester.tap(cta);
    expect(navigations, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fotografias se pueden recorrer deslizando sin abrir el login',
      (WidgetTester tester) async {
    int navigations = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          disableAnimations: true,
          accessibleNavigation: true,
        ),
        child: TalaWelcomeScreen(onContinue: () => navigations++),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey<int>(0)), findsOneWidget);
    await tester.fling(find.byType(TalaWelcomeScreen), const Offset(-240, 0), 1200);
    await tester.pump();
    expect(find.byKey(const ValueKey<int>(1)), findsOneWidget);
    expect(navigations, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Splash usa logo local y slogan de la referencia',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: LaunchScreen(),
      ),
    ));
    await tester.pump();
    expect(find.text('Pide, disfruta y repite.'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bienvenida adaptable a 320 y 430 dp con texto grande',
      (WidgetTester tester) async {
    for (final double width in <double>[320, 430]) {
      tester.view.physicalSize = Size(width, 780);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(
        theme: buildTalaTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 780),
            textScaler: const TextScaler.linear(1.3),
            disableAnimations: true,
            accessibleNavigation: true,
          ),
          child: TalaWelcomeScreen(onContinue: () {}),
        ),
      ));
      await tester.pump();
      expect(find.text('Continuar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
