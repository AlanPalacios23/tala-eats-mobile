import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/data/location_store.dart';
import 'package:talaeats_restaurant/data/remote/remote_api.dart';
import 'package:talaeats_restaurant/models/restaurant_location.dart';

// Un widget test no tiene llavero Android. Simulamos solo la sesión HTTP,
// manteniendo intacto el almacenamiento cifrado que usa producción.
class _LocationTestSession extends RemoteSessionStore {
  @override
  Future<String?> accessToken() async => 'token-de-prueba';

  @override
  Future<String?> deviceToken() async => null;

  @override
  Future<String> deviceId() async => 'dispositivo-test-location';
}

const fields = LocationServerFields(
  path: '/owner/restaurant',
  address: 'address', latitude: 'lat', longitude: 'lng',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const location = RestaurantLocation(
    street: 'Hidalgo 12', neighborhood: 'Centro', city: 'Tala',
    postalCode: '45300', latitude: 20.65, longitude: -103.70,
  );
  test('PATCH exige confirmación exacta del backend y conserva GPS', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/owner/restaurant');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['address'], location.singleLine);
      expect(body['lat'], 20.65);
      expect(body['lng'], -103.70);
      return http.Response(jsonEncode(<String, dynamic>{
        'id': 9, 'address': location.singleLine,
        'lat': 20.65, 'lng': -103.70,
      }), 200, headers: {'content-type': 'application/json'});
    });
    final store = RemoteRestaurantLocationStore(
      RemoteApi(client: client, session: _LocationTestSession()), fields,
      const LocalRestaurantLocationStore(),
    );
    final saved = await store.save(9, location);
    expect(saved.syncedToServer, isTrue);
    expect(saved.latitude, 20.65);
    expect((await const LocalRestaurantLocationStore().load(9))?.syncedToServer, isTrue);
  });
  test('un backend antiguo que ignora address no confirma sincronización', () async {
    final client = MockClient((request) async => http.Response(
      '{"id":9,"lat":20.65,"lng":-103.70}', 200,
      headers: {'content-type': 'application/json'},
    ));
    final store = RemoteRestaurantLocationStore(
      RemoteApi(client: client, session: _LocationTestSession()), fields,
      const LocalRestaurantLocationStore(),
    );
    await expectLater(store.save(9, location), throwsA(anything));
    expect(await const LocalRestaurantLocationStore().load(9), isNull);
  });
  test('editar solo texto no envía GPS nulo ni sobreescribe posición', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.containsKey('lat'), isFalse);
      expect(body.containsKey('lng'), isFalse);
      return http.Response(jsonEncode({
        'id': 9, 'address': location.singleLine,
        'lat': 20.0, 'lng': -103.0,
      }), 200, headers: {'content-type': 'application/json'});
    });
    final store = RemoteRestaurantLocationStore(
      RemoteApi(client: client, session: _LocationTestSession()), fields,
      const LocalRestaurantLocationStore(),
    );
    final saved = await store.save(9, const RestaurantLocation(
      street: 'Hidalgo 12', neighborhood: 'Centro', city: 'Tala',
      postalCode: '45300',
    ));
    expect(saved.syncedToServer, true);
    expect(saved.latitude, 20.0);
  });
}
