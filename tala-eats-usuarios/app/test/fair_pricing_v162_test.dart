import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/checkout_pricing.dart';

final policy = <String, dynamic>{
  'commercial_pricing_version': '1.6.2',
  'service_fee_rate':'0.07','service_fee_cap':'25.00',
  'delivery_base_fee':'35.00','delivery_included_km':'2.00',
  'delivery_additional_per_km':'5.00'
};
CheckoutPricingPreview preview(double food, {String mode='delivery'}) => CheckoutPricingPreview(
  policy: CheckoutPricingPolicy.fromPaymentMethods(policy),
  merchandiseSubtotal: food, restaurantDeliveryFee: 100,
  deliveryMode: mode, tip: 0, hasCoupon: false, plusMember: false,
);
void main() {
  test('7% capped at 25 pesos on large order', () {
    expect(preview(100).serviceFee, 7);
    expect(preview(500).serviceFee, 25);
    expect(preview(1000).serviceFee, 25);
  });
  test('delivery shows base as minimum, not restaurant old higher fee', () {
    expect(preview(200).deliveryReference, 35);
    expect(preview(200).estimatedReferenceTotal, 249);
    expect(preview(500).disclosure, contains('2 km'));
  });
  test('pickup has no shipping', () {
    expect(preview(500, mode: 'pickup').deliveryReference, 0);
    expect(preview(500, mode: 'pickup').estimatedReferenceTotal, 525);
  });
  test('delivery reference text reads the CURRENT server policy, never a fixed $35', () {
    final changed = <String, dynamic>{...policy,
      'delivery_base_fee': '42.00',
      'delivery_included_km': '3.00',
      'delivery_additional_per_km': '8.00',
    };
    final view = CheckoutPricingPreview(
      policy: CheckoutPricingPolicy.fromPaymentMethods(changed),
      merchandiseSubtotal: 230,
      restaurantDeliveryFee: 15, // merchant field is not the shipping quote
      deliveryMode: 'delivery',
      tip: 20,
      hasCoupon: false,
      plusMember: false,
    );
    expect(view.deliveryReference, 42);
    expect(view.serviceFee, closeTo(16.10, 0.001));
    expect(view.estimatedReferenceTotal, closeTo(308.10, 0.001));
    expect(view.disclosure, contains('42.00'));
    expect(view.disclosure, contains('3.0 km'));
    expect(view.disclosure, contains('8.00'));
    expect(view.disclosure, isNot(contains('35.00')));
  });
  test('pickup does not show delivery tariff even under v1.6.2', () {
    expect(preview(230, mode:'pickup').disclosure, contains('sin cargo de envío'));
  });
  test('invalid policy rejected instead of invented fee', () {
    final row = {...policy, 'service_fee_cap': 'NaN'};
    expect(CheckoutPricingPolicy.fromPaymentMethods(row), isNull);
  });
}
