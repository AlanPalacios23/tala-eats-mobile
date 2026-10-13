import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/widgets/withdrawal_preview.dart';

void main() {
  testWidgets('repartidor: retiros son solo vista previa, no transfieren',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: WithdrawalPreviewCard())),
    ));

    final button = find.byKey(const ValueKey<String>('driver-withdraw-earnings'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Cuenta bancaria'), findsOneWidget);
    expect(find.textContaining('registro bancario estará disponible'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta bancaria'), findsNothing);
  });
}
