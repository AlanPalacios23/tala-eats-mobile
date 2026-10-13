// v0.6.0 (candidata a producción): barra de estado legible en cocina,
// aviso de pedido nuevo, hoja «Acerca de», fecha en Inicio, superficies
// destacadas y contraste AA de textos secundarios.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/core/format.dart';
import 'package:talaeats_restaurant/core/theme.dart';
import 'package:talaeats_restaurant/data/app_services.dart';
import 'package:talaeats_restaurant/data/local/qa_scenario.dart';
import 'package:talaeats_restaurant/data/repositories.dart';
import 'package:talaeats_restaurant/main.dart';
import 'package:talaeats_restaurant/screens/more/more_screen.dart';
import 'package:talaeats_restaurant/screens/shell.dart';
import 'package:talaeats_restaurant/widgets/surfaces.dart';

class _FakeMedia implements MediaRepository {
  @override
  Future<String?> pickImage({
    required MediaSource source,
    required MediaPurpose purpose,
  }) async =>
      'test/fixtures/${purpose.name}.jpg';
}

Finder _key(String key) => find.byKey(ValueKey<String>(key));

Finder _nav(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _launchAndSignIn(WidgetTester tester) async {
  await tester.pumpWidget(
    TalaEatsRestaurantApp(
      services: AppServices.local(
        latency: const LocalLatency(
          read: Duration(milliseconds: 40),
          write: Duration(milliseconds: 40),
        ),
        scenario: QaScenario.normal,
        media: _FakeMedia(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, _key('alreadyHaveAccountButton'));
  await tester.enterText(_key('loginEmail'), 'propietario@correo.mx');
  await tester.enterText(_key('loginPassword'), 'clave-segura');
  await _tap(tester, _key('loginSubmitButton'));
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('aviso de pedido nuevo: solo cuando llega uno después de cargar', () {
    expect(newIncomingArrived(null, <int>{1, 2}), isFalse);
    expect(newIncomingArrived(<int>{1}, <int>{1}), isFalse);
    expect(newIncomingArrived(<int>{1, 2}, <int>{2}), isFalse);
    expect(newIncomingArrived(<int>{1}, <int>{1, 3}), isTrue);
    expect(newIncomingArrived(<int>{}, <int>{5}), isTrue);
  });

  test('textos secundarios con contraste AA', () {
    expect(_contrast(AppColors.inkFaint, AppColors.canvas),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.inkFaint, AppColors.surface),
        greaterThanOrEqualTo(4.5));
    expect(_contrast(AppColors.inkSoft, AppColors.canvas),
        greaterThanOrEqualTo(4.5));
  });

  testWidgets('la carga inicial no vibra como pedido nuevo', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _launchAndSignIn(tester);
    expect(
      calls.where(
        (c) => c.method == 'HapticFeedback.vibrate' && c.arguments == null,
      ),
      isEmpty,
    );
  });

  testWidgets('Inicio muestra la fecha y ventas en superficie destacada',
      (tester) async {
    await _launchAndSignIn(tester);
    expect(
      find.textContaining(shortDate(DateTime.now())),
      findsWidgets,
    );
    final tile = find.byType(MetricTile).first;
    final box = tester.widget<Container>(
      find.descendant(of: tile, matching: find.byType(Container)).first,
    );
    expect((box.decoration! as BoxDecoration).gradient, AppGradients.ink);
  });

  testWidgets('cocina usa íconos claros en la barra de estado',
      (tester) async {
    await _launchAndSignIn(tester);
    await tester.tap(_nav('Pedidos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir modo cocina'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) =>
            w is AnnotatedRegion<SystemUiOverlayStyle> &&
            w.value.statusBarIconBrightness == Brightness.light,
      ),
      findsOneWidget,
    );
  });

  testWidgets('«Acerca de la app» abre una hoja con marca y versión',
      (tester) async {
    await _launchAndSignIn(tester);
    await tester.tap(_nav('Más'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Acerca de la app'));

    expect(_key('aboutSheet'), findsOneWidget);
    expect(
      find.text('Panel para restaurantes · Versión $kAppVersion'),
      findsOneWidget,
    );
    expect(find.text('Licencias de código abierto'), findsOneWidget);
  });
}
