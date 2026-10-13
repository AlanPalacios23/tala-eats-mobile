import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/production_api.dart';
import 'package:talaeats_users/checkout_pricing.dart';

// P0: prueba aislada de rutas y serialización. No se hacen llamadas a producción.
class _OrderContractApi extends TalaApi {
  final List<String> calls = <String>[];
  Map<String, dynamic>? sentOrder;

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    calls.add('POST '+path);
    if (path == '/orders') {
      sentOrder = Map<String, dynamic>.from(body as Map);
      return <String, dynamic>{
        'id': 451, 'status': 'received', 'payment_method': 'cash',
        'subtotal': '200.00', 'service_fee': '14.00',
        'delivery_fee': '35.00', 'total': '249.00',
      };
    }
    throw StateError('Unexpected write: '+path);
  }

  @override
  Future<dynamic> get(String path) async {
    calls.add('GET '+path);
    if (path == '/v11/orders/451/live') {
      return <String, dynamic>{
        'order': <String, dynamic>{
          'id': 451, 'status': 'ready', 'total': '249.00',
          'payment_status': 'pending', 'payment_method': 'cash',
        },
      };
    }
    throw StateError('Unexpected read: '+path);
  }
}

void main() {
  test('P0 cliente: crear orden -> seguimiento servidor; sin cobros ni red externa', () async {
    final api = _OrderContractApi();
    final order = await api.createOrder(<String, dynamic>{
      'restaurant_id': 7,
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'menu_item_id': 99, 'quantity': 2},
      ],
      'payment_method': 'cash',
      'order_type': 'delivery',
    });
    expect(order['id'], 451);
    expect(order['status'], 'received');
    expect(order['total'], '249.00');
    expect(api.sentOrder?['restaurant_id'], 7);
    expect((api.sentOrder?['items'] as List).single['quantity'], 2);

    final live = await api.liveOrder(order['id'] as int);
    final current = Map<String, dynamic>.from(live['order'] as Map);
    expect(current['id'], order['id']);
    expect(current['status'], 'ready');
    expect(current['total'], order['total']);
    expect(api.calls, <String>['POST /orders', 'GET /v11/orders/451/live']);
  });

  test('P1 precios: 7% tope 25 y transporte SOLO de referencia', () {
    final cfg = CheckoutPricingPolicy.fromPaymentMethods(<String, dynamic>{
      'commercial_pricing_version': '1.6.2',
      'service_fee_rate': '0.07', 'service_fee_cap': '25',
      'delivery_base_fee': '35', 'delivery_included_km': '2',
      'delivery_additional_per_km': '5',
    });
    expect(cfg, isNotNull);
    CheckoutPricingPreview preview(double food, {String mode='delivery'}) =>
        CheckoutPricingPreview(
          policy: cfg, merchandiseSubtotal: food,
          restaurantDeliveryFee: 100, deliveryMode: mode,
          tip: 0, hasCoupon: false, plusMember: false,
        );
    expect(preview(200).serviceFee, 14);
    expect(preview(500).serviceFee, 25);
    expect(preview(200).deliveryReference, 35);
    expect(preview(200).estimatedReferenceTotal, 249);
    expect(preview(200, mode: 'pickup').deliveryReference, 0);
    expect(preview(200).disclosure.toLowerCase(), contains('no cotización'));
  });
}
