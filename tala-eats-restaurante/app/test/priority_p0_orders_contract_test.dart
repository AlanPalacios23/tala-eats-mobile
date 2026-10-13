import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_restaurant/data/remote/remote_api.dart';
import 'package:talaeats_restaurant/data/remote/remote_repositories.dart';
import 'package:talaeats_restaurant/models/entities.dart';

// P0: API falsa en memoria: nunca ejecuta escrituras al backend productivo.
class _OrdersContractApi extends RemoteApi {
  _OrdersContractApi() : super(baseUrl: 'http://127.0.0.1:1/api/v1');

  final List<String> requests = <String>[];
  final Map<int, String> states = <int, String>{451: 'received'};

  Map<String, dynamic> order(int id, {String method='cash', String pay='pending'}) =>
      <String, dynamic>{
        'id': id, 'status': states[id] ?? 'received',
        'payment_method': method, 'payment_status': pay,
        'total': '249.00', 'subtotal': '200.00',
        'restaurant_payout': '170.00', 'order_type': 'delivery',
        'items': <dynamic>[],
      };

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    requests.add('GET '+path);
    if (path == '/owner/orders') {
      expect(query, containsPair('limit', '200'));
      return <dynamic>[
        order(451),
        order(452, method: 'stripe', pay: 'pending'),
        order(453, method: 'stripe', pay: 'paid'),
      ];
    }
    throw StateError('Unexpected read: '+path);
  }

  @override
  Future<dynamic> patch(String path, {required Map<String, dynamic> body}) async {
    requests.add('PATCH '+path+' -> '+(body['status']?.toString() ?? ''));
    if (path != '/owner/orders/451/status') {
      throw StateError('Unexpected status route: '+path);
    }
    final status = body['status']?.toString() ?? '';
    if (!<String>['confirmed','preparing','ready'].contains(status)) {
      throw StateError('Unexpected status: '+status);
    }
    states[451] = status;
    return order(451);
  }
}

void main() {
  test('P0 tienda: filtra tarjeta pendiente y cambia recibido -> cocina -> listo', () async {
    final api = _OrdersContractApi();
    final repo = RemoteOrdersRepository(api);
    final orders = await repo.fetchOrders();
    expect(orders.map((o) => o.id), <int>[451, 453]);
    final cash = orders.first;
    expect(cash.stage, OrderStage.incoming);
    expect(cash.nextAction, OrderAction.accept);

    final confirmed = await repo.acceptOrder(451);
    expect(confirmed.stage, OrderStage.kitchen);
    expect(confirmed.nextAction, OrderAction.startPreparation);

    final preparing = await repo.startPreparation(451);
    expect(preparing.stage, OrderStage.kitchen);
    expect(preparing.nextAction, OrderAction.markReady);

    final ready = await repo.markReady(451);
    expect(ready.stage, OrderStage.ready);
    expect(ready.nextAction, isNull);
    expect(api.requests, <String>[
      'GET /owner/orders',
      'PATCH /owner/orders/451/status -> confirmed',
      'PATCH /owner/orders/451/status -> preparing',
      'PATCH /owner/orders/451/status -> ready',
    ]);
  });

  test('P1 tienda: tarjeta pagada no permite rechazo simplista', () {
    final paid = RestaurantOrder.fromJson(<String, dynamic>{
      'id': 453, 'status': 'received', 'payment_method': 'stripe',
      'payment_status': 'paid', 'total': 100,
    });
    expect(paid.canReject, isFalse);
    final cash = RestaurantOrder.fromJson(<String, dynamic>{
      'id': 451, 'status': 'received', 'payment_method': 'cash',
      'payment_status': 'pending', 'total': 100,
    });
    expect(cash.canReject, isTrue);
  });
}
