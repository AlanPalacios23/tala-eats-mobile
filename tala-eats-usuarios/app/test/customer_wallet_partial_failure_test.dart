import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

class _Wallet503Api extends TalaApi {
  @override
  Future<Map<String, dynamic>> bootstrap() async => <String, dynamic>{};
  @override
  Future<List<dynamic>> restaurantsForMarket(String code) async => <dynamic>[];
  @override
  Future<List<dynamic>> addresses() async => <dynamic>[];
  @override
  Future<List<dynamic>> orders() async => <dynamic>[];
  @override
  Future<List<dynamic>> favorites() async => <dynamic>[];
  @override
  Future<Map<String, dynamic>> wallet() async =>
      throw ApiException(503, 'Wallet temporalmente no disponible');
  @override
  Future<List<dynamic>> notifications() async => <dynamic>[];
  @override
  Future<dynamic> get(String path) async =>
      throw ApiException(503, 'Servicio secundario no disponible');
}

void main() {
  test('503 en Wallet no bloquea catálogo, pedidos ni inventa saldo verificado',
      () async {
    final model = TalaModel(apiClient: _Wallet503Api());
    await model.refreshAll();
    expect(model.online, true);
    expect(model.walletSyncFailed, true);
    expect(model.loading, false);
    expect(model.orders, isEmpty);
    expect(model.restaurants, isEmpty);
    model.dispose();
  });

  testWidgets('Tala Club distingue fallo de consulta de wallet vacía',
      (WidgetTester tester) async {
    final model = TalaModel(apiClient: _Wallet503Api());
    await model.refreshAll();
    await tester.pumpWidget(MaterialApp(
      home: WalletScreen(model: model),
    ));
    await tester.pump();
    expect(find.text('Sin verificar'), findsOneWidget);
    expect(find.text('Movimientos no disponibles'), findsOneWidget);
    expect(find.text('Sin movimientos'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
