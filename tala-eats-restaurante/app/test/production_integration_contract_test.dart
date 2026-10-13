import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_restaurant/data/app_services.dart';
import 'package:talaeats_restaurant/data/remote/remote_withdrawal_gateway.dart';
import 'package:talaeats_restaurant/data/location_store.dart';
import 'package:talaeats_restaurant/data/withdrawal_gateway.dart';

void main() {
  test('production uses authenticated withdrawals and server location', () {
    final services = AppServices.production();
    expect(services.withdrawals, isA<RemoteWithdrawalGateway>());
    expect(services.withdrawals.forRecipient(7).isConnected, isTrue);
    expect(services.withdrawals.isConnected, isFalse);
    expect(services.locationStore, isA<RemoteRestaurantLocationStore>());
    expect(services.locationStore.sendsToServer, isTrue);
  });
  test('local preview cannot send money and does not send GPS to API', () {
    final services = AppServices.local();
    expect(services.withdrawals, isA<DisconnectedWithdrawalGateway>());
    expect(services.withdrawals.isConnected, isFalse);
    expect(services.locationStore.sendsToServer, isFalse);
  });
}
