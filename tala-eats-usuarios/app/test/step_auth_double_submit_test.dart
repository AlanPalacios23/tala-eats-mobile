import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  testWidgets('Registro: doble pulsacion no abre dos consentimientos',
      (WidgetTester tester) async {
    final model = TalaModel();
    await tester.pumpWidget(MaterialApp(
      theme: buildTalaTheme(),
      home: TalaStepAuthScreen(
        model: model,
        onBack: () {},
        initialMode: TalaEmailMode.signUp,
      ),
    ));

    final inputs = <String>['Ana', 'López', 'ana@example.com', 'ClaveSegura123'];
    for (int step = 0; step < inputs.length; step++) {
      await tester.enterText(
        find.byKey(ValueKey<String>('stepInput$step')), inputs[step]);
      await tester.pump();
      if (step < inputs.length - 1) {
        await tester.tap(find.byKey(const ValueKey<String>('stepNext')));
        await tester.pumpAndSettle();
      }
    }

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('stepNext')));
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('consentTerms')),
      findsOneWidget);
    expect(find.byKey(const ValueKey<String>('consentPrivacy')),
      findsOneWidget);
    // No aceptamos los términos ni hacemos llamadas al backend durante QA.
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
