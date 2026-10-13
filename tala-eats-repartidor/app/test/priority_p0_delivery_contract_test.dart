import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_driver/data/remote_api.dart';
import 'package:talaeats_driver/data/driver_backend.dart';
import 'package:talaeats_driver/models/delivery.dart';

// P0: fake inyectado: ni GPS ni órdenes se envían al servidor real.
class _DriverContractApi extends RemoteApi {
  _DriverContractApi() : super(baseUrl: 'http://127.0.0.1:1/api/v1');

  final List<String> writes = <String>[];
  Map<String, dynamic>? deliveryBody;

  @override
  Future<dynamic> patch(String path, {required Map<String, dynamic> body}) async {
    writes.add('PATCH '+path);
    if (path == '/driver/availability') {
      expect(body['is_online'], true);
      return <String, dynamic>{'ok': true};
    }
    if (path == '/driver/location') {
      expect(body, containsPair('lat', 20.653));
      expect(body, containsPair('lng', -103.7));
      return <String, dynamic>{'ok': true};
    }
    if (path == '/driver/orders/451/status') {
      expect(body['status'], 'picked_up');
      return <String, dynamic>{
        'id': 451, 'status': 'picked_up',
        'total': '249.00', 'driver_earning': '32.00', 'tip': '5.00',
      };
    }
    throw StateError('Unexpected patch: '+path);
  }

  @override
  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth=true}) async {
    writes.add('POST '+path);
    if (path == '/driver/orders/451/complete') {
      deliveryBody = body;
      return <String, dynamic>{
        'id': 451, 'status': 'delivered', 'total': '249.00',
        'driver_earning': '32.00', 'tip': '5.00',
      };
    }
    throw StateError('Unexpected post: '+path);
  }
}

const job = DeliveryJob(
  id: 'TE-0451', serverId: 451, restaurant: 'Tienda QA',
  restaurantAddress: 'Centro', customer: 'Cliente QA',
  customerAddress: 'Tala', total: 249, earning: 37,
  distanceKm: 2, etaMinutes: 15, stage: DeliveryStage.atRestaurant,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('P0 reparto: asignación -> recogida -> PIN/foto -> entrega', () async {
    final api = _DriverContractApi();
    final backend = DriverBackend(api: api);
    await backend.setAvailability(true);
    await backend.updateLocation(20.653, -103.7);
    final collected = await backend.updateOrderStatus(job, 'picked_up');
    expect(collected.serverId, 451);
    expect(collected.stage, DeliveryStage.pickedUp);
    expect(collected.total, 249);
    expect(collected.earning, 37);

    await api.session.saveRouteStage(451, 'toRestaurant');
    final done = await backend.completeDelivery(
      job: collected, pin: '1234', proofUrl: 'https://example.test/proof.jpg',
      lat: 20.653, lng: -103.7,
    );
    expect(done.stage, DeliveryStage.delivered);
    expect(done.serverId, 451);
    expect(done.total, 249);
    expect(done.earning, 37);
    expect(api.deliveryBody, containsPair('pin', '1234'));
    expect(api.deliveryBody, containsPair('photo_url', 'https://example.test/proof.jpg'));
    expect(await api.session.routeStage(451), isNull);
    expect(api.writes, <String>[
      'PATCH /driver/availability',
      'PATCH /driver/location',
      'PATCH /driver/orders/451/status',
      'POST /driver/orders/451/complete',
    ]);
    backend.close();
  });
}
