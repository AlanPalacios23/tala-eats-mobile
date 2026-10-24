import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/models/delivery.dart';

DeliveryJob job(String tender) => DeliveryJob(
  id:'TE-1234',serverId:1234,
  restaurant:'Tienda Tala',restaurantAddress:'Tala',
  customer:'Cliente',customerAddress:'Tala',
  total:150.75,earning:40.00,distanceKm:2.5,etaMinutes:15,
  stage:DeliveryStage.toCustomer,paymentMethod:tender,
);

void main() {
  test('RC810: prepaid Stripe delivery NEVER signals collect cash', () {
    final delivery=job('stripe');
    expect(delivery.isCardPaid,isTrue);
    expect(delivery.collectsCash,isFalse);
    expect(delivery.copyWith(stage:DeliveryStage.delivered).isCardPaid,isTrue);
  });
  test('RC810: cash delivery explicitly requires collection', () {
    final delivery=job('cash');
    expect(delivery.collectsCash,isTrue);
    expect(delivery.isCardPaid,isFalse);
  });
  test('RC810: unknown/legacy tender must not silently assume cash', () {
    expect(job('unknown').collectsCash,isFalse);
    expect(job('unknown').isCardPaid,isFalse);
  });
}
