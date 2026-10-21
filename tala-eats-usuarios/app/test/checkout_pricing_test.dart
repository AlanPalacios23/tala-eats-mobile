import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/checkout_pricing.dart';
import 'package:talaeats_users/main.dart';
import 'package:talaeats_users/production_api.dart';

class _BackendPolicyApi extends TalaApi {
  _BackendPolicyApi(this.response);
  Map<String, dynamic> response;
  @override
  Future<dynamic> get(String path) async {
    if (path == '/orders/payment-methods') return response;
    throw StateError('Unrequested endpoint: $path');
  }
}

Map<String, dynamic> policy({String version = '1.5.2', String rate = '0.07', String delivery = '39.00'}) => <String, dynamic>{
  'commercial_pricing_version': version,
  'service_fee_rate': version == '1.5.2' ? rate : null,
  'delivery_base_fee': version == '1.5.2' ? delivery : null,
  'methods': <Map<String, dynamic>>[
    <String, dynamic>{'id': 'cash', 'enabled': true, 'service_fee_waived': false},
    <String, dynamic>{'id': 'stripe', 'enabled': true},
  ],
};

CheckoutPricingPreview reference({double food = 200, double tip = 0, String mode = 'delivery', double restaurantFee = 20, bool coupon = false, bool plus = false}) => CheckoutPricingPreview(
  policy: CheckoutPricingPolicy.fromPaymentMethods(policy()),
  merchandiseSubtotal: food, restaurantDeliveryFee: restaurantFee,
  deliveryMode: mode, tip: tip, hasCoupon: coupon, plusMember: plus,
);

void main() {
  test('7% sobre comida y tarifa base 39; comision restaurante NO añadida', () {
    final p = reference();
    expect(p.serviceFee, 14);
    expect(p.deliveryReference, 39);
    expect(p.estimatedReferenceTotal, 253);
  });
  test('recoger: 7% efectivo, sin envio ni propina', () {
    final p = reference(mode: 'pickup', tip: 50);
    expect(p.serviceFee, 14);
    expect(p.deliveryReference, 0);
    expect(p.estimatedReferenceTotal, 214);
  });
  test('redondeo de centavos es half-up del backend', () {
    final p = reference(food: 1.50);
    expect(p.serviceFee, 0.11);
    expect(p.estimatedReferenceTotal, 40.61);
  });
  test('si el restaurante anuncia mayor base se muestra referencia mayor', () {
    final p = reference(restaurantFee: 49.0);
    expect(p.deliveryReference, 49);
    expect(p.estimatedReferenceTotal, 263);
  });
  test('con cupon o Plus no se presenta una cotizacion definitiva', () {
    final p = reference(coupon: true, plus: true);
    expect(p.disclosure, contains('cupones'));
    expect(p.disclosure, contains('Plus'));
    expect(p.disclosure, contains('confirma'));
  });
  test('sin configuracion comercial no se inventan porcentajes o envios', () {
    final cfg = CheckoutPricingPolicy.fromPaymentMethods(policy(version: 'legacy'));
    expect(cfg, isNull);
    final p = CheckoutPricingPreview(policy: cfg, merchandiseSubtotal: 200, restaurantDeliveryFee: 20, deliveryMode: 'delivery', tip: 0, hasCoupon: false, plusMember: false);
    expect(p.serviceFee, isNull);
    expect(p.deliveryReference, isNull);
    expect(p.estimatedReferenceTotal, isNull);
  });
  test('parametros invalidos desde servidor son rechazados', () {
    expect(CheckoutPricingPolicy.fromPaymentMethods(policy(rate: 'NaN')), isNull);
    expect(CheckoutPricingPolicy.fromPaymentMethods(policy(delivery: '-1')), isNull);
  });
  test('efectivo y Stripe comparten la tarifa cuando backend activa politica', () async {
    final model = TalaModel(apiClient: _BackendPolicyApi(policy()));
    model.restaurants.add(const Restaurant(id: 1, name: 'Tienda', category: '', rating: 5, eta: '20 min', deliveryFee: 20, image: '', description: ''));
    model.cartRestaurantId = 1;
    model.cart.add(CartLine(item: const FoodItem(id: 15, restaurantId: 1, name: 'Burrito', description: '', price: 200, image: '', category: '')));
    await model.refreshPaymentMethods();
    model.setTip(0);
    model.setPaymentMethod('cash');
    expect(model.checkoutPreview.estimatedReferenceTotal, 253);
    model.setPaymentMethod('stripe');
    expect(model.checkoutPreview.estimatedReferenceTotal, 253);
    model.dispose();
  });
  test('RC0: nunca ofrece Mercado Pago para pedidos nuevos aunque lo habilite backend', () async {
    final cfg = <String, dynamic>{
      'methods': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'mercadopago', 'enabled': true},
        <String, dynamic>{'id': 'stripe', 'enabled': true},
        <String, dynamic>{'id': 'cash', 'enabled': true},
      ],
    };
    final model = TalaModel(apiClient: _BackendPolicyApi(cfg));
    await model.refreshPaymentMethods();
    expect(model.hasAvailablePaymentMethod, true);
    expect(model.mercadoPagoPayments, false);
    expect(model.onlinePayments, true);
    expect(model.isPaymentMethodEnabled('mercadopago'), false);
    expect(model.isPaymentMethodEnabled('stripe'), true);
    model.setPaymentMethod('mercadopago');
    expect(model.paymentMethod, isNot('mercadopago'));
    model.dispose();
  });

  test('RC0: backend con solo Mercado Pago deja checkout bloqueado', () async {
    final model = TalaModel(apiClient: _BackendPolicyApi(<String, dynamic>{
      'methods': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'mercadopago', 'enabled': true},
      ],
    }));
    await model.refreshPaymentMethods();
    expect(model.hasAvailablePaymentMethod, false);
    expect(model.paymentMethod, isEmpty);
    await expectLater(model.placeOrder(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    model.dispose();
  });

  test('RC0: si servidor deshabilita Stripe y efectivo se borra selección obsoleta', () async {
    final api = _BackendPolicyApi(<String, dynamic>{
      'methods': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'cash', 'enabled': true},
        <String, dynamic>{'id': 'stripe', 'enabled': true},
      ],
    });
    final model = TalaModel(apiClient: api);
    await model.refreshPaymentMethods();
    model.setPaymentMethod('stripe');
    expect(model.paymentMethod, 'stripe');

    api.response = <String, dynamic>{
      'methods': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'cash', 'enabled': false},
        <String, dynamic>{'id': 'stripe', 'enabled': false},
        <String, dynamic>{'id': 'mercadopago', 'enabled': true},
      ],
    };
    await model.refreshPaymentMethods();
    expect(model.hasAvailablePaymentMethod, false);
    expect(model.paymentMethod, isEmpty);
    expect(model.isPaymentMethodEnabled('mercadopago'), false);
    model.dispose();
  });

  testWidgets('sin métodos disponibles no se indica erróneamente que efectivo funciona',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PaymentUnavailableCard(onRetry: () {}, loading: false)),
    ));
    expect(find.text('No hay métodos de pago disponibles'), findsOneWidget);
    expect(find.textContaining('Stripe o efectivo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resumen del checkout muestra tarifa, envio y total transparente', (tester) async {
    final model = TalaModel(apiClient: _BackendPolicyApi(policy()));
    model.restaurants.add(const Restaurant(id: 1, name: 'Tienda', category: '', rating: 5, eta: '20 min', deliveryFee: 20, image: '', description: ''));
    model.cartRestaurantId = 1;
    model.cart.add(CartLine(item: const FoodItem(id: 15, restaurantId: 1, name: 'Burrito', description: '', price: 200, image: '', category: '')));
    model.setTip(0);
    await model.refreshPaymentMethods();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: CustomerCheckoutBreakdown(model: model)))));
    expect(find.text('Tarifa de servicio (7%)'), findsOneWidget);
    expect(find.text('Envío (referencia base)'), findsOneWidget);
    expect(find.text('Total de referencia'), findsOneWidget);
    expect(find.text(r'$14.00'), findsOneWidget);
    expect(find.text(r'$39.00'), findsOneWidget);
    expect(find.text(r'$253.00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
  });
}
