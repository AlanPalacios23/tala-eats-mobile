// Matriz de capturas P0 (qa/SCREENSHOT-MATRIX.md).
//
// No corre en el gate normal. Se genera con:
//   flutter test --update-goldens --dart-define=TALA_SCREENSHOTS=true test/screenshot_matrix_test.dart
// o con GENERAR-CAPTURAS.cmd. Las imágenes quedan en ../qa/screenshots/.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/data/app_services.dart';
import 'package:talaeats_restaurant/data/local/qa_scenario.dart';
import 'package:talaeats_restaurant/data/repositories.dart';
import 'package:talaeats_restaurant/main.dart';

const bool _enabled = bool.fromEnvironment('TALA_SCREENSHOTS');
const String _dir = '../../qa/screenshots';

class _FakeMedia implements MediaRepository {
  @override
  Future<String?> pickImage({
    required MediaSource source,
    required MediaPurpose purpose,
  }) async =>
      'qa/${purpose.name}.jpg';
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> assets) async {
    final loader = FontLoader(name);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await family('Figtree', <String>[
    'assets/fonts/Figtree_400Regular.ttf',
    'assets/fonts/Figtree_500Medium.ttf',
    'assets/fonts/Figtree_600SemiBold.ttf',
    'assets/fonts/Figtree_700Bold.ttf',
    'assets/fonts/Figtree_800ExtraBold.ttf',
  ]);
  await family('Bricolage', <String>[
    'assets/fonts/BricolageGrotesque_600SemiBold.ttf',
    'assets/fonts/BricolageGrotesque_700Bold.ttf',
    'assets/fonts/BricolageGrotesque_800ExtraBold.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final bytes = icons.readAsBytesSync();
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  }
}

AppServices _services(
  QaScenario scenario, {
  Duration read = const Duration(milliseconds: 40),
  Duration write = const Duration(milliseconds: 40),
}) =>
    AppServices.local(
      latency: LocalLatency(read: read, write: write),
      scenario: scenario,
      media: _FakeMedia(),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
}

void _tablet(WidgetTester tester) {
  tester.view.physicalSize = const Size(2560, 1600);
  tester.view.devicePixelRatio = 2;
}

Future<void> _shot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$_dir/$name.png'),
  );
}

Future<void> _start(
  WidgetTester tester,
  AppServices services, {
  bool tablet = false,
}) async {
  if (tablet) {
    _tablet(tester);
  } else {
    _phone(tester);
  }
  addTearDown(tester.view.reset);
  await tester.pumpWidget(TalaEatsRestaurantApp(services: services));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsWidgets);
  await Scrollable.ensureVisible(
    finder.evaluate().first,
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Finder _nav(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

Future<void> _signIn(WidgetTester tester, {bool settle = true}) async {
  await _tap(tester, _key('alreadyHaveAccountButton'));
  await tester.enterText(_key('loginEmail'), 'propietario@tacoselcentro.mx');
  await tester.enterText(_key('loginPassword'), 'clave-segura');
  await tester.ensureVisible(_key('loginSubmitButton'));
  await tester.tap(_key('loginSubmitButton'));
  if (settle) await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('01-08 bienvenida, alta y login', skip: !_enabled, (tester) async {
    await _start(tester, _services(QaScenario.normal));
    await _shot(tester, '01_welcome');

    await _tap(tester, _key('createMyRestaurantButton'));
    await _shot(tester, '02_onboarding_owner');

    await _tap(tester, _key('nextOnboardingButton'));
    await _shot(tester, '03_onboarding_validation');

    await tester.enterText(_key('ownerNameField'), 'Alan Palacios');
    await tester.enterText(_key('ownerEmailField'), 'alan@correo.mx');
    await tester.enterText(_key('ownerPhoneField'), '3312345678');
    await tester.enterText(_key('ownerPasswordField'), 'tacos2026');
    await _tap(tester, _key('nextOnboardingButton'));
    await tester.enterText(_key('restaurantNameField'), 'Tacos Alan');
    await _tap(tester, find.text('Tacos'));
    await _tap(tester, _key('restaurantPhotoPicker'));
    await _tap(tester, find.text('Elegir de la galería'));
    await _shot(tester, '04_onboarding_restaurant_photo');

    await _tap(tester, _key('nextOnboardingButton'));
    await tester.enterText(_key('productNameField'), 'Taco de asada');
    await tester.enterText(_key('productPriceField'), '28');
    await _tap(tester, _key('finishRestaurantButton'));
    await _shot(tester, '05_onboarding_product_photo_required');

    await _tap(tester, _key('firstProductPhotoPicker'));
    await _tap(tester, find.text('Elegir de la galería'));
    await _tap(tester, _key('finishRestaurantButton'));
    await _shot(tester, '06_onboarding_success');
  });

  testWidgets('07-08 login idle, cargando y error', skip: !_enabled, (tester) async {
    await _start(
      tester,
      _services(
        QaScenario.loginError,
        write: const Duration(milliseconds: 1500),
      ),
    );
    await _tap(tester, _key('alreadyHaveAccountButton'));
    await _shot(tester, '07_login_idle');

    await tester.enterText(_key('loginEmail'), 'propietario@tacoselcentro.mx');
    await tester.enterText(_key('loginPassword'), 'clave-segura');
    await tester.tap(_key('loginSubmitButton'));
    await tester.pump(const Duration(milliseconds: 200));
    await _shot(tester, '08a_login_loading');
    await tester.pumpAndSettle();
    await _shot(tester, '08b_login_error');
  });

  testWidgets('09-13 inicio, pedidos y acción en curso', skip: !_enabled, (tester) async {
    await _start(
      tester,
      _services(
        QaScenario.normal,
        read: const Duration(milliseconds: 1200),
        write: const Duration(milliseconds: 900),
      ),
    );
    await _signIn(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 300));
    await _shot(tester, '10_home_skeleton');
    await tester.pumpAndSettle();
    await _shot(tester, '09_home_loaded');

    await _tap(tester, _nav('Pedidos'));
    await _shot(tester, '11_orders_new');

    await Scrollable.ensureVisible(
      _key('orderAction-1842').evaluate().single,
      alignment: 0.5,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(_key('orderAction-1842'));
    await tester.pump(const Duration(milliseconds: 150));
    await _shot(tester, '12_order_action_loading');
    await tester.pumpAndSettle();

    await _tap(tester, find.text('En cocina').first);
    await _shot(tester, '13_orders_kitchen');

    await _tap(tester, find.byTooltip('Abrir modo cocina'));
    await _shot(tester, '14_kds_phone');
  });

  testWidgets('15 KDS tablet', skip: !_enabled, (tester) async {
    await _start(tester, _services(QaScenario.normal), tablet: true);
    await _signIn(tester);
    await _tap(tester, find.text('Cocina').first);
    await _shot(tester, '15_kds_tablet_landscape');
  });

  testWidgets('16-20 menú, editor, finanzas y más', skip: !_enabled, (tester) async {
    await _start(tester, _services(QaScenario.normal));
    await _signIn(tester);

    await _tap(tester, _nav('Menú'));
    await _shot(tester, '16_menu');

    await _tap(tester, find.text('Revisar'));
    await _shot(tester, '24_menu_stock_attention');

    await _tap(tester, find.text('Gringa al pastor'));
    await _shot(tester, '17_product_editor');
    await _tap(tester, find.byTooltip('Cerrar'));

    await _tap(tester, _key('addProductButton'));
    await _tap(tester, _key('saveProductButton'));
    await _shot(tester, '18_product_editor_validation');
    await _tap(tester, find.byTooltip('Cerrar'));

    await _tap(tester, _nav('Finanzas'));
    await _tap(tester, find.text('7 días'));
    await _shot(tester, '19_finance');

    // v0.5.11: retiros en modo informativo (sin servicio conectado).
    await _tap(tester, _key('restaurant-withdraw-earnings'));
    await _shot(tester, '25_withdrawals');
    await _tap(tester, _key('withdrawals-open-new'));
    await tester.enterText(_key('withdrawal-amount-field'), '250');
    await tester.pumpAndSettle();
    await _shot(tester, '26_new_withdrawal_blocked');
    await _tap(tester, find.byTooltip('Volver'));
    await _tap(tester, _key('withdrawals-open-history'));
    await _shot(tester, '27_withdrawal_history_pending');
    await _tap(tester, find.byTooltip('Volver'));
    await _tap(tester, find.byTooltip('Volver'));

    await _tap(tester, _nav('Más'));
    await _shot(tester, '20_more');
  });

  testWidgets('21 vacío', skip: !_enabled, (tester) async {
    await _start(tester, _services(QaScenario.empty));
    await _signIn(tester);
    await _tap(tester, _nav('Pedidos'));
    await _shot(tester, '21_empty_orders');
  });

  testWidgets('22 error y reintentar', skip: !_enabled, (tester) async {
    await _start(tester, _services(QaScenario.error));
    await _signIn(tester);
    await _shot(tester, '22_error_retry');
  });

  testWidgets('23 sin conexión', skip: !_enabled, (tester) async {
    await _start(tester, _services(QaScenario.offline));
    await _signIn(tester);
    await _shot(tester, '23_offline');
  });
}
