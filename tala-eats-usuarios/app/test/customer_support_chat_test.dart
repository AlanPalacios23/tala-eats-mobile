import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

class _SupportQaApi extends TalaApi {
  _SupportQaApi({this.reject = false});
  bool reject;
  int posts = 0;
  int gets = 0;
  final List<Map<String, dynamic>> tickets = <Map<String, dynamic>>[];

  @override
  Future<dynamic> get(String path) async {
    expect(path, '/platform/support');
    gets++;
    return tickets.reversed.toList();
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    expect(path, '/platform/support');
    posts++;
    if (reject) throw ApiException(503, 'No hay conexión');
    final Map<String, dynamic> payload = Map<String, dynamic>.from(body! as Map);
    final Map<String, dynamic> ticket = <String, dynamic>{
      'id': posts, 'order_id': payload['order_id'],
      'category': payload['category'], 'message': payload['message'],
      'status': 'open', 'created_at': '2026-10-21T12:00:00',
    };
    tickets.add(ticket);
    return ticket;
  }
}

void main() {
  testWidgets('Soporte tipo chat: muestra casos reales y no inventa respuestas',
      (WidgetTester tester) async {
    final api = _SupportQaApi();
    api.tickets.add(<String, dynamic>{
      'id': 7, 'order_id': 123, 'category': 'pedido',
      'message': 'Mi pedido todavía no llegó', 'status': 'open',
      'created_at': '2026-10-21T12:00:00',
    });
    final model = TalaModel(apiClient: api);
    await tester.pumpWidget(MaterialApp(home: SupportScreen(model: model)));
    await tester.pumpAndSettle();
    expect(api.gets, greaterThan(0));
    expect(find.text('Mi pedido todavía no llegó'), findsOneWidget);
    expect(find.textContaining('Caso #7'), findsOneWidget);
    expect(find.textContaining('Las respuestas de agentes dentro del chat'), findsOneWidget);
    expect(find.text('Soporte respondió'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });

  testWidgets('Soporte: envío único confirmado por POST y mensaje persistente',
      (WidgetTester tester) async {
    final api = _SupportQaApi();
    final model = TalaModel(apiClient: api);
    await tester.pumpWidget(MaterialApp(
      home: SupportScreen(model: model, orderId: 42)));
    await tester.pumpAndSettle();
    expect(find.textContaining('pedido #42'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey<String>('supportChatInput')),
      'Necesito ayuda con mi pedido');
    await tester.tap(find.byKey(const ValueKey<String>('supportChatSend')));
    await tester.pumpAndSettle();
    expect(api.posts, 1);
    expect(api.tickets.single['order_id'], 42);
    expect(find.text('Necesito ayuda con mi pedido'), findsOneWidget);
    expect(find.textContaining('Caso #1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });

  testWidgets('Soporte: si servidor rechaza conserva borrador sin caso falso',
      (WidgetTester tester) async {
    final api = _SupportQaApi(reject: true);
    final model = TalaModel(apiClient: api);
    await tester.pumpWidget(MaterialApp(home: SupportScreen(model: model)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('supportChatInput')),
      'Problema de pago');
    await tester.tap(find.byKey(const ValueKey<String>('supportChatSend')));
    await tester.pumpAndSettle();
    expect(api.posts, 1);
    expect(api.tickets, isEmpty);
    expect(find.text('No hay conexión'), findsOneWidget);
    expect(find.text('Problema de pago'), findsNothing);
    expect(find.textContaining('Caso #'), findsNothing);
    expect(find.byKey(const ValueKey<String>('supportChatInput')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
