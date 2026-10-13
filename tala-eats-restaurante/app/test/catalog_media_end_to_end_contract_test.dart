import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/data/remote/remote_api.dart';
import 'package:talaeats_restaurant/data/remote/remote_repositories.dart';
import 'package:talaeats_restaurant/models/entities.dart';

class _TestSession extends RemoteSessionStore {
  @override
  Future<String?> accessToken() async => 'fake-token-test';

  @override
  Future<String?> deviceToken() async => null;

  @override
  Future<String> deviceId() async => 'test-device-123456';
}

void main() {
  test('imagen local se conserva si URL de backend es cadena vacía', () {
    final product = MenuProduct.fromJson(<String, dynamic>{
      'id': 11,
      'name': 'Prueba',
      'image_url': '',
      'image_path': '/data/user/0/com.talaeats.restaurant/files/foto.jpg',
    });
    final restaurant = RestaurantInfo.fromJson(<String, dynamic>{
      'id': 1,
      'name': 'Restaurante',
      'cover_image_url': '',
      'image_path': '/data/user/0/com.talaeats.restaurant/files/cover.jpg',
    });
    expect(product.imagePath, endsWith('foto.jpg'));
    expect(restaurant.imagePath, endsWith('cover.jpg'));
  });

  test('guardar foto POST multipart y confirmar persistencia en owner', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final dir = await Directory.systemTemp.createTemp('tala-catalog-test-');
    final file = File('${dir.path}/food.jpg');
    await file.writeAsBytes(const <int>[0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
    const url = 'https://talaeats.alan-palacios-dev.com/api/v1/uploads/catalog/r1-p11-demo.jpg';
    final called = <String>[];
    final api = RemoteApi(
      session: _TestSession(),
      client: MockClient((http.Request request) async {
        called.add('${request.method} ${request.url.path}');
        if (request.method == 'PATCH' && request.url.path == '/api/v1/owner/menu/11') {
          return http.Response(jsonEncode(<String, dynamic>{
            'id': 11, 'name': 'Producto', 'price': 100,
            'stock': 10, 'is_available': true,
          }), 200, headers: <String, String>{'content-type': 'application/json'});
        }
        if (request.method == 'POST' && request.url.path == '/api/v1/uploads/catalog/menu/11') {
          expect(request.headers['content-type'], contains('multipart/form-data'));
          expect(latin1.decode(request.bodyBytes), contains('name="file"'));
          return http.Response(jsonEncode(<String, String>{'url': url}), 200);
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/owner/restaurant') {
          return http.Response(jsonEncode(<String, dynamic>{
            'id': 1, 'menu_items': <Map<String, Object>>[<String, Object>{'id': 11, 'image_url': url}],
          }), 200);
        }
        return http.Response('not found', 404);
      }),
    );
    try {
      final result = await RemoteMenuRepository(api).saveProduct(ProductDraft(
        id: 11, name: 'Producto', description: '', category: 'General',
        price: 100, stock: 10, isAvailable: true, allergens: '',
        isCombo: false, imagePath: file.path,
      ));
      expect(result.imagePath, url);
      expect(called, <String>[
        'PATCH /api/v1/owner/menu/11',
        'POST /api/v1/uploads/catalog/menu/11',
        'GET /api/v1/owner/restaurant',
      ]);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
