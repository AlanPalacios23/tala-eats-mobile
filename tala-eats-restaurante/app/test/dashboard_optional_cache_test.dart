import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:talaeats_restaurant/data/remote/optional_image_cache.dart';
import 'package:talaeats_restaurant/data/remote/remote_api.dart';
import 'package:talaeats_restaurant/data/remote/remote_repositories.dart';

class _Session extends RemoteSessionStore {
  @override
  Future<String?> accessToken() async => 'token-test';
  @override
  Future<String?> deviceToken() async => null;
  @override
  Future<String> deviceId() async => 'test-device-restaurant';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('caché de imágenes rota no bloquea el restaurante ni el menú', () async {
    final cache = OptionalImageCache(load: () async =>
        throw PlatformException(code: 'storage_unavailable'));
    final api = RemoteApi(session: _Session(), client: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/owner/restaurant');
      return http.Response(jsonEncode(<String, dynamic>{
        'id': 19,
        'name': 'Restaurante real',
        'is_open': true,
        'cover_image_url': 'https://example.com/restaurant.jpg',
        'menu_items': <Map<String, dynamic>>[
          <String, dynamic>{'id': 8, 'name': 'Tacos', 'price': 28.0,
            'image_url': 'https://example.com/tacos.jpg'},
        ],
      }), 200, headers: {'content-type': 'application/json'});
    }));
    final restaurant = await RemoteRestaurantRepository(api, cache: cache)
        .fetchRestaurant();
    expect(restaurant.id, 19);
    expect(restaurant.name, 'Restaurante real');
    final products = await RemoteMenuRepository(api, cache: cache).fetchMenu();
    expect(products, hasLength(1));
    expect(products.single.name, 'Tacos');
  });

  test('caché temporal mantiene referencias visuales sin escribir credenciales', () async {
    final cache = OptionalImageCache(load: () async =>
        throw MissingPluginException('storage plugin unavailable'));
    await cache.write('photo_only', 'https://example.com/image.jpg');
    expect(await cache.read('photo_only'), 'https://example.com/image.jpg');
  });
}
