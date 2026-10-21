import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

Map<String, dynamic> _paymentConfig({bool cash = false, bool stripe = false}) =>
    <String, dynamic>{
      'methods': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'cash', 'enabled': cash},
        <String, dynamic>{'id': 'stripe', 'enabled': stripe},
        <String, dynamic>{'id': 'mercadopago', 'enabled': true},
      ],
    };

class _FlakyPaymentApi extends TalaApi {
  bool unavailable = false;
  int posts = 0;
  @override
  Future<dynamic> get(String path) async {
    expect(path, '/orders/payment-methods');
    if (unavailable) throw ApiException(503, 'Backend no disponible');
    return _paymentConfig(cash: true, stripe: true);
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    posts++;
    throw StateError('Nunca debe enviar pedidos con métodos sin verificar');
  }
}

class _DelayedPaymentApi extends TalaApi {
  final first = Completer<dynamic>();
  final second = Completer<dynamic>();
  int calls = 0;

  @override
  Future<dynamic> get(String path) {
    expect(path, '/orders/payment-methods');
    calls++;
    return calls == 1 ? first.future : second.future;
  }
}

class _MalformedPaymentApi extends TalaApi {
  @override
  Future<dynamic> get(String path) async {
    expect(path, '/orders/payment-methods');
    return <String, dynamic>{'methods': 'no-es-lista'};
  }
}

void main() {
  test('RC1: si red falla tras habilitar Stripe, invalida sesión de pagos sin POST', () async {
    final api = _FlakyPaymentApi();
    final model = TalaModel(apiClient: api);
    await model.refreshPaymentMethods();
    expect(model.paymentMethodsVerified, true);
    model.setPaymentMethod('stripe');
    expect(model.paymentMethod, 'stripe');

    api.unavailable = true;
    await expectLater(model.refreshPaymentMethods(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
    expect(model.paymentMethodsVerified, false);
    expect(model.hasAvailablePaymentMethod, false);
    expect(model.isPaymentMethodEnabled('stripe'), false);
    expect(model.cashPayments, false);
    expect(model.stripePayments, false);
    expect(model.paymentMethod, isEmpty);
    expect(model.customerPricingPolicy, isNull);
    await expectLater(model.placeOrder(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    expect(api.posts, 0);

    api.unavailable = false;
    await model.refreshPaymentMethods();
    expect(model.paymentMethodsVerified, true);
    expect(model.hasAvailablePaymentMethod, true);
    expect(model.mercadoPagoPayments, false);
    model.dispose();
  });

  test('RC1: respuesta antigua nunca reactiva Stripe tras refresh reciente', () async {
    final api = _DelayedPaymentApi();
    final model = TalaModel(apiClient: api);
    final older = model.refreshPaymentMethods();
    final newer = model.refreshPaymentMethods();
    expect(api.calls, 2);
    expect(model.hasAvailablePaymentMethod, false);

    api.second.complete(_paymentConfig(cash: false, stripe: false));
    await newer;
    expect(model.paymentMethodsVerified, true);
    expect(model.hasAvailablePaymentMethod, false);

    api.first.complete(_paymentConfig(cash: true, stripe: true));
    await older;
    expect(model.stripePayments, false);
    expect(model.cashPayments, false);
    expect(model.hasAvailablePaymentMethod, false);
    expect(model.paymentMethod, isEmpty);
    model.dispose();
  });

  test('RC1: configuración incompleta es error 502 y nunca checkout disponible',
      () async {
    final model = TalaModel(apiClient: _MalformedPaymentApi());
    await expectLater(model.refreshPaymentMethods(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)));
    expect(model.paymentMethodsVerified, false);
    expect(model.hasAvailablePaymentMethod, false);
    model.dispose();
  });
}
