import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_restaurant/widgets/withdrawal_preview.dart';

void main() {
  testWidgets('botón de retiros: abre Mis retiros sin ejecutar transferencias',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: WithdrawalPreviewAction()),
      ),
    ));
    final button =
        find.byKey(const ValueKey<String>('restaurant-withdraw-earnings'));
    expect(button, findsOneWidget);
    expect(find.text('Retirar ganancias'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    // Pantalla A con aviso honesto: no se mueve dinero ni se inventa saldo.
    expect(find.text('Mis retiros'), findsOneWidget);
    expect(find.textContaining('no se mueve dinero'), findsOneWidget);
    expect(find.text('Saldo no disponible'), findsOneWidget);
    expect(find.textContaining(r'$0'), findsNothing);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Mis retiros'), findsNothing);
    expect(find.text('Retirar ganancias'), findsOneWidget);
  });
}
