import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/production_api.dart';

/// Backend contract QA with fake responses. No LIVE calls or Android device.
class _FakeCustomerApi extends TalaApi {
  final List<String> calls = <String>[];
  Object? lastBody;

  @override
  Future<dynamic> get(String path) async {
    calls.add('GET ' + path);
    if (path == '/auth/devices') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1, 'device_label': 'Android', 'active': true,
          'current': true, 'platform': 'android',
        },
        <String, dynamic>{
          'id': 2, 'device_label': 'Otro Android', 'active': true,
          'current': false, 'platform': 'android',
        },
      ];
    }
    if (path == '/v11/orders/71/substitutions') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 14, 'order_id': 71, 'status': 'pending',
          'replacement_menu_item_id': 9,
          'original_amount': '105.00', 'replacement_amount': '99.00',
        },
      ];
    }
    if (path == '/v11/orders/71/refunds') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 25, 'amount': '6.00', 'status': 'pending',
          'provider': 'stripe',
        },
      ];
    }
    throw StateError('Unexpected backend GET ' + path);
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    calls.add('POST ' + path);
    lastBody = body;
    if (path == '/auth/devices/2/revoke') {
      return <String, dynamic>{
        'revoked': true, 'device_id': 2, 'current': false,
      };
    }
    if (path == '/auth/devices/revoke-others') {
      return <String, dynamic>{'revoked': 1, 'current_device_id': 1};
    }
    if (path == '/v11/orders/71/substitutions/14/respond') {
      return <String, dynamic>{
        'id': 14, 'order_id': 71, 'status': 'resolved',
      };
    }
    throw StateError('Unexpected backend POST ' + path);
  }

  @override
  Future<dynamic> patch(String path, [Object? body]) async {
    calls.add('PATCH ' + path);
    lastBody = body;
    if (path == '/platform/addresses/3') {
      return <String, dynamic>{
        'id': 3, 'label': 'Casa', 'address': 'Centro, Tala',
        'lat': 20.65, 'lng': -103.70, 'is_default': true,
      };
    }
    throw StateError('Unexpected backend PATCH ' + path);
  }
}

void main() {
  test('Usuarios: sesiones actuales y revocación segura por ID', () async {
    final api = _FakeCustomerApi();
    final devices = await api.customerDevices();
    expect(devices.length, 2);
    expect(devices.first['current'], true);
    expect((await api.revokeCustomerDevice(2))['revoked'], true);
    expect((await api.revokeOtherCustomerDevices())['revoked'], 1);
    expect(api.calls, <String>[
      'GET /auth/devices',
      'POST /auth/devices/2/revoke',
      'POST /auth/devices/revoke-others',
    ]);
    await expectLater(api.revokeCustomerDevice(0), throwsArgumentError);
  });

  test('V11: sustitución solo del pedido y respuesta permitida', () async {
    final api = _FakeCustomerApi();
    final substitutions = await api.orderSubstitutions(71);
    expect(substitutions.single['status'], 'pending');
    final result = await api.respondOrderSubstitution(71, 14, 'accept');
    expect(result['status'], 'resolved');
    expect(api.lastBody, <String, dynamic>{'action': 'accept'});
    final refunds = await api.orderRefunds(71);
    expect(refunds.single['status'], 'pending');
    expect(refunds.single['amount'], '6.00'); // no infer bank-settled
    expect(api.calls, <String>[
      'GET /v11/orders/71/substitutions',
      'POST /v11/orders/71/substitutions/14/respond',
      'GET /v11/orders/71/refunds',
    ]);
    await expectLater(api.respondOrderSubstitution(71, 14, 'charge_extra'),
        throwsArgumentError);
    await expectLater(api.orderRefunds(-1), throwsArgumentError);
  });

  test('Direcciones: PATCH solo campos del dueño soportados', () async {
    final api = _FakeCustomerApi();
    final updated = await api.updateCustomerAddress(3,
      <String, dynamic>{'is_default': true});
    expect(updated['is_default'], true);
    expect(api.calls.single, 'PATCH /platform/addresses/3');
    expect(api.lastBody, <String, dynamic>{'is_default': true});
    await expectLater(api.updateCustomerAddress(3,
      <String, dynamic>{'owner_id': 999}), throwsArgumentError);
  });
}
