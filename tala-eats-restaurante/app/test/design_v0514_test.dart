// v0.5.14: perfil sin costo de envío editable y productos con foto en el
// detalle del pedido.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/data/app_services.dart';
import 'package:talaeats_restaurant/data/local/qa_scenario.dart';
import 'package:talaeats_restaurant/data/repositories.dart';
import 'package:talaeats_restaurant/main.dart';
import 'package:talaeats_restaurant/widgets/images.dart';

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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('perfil: el envío lo calcula Tala Eats y se puede guardar',
      (tester) async {
    await _launchAndSignIn(tester);
    await tester.tap(_nav('Más'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('envío calculado por Tala Eats'),
      findsOneWidget,
    );

    await _tap(tester, _key('editRestaurantButton'));
    expect(find.text('Perfil del restaurante'), findsOneWidget);
    expect(find.text('Costo de envío'), findsNothing);
    expect(_key('deliveryFeeNote'), findsOneWidget);

    await _tap(tester, _key('saveRestaurantButton'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Perfil del restaurante'), findsNothing);
    expect(find.text('Perfil actualizado.'), findsOneWidget);
  });

  testWidgets('detalle: productos con foto del catálogo', (tester) async {
    await _launchAndSignIn(tester);
    await tester.tap(_nav('Pedidos'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('#1842'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(AppThumbnail),
      ),
      findsWidgets,
    );
  });
}
