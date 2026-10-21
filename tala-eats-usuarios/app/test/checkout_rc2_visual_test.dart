import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  testWidgets('RC2: el estado de verificación no afirma pago disponible',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(20),
          child: PaymentCheckingCard(),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Verificando pagos disponibles'), findsOneWidget);
    expect(find.textContaining('Aún no se registrará ningún pedido'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Confirmar pedido'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RC2: tarjeta Stripe marca selección y funciona con texto 1.3',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: PaymentChoiceCard(
              icon: Icons.credit_card_outlined,
              title: 'Tarjeta y Google Pay',
              subtitle: 'Pago seguro procesado por Stripe',
              selected: true,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tarjeta y Google Pay'), findsOneWidget);
    expect(find.text('Pago seguro procesado por Stripe'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    await tester.tap(find.text('Tarjeta y Google Pay'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RC2: no disponibles da mensaje claro y acción de reintento',
      (WidgetTester tester) async {
    int retries = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PaymentUnavailableCard(onRetry: () => retries++, loading: false),
      ),
    ));
    expect(find.text('No hay métodos de pago disponibles'), findsOneWidget);
    expect(find.textContaining('Stripe o efectivo'), findsOneWidget);
    await tester.tap(find.text('Revisar de nuevo'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
