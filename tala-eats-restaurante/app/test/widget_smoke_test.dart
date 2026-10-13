import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/core/format.dart';
import 'package:talaeats_restaurant/data/app_services.dart';
import 'package:talaeats_restaurant/data/local/qa_scenario.dart';
import 'package:talaeats_restaurant/data/repositories.dart';
import 'package:talaeats_restaurant/main.dart';

/// Selector de fotos falso: devuelve una referencia sin abrir la galería.
class FakeMedia implements MediaRepository {
  @override
  Future<String?> pickImage({
    required MediaSource source,
    required MediaPurpose purpose,
  }) async =>
      'test/fixtures/${purpose.name}.jpg';
}

AppServices _services([QaScenario scenario = QaScenario.normal]) =>
    AppServices.local(
      latency: const LocalLatency(
        read: Duration(milliseconds: 40),
        write: Duration(milliseconds: 40),
      ),
      scenario: scenario,
      media: FakeMedia(),
    );

Future<void> _launch(
  WidgetTester tester, [
  QaScenario scenario = QaScenario.normal,
]) async {
  await tester.pumpWidget(TalaEatsRestaurantApp(services: _services(scenario)));
  await tester.pumpAndSettle();
}

Future<Finder> _centerKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  expect(finder, findsOneWidget);
  await Scrollable.ensureVisible(
    finder.evaluate().single,
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
  return finder;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = await _centerKey(tester, key);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  await _tapKey(tester, 'alreadyHaveAccountButton');
  await tester.enterText(
    find.byKey(const ValueKey<String>('loginEmail')),
    'propietario@correo.mx',
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('loginPassword')),
    'clave-segura',
  );
  await _tapKey(tester, 'loginSubmitButton');
}

Finder _navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('formato', () {
    test('money usa separador de miles y centavos', () {
      expect(money(1284.5), r'$1,284.50');
      expect(money(0), r'$0.00');
      expect(money(1234567), r'$1,234,567.00');
      expect(money(92, cents: false), r'$92');
    });

    test('parseMoney acepta coma o punto', () {
      expect(parseMoney('12,5'), 12.5);
      expect(parseMoney(r'$ 99.90'), 99.9);
      expect(parseMoney(''), isNull);
    });

    test('elapsedLabel es legible', () {
      expect(elapsedLabel(0), 'Ahora');
      expect(elapsedLabel(12), '12 min');
      expect(elapsedLabel(75), '1 h 15 min');
    });
  });

  testWidgets('primera apertura muestra bienvenida y crear restaurante',
      (tester) async {
    await _launch(tester);

    expect(find.text('Bienvenido a\nTala Eats Restaurante'), findsOneWidget);
    expect(find.text('Crear mi restaurante'), findsOneWidget);
    expect(find.text('Ya tengo cuenta'), findsOneWidget);
    expect(find.textContaining('demo'), findsNothing);
    expect(find.textContaining('MODO DISEÑO'), findsNothing);
  });

  testWidgets('ya tengo cuenta abre login', (tester) async {
    await _launch(tester);
    await _tapKey(tester, 'alreadyHaveAccountButton');

    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('login valida campos vacíos sin salir de la pantalla',
      (tester) async {
    await _launch(tester);
    await _tapKey(tester, 'alreadyHaveAccountButton');
    await _tapKey(tester, 'loginSubmitButton');

    expect(find.text('Escribe tu correo.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
  });

  testWidgets('login con error muestra mensaje de producto', (tester) async {
    await _launch(tester, QaScenario.loginError);
    await _signIn(tester);

    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('alta completa exige foto, confirma y abre el panel',
      (tester) async {
    await _launch(tester);
    await _tapKey(tester, 'createMyRestaurantButton');
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    // Paso 1 con validación inline.
    await _tapKey(tester, 'nextOnboardingButton');
    expect(find.text('Escribe tu nombre completo.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey<String>('ownerNameField')), 'Alan Palacios');
    await tester.enterText(
        find.byKey(const ValueKey<String>('ownerEmailField')), 'alan@correo.mx');
    await tester.enterText(
        find.byKey(const ValueKey<String>('ownerPhoneField')), '3312345678');
    await tester.enterText(
        find.byKey(const ValueKey<String>('ownerPasswordField')), 'tacos2026');
    await _tapKey(tester, 'nextOnboardingButton');

    // Paso 2.
    expect(find.text('Configura tu restaurante'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey<String>('restaurantNameField')), 'Tacos Alan');
    await tester.ensureVisible(find.text('Tacos'));
    await tester.tap(find.text('Tacos'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'nextOnboardingButton');

    // Paso 3: la foto es obligatoria.
    expect(find.text('Agrega tu primer producto'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('firstProductPhotoPicker')),
      findsOneWidget,
    );
    await tester.enterText(
        find.byKey(const ValueKey<String>('productNameField')), 'Taco de asada');
    await tester.enterText(
        find.byKey(const ValueKey<String>('productPriceField')), '28');
    await _tapKey(tester, 'finishRestaurantButton');
    expect(
      find.text('Agrega una foto para publicar tu primer producto.'),
      findsOneWidget,
    );

    await _tapKey(tester, 'firstProductPhotoPicker');
    await tester.tap(find.text('Elegir de la galería'));
    await tester.pumpAndSettle();
    expect(
      find.text('Agrega una foto para publicar tu primer producto.'),
      findsNothing,
    );

    await _tapKey(tester, 'finishRestaurantButton');
    expect(find.text('Solicitud enviada'), findsOneWidget);

    await _tapKey(tester, 'openPanelButton');
    expect(_navLabel('Inicio'), findsOneWidget);
    expect(_navLabel('Pedidos'), findsOneWidget);
    expect(_navLabel('Menú'), findsOneWidget);
    expect(_navLabel('Finanzas'), findsOneWidget);
    expect(_navLabel('Más'), findsOneWidget);
    expect(find.text('Tacos Alan'), findsWidgets);

    // Reinicio: conserva el alta y la sesión.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(TalaEatsRestaurantApp(services: _services()));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a\nTala Eats Restaurante'), findsNothing);
    expect(_navLabel('Inicio'), findsOneWidget);
  });

  testWidgets('login entra al panel y cerrar sesión vuelve a login',
      (tester) async {
    await _launch(tester);
    await _signIn(tester);

    expect(_navLabel('Inicio'), findsOneWidget);
    expect(find.text('Requiere atención'), findsOneWidget);

    await tester.tap(_navLabel('Más'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'signOutButton');
    await tester.tap(find.text('Cerrar sesión').last);
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de vuelta'), findsOneWidget);
    expect(find.text('Bienvenido a\nTala Eats Restaurante'), findsNothing);
  });

  testWidgets('aceptar pedido muestra estado pendiente individual',
      (tester) async {
    await _launch(tester);
    await _signIn(tester);

    await tester.tap(_navLabel('Pedidos'));
    await tester.pumpAndSettle();

    final accept = await _centerKey(tester, 'orderAction-1842');
    await tester.tap(accept);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Aceptando…'), findsOneWidget);
    // Otro pedido sigue disponible mientras tanto.
    expect(find.byKey(const ValueKey<String>('orderAction-1843')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Pedido #1842 aceptado.'), findsOneWidget);
  });

  testWidgets('modo cocina abre y muestra carriles', (tester) async {
    await _launch(tester);
    await _signIn(tester);

    await tester.tap(_navLabel('Pedidos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir modo cocina'));
    await tester.pumpAndSettle();

    expect(find.text('Cocina'), findsOneWidget);
    expect(find.text('Nuevos'), findsWidgets);
    expect(find.text('Preparando'), findsWidgets);
  });

  testWidgets('escenario vacío muestra estado sin pedidos', (tester) async {
    await _launch(tester, QaScenario.empty);
    await _signIn(tester);

    await tester.tap(_navLabel('Pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('Sin pedidos activos'), findsWidgets);
  });

  testWidgets('escenario de error permite reintentar', (tester) async {
    await _launch(tester, QaScenario.error);
    await _signIn(tester);

    expect(find.text('No pudimos cargar la información'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Requiere atención'), findsOneWidget);
  });

  testWidgets('escenario sin conexión muestra estado offline', (tester) async {
    await _launch(tester, QaScenario.offline);
    await _signIn(tester);

    expect(find.text('Sin conexión'), findsOneWidget);
  });
}
