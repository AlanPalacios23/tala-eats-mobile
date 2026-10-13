import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

class _ChangingCatalogApi extends TalaApi {
  int generation = 0;

  @override
  Future<Map<String, dynamic>> restaurant(int id) async => <String, dynamic>{
        'id': id,
        'menu_items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 42,
            'name': 'Producto real',
            'is_available': true,
            'stock': 10,
            'image_url': 'https://talaeats.alan-palacios-dev.com/api/v1/uploads/catalog/p-$generation.jpg',
          },
        ],
      };

  @override
  Future<dynamic> get(String path) async => <String, dynamic>{
        'restaurant_id': 1,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'id': 42, 'name': 'Producto real',
            'effective_price': 100, 'available_now': true},
        ],
      };
}

void main() {
  test('al recargar un restaurante se usa la URL nueva sin alterar el menú', () async {
    final api = _ChangingCatalogApi();
    final model = TalaModel(apiClient: api);
    await model.refreshRestaurantMenu(1);
    expect(model.itemsFor(1).single.imageUrl, contains('p-0.jpg'));
    api.generation = 1;
    await model.refreshRestaurantMenu(1);
    expect(model.itemsFor(1).single.imageUrl, contains('p-1.jpg'));
    expect(model.itemsFor(1).single.name, 'Producto real');
    model.dispose();
  });
}
