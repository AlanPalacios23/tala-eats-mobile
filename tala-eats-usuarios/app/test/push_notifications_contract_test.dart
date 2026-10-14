import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  group('Datos de notificaciones push', () {
    test('Solo acepta identificadores de pedido positivos', () {
      expect(safePushOrderId(<String, dynamic>{'order_id': '7821'}), 7821);
      expect(safePushOrderId(<String, dynamic>{'order_id': 71}), 71);
      expect(safePushOrderId(<String, dynamic>{'order_id': '0'}), isNull);
      expect(safePushOrderId(<String, dynamic>{'order_id': '-3'}), isNull);
      expect(safePushOrderId(<String, dynamic>{'order_id': 'abc'}), isNull);
      expect(safePushOrderId(<String, dynamic>{}), isNull);
    });

    test('Sin Firebase no se finge que push está habilitado', () {
      // El test no presupone si el futuro build inyecta opciones FCM.
      // Sin iniciar el servicio, nunca se declara un dispositivo registrado.
      final TalaModel model = TalaModel();
      final CustomerPushService service = CustomerPushService(model);
      expect(service.configured, false);
      expect(service.registered, false);
      service.dispose();
      model.dispose();
    });
  });

  testWidgets('Buzón muestra activación pendiente, sin estado falso de registro',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    final CustomerPushService service = CustomerPushService(model);
    model.pushService = service;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(
        child: PushSetupCard(model: model, service: service),
      )),
    ));
    await tester.pump();

    expect(find.text('Avisos en tu celular'), findsOneWidget);
    expect(find.textContaining('aunque la app esté cerrada'), findsOneWidget);
    expect(find.textContaining('requieren configurar Firebase'), findsOneWidget);
    expect(find.text('Activar avisos de pedidos'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.pushService = null;
    service.dispose();
    model.dispose();
  });

  testWidgets('Buzón de notificaciones no se sustituye por mensajes ficticios',
      (WidgetTester tester) async {
    final TalaModel model = TalaModel();
    final CustomerPushService service = CustomerPushService(model);
    model.pushService = service;
    await tester.pumpWidget(MaterialApp(
      home: NotificationsScreen(model: model),
    ));
    await tester.pump();
    expect(find.text('Sin notificaciones'), findsOneWidget);
    expect(find.text('Avisos en tu celular'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    model.pushService = null;
    service.dispose();
    model.dispose();
  });
}
