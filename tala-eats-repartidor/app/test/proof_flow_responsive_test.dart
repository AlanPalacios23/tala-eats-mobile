import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/screens/proof_screen.dart';

import 'test_helpers.dart';

void main() {
  const cases = <(double, double)>[
    (320, 1.0),
    (320, 1.3),
    (360, 1.0),
    (360, 1.3),
    (390, 1.3),
    (430, 1.3),
  ];

  for (final (width, scale) in cases) {
    testWidgets('proof full flow ${width.toInt()}dp x$scale', (tester) async {
      setPhoneSize(tester, width, 720);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final c = await pumpSignedInApp(tester);
      c.setOnline(true);
      c.beginRoute();
      c.arrivedRestaurant();
      c.confirmPickup();
      c.beginCustomerRoute();
      await tester.pumpAndSettle();
      await tapPrimaryCta(tester);
      expect(find.byType(ProofScreen), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'abrir prueba');

      await tester.enterText(find.byKey(const Key('pin-field')), '1234');
      await tester.ensureVisible(find.byKey(const Key('attach-photo')));
      await tester.tap(find.byKey(const Key('attach-photo')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('retake-photo')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'foto adjunta');

      await tester.ensureVisible(find.byKey(const Key('proof-complete')));
      await tester.tap(find.byKey(const Key('proof-complete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('proof-confirm')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'hoja de confirmación');
    });
  }
}
