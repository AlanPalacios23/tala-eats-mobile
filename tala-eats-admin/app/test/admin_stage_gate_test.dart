import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talaeats_admin/admin_api.dart';

// Se ejecuta SOLO con --dart-define de escritura y URL staging exacta.
void main() {
  const stage = 'https://admin-stage.example.test/api/v1';

  test('Mutaciones requieren coincidencia HTTPS exacta con staging', () async {
    expect(kAdminWritesEnabled, isTrue);
    expect(kAdminWriteApiBase, stage);
    final mismatched = AdminApi(
      baseUrl: 'https://production.example.test/api/v1',
      client: MockClient((_) async =>
          throw StateError('No se debe enviar tráfico a producción')),
    );
    expect(mismatched.writesEnabled, isFalse);
    await expectLater(
        mismatched.respondSupport(1, 'resolved', 'Respuesta de soporte real'),
        throwsA(isA<AdminApiException>()
            .having((e) => e.status, 'status', 403)));
    mismatched.dispose();

    final insecure = AdminApi(baseUrl: 'http://admin-stage.example.test/api/v1');
    expect(insecure.writesEnabled, isFalse);
    insecure.dispose();
  });

  test('Soporte y archivo usan contratos Node y no crean rutas nuevas', () async {
    final paths = <String>[];
    final api = AdminApi(
      baseUrl: stage,
      client: MockClient((req) async {
        paths.add('${req.method} ${req.url.path}');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (req.url.path.endsWith('/support/6')) {
          expect(body, {'status': 'resolved', 'reply': 'Respuesta de prueba al cliente'});
        } else {
          expect(body, {'confirm_name': 'Antojitos', 'reason': 'Cierre definitivo confirmado'});
        }
        return http.Response('{}', 200);
      }),
    );
    expect(api.writesEnabled, isTrue);
    await api.respondSupport(6, 'resolved', 'Respuesta de prueba al cliente');
    await api.archiveRestaurant(7, 'Antojitos', 'Cierre definitivo confirmado');
    expect(paths, [
      'PATCH /api/v1/admin/support/6',
      'PATCH /api/v1/admin/restaurants/7/archive',
    ]);
    api.dispose();
  });
}
