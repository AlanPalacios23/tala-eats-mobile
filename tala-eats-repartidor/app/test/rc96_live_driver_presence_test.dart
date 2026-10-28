import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/core/controller.dart';
import 'package:talaeats_driver/core/mock_data.dart';
import 'package:talaeats_driver/data/driver_backend.dart';
import 'package:talaeats_driver/data/remote_api.dart';
import 'package:talaeats_driver/services/location_service.dart';

class _FakeBackend extends DriverBackend {
  _FakeBackend(this.events) : super(api: RemoteApi(baseUrl: 'http://127.0.0.1:1/api/v1'));
  final List<String> events;
  bool online = false;
  bool fresh = true;
  int gpsWrites = 0;

  @override
  Future<bool> restoreSession() async => true;
  @override
  Future<DriverDashboardData> dashboard() async => DriverDashboardData(
    profile: MockData.profile, online: online, active: null,
    history: const [], todayEarnings: 0, todayDeliveries: 0,
    todayKm: 0, todayOrdersTotal: 0, acceptance: 100,
    weekEarnings: List<double>.filled(7, 0),
  );
  @override
  Future<void> setAvailability(bool value) async {
    events.add('availability:$value');
    online = value;
  }
  @override
  Future<void> updateLocation(double lat, double lng) async {
    expect(online, true, reason: 'RC9.5 prohibits GPS before ONLINE');
    expect(lat, closeTo(20.653, .00001));
    expect(lng, closeTo(-103.7, .00001));
    events.add('gps');
    gpsWrites++;
  }
  @override
  Future<bool> hasConfirmedLiveGpsPresence() async {
    events.add('readiness');
    return fresh && online;
  }
  @override
  void close() {
    api.close();
  }
}

class _FakeLocation extends LocationService {
  _FakeLocation(this.events);
  final List<String> events;
  @override
  Future<DriverLocation> ensureCurrent() async {
    events.add('get-location');
    return const DriverLocation(20.653, -103.7);
  }
  @override
  Future<void> start(Future<void> Function(DriverLocation) onLocation) async {
    events.add('stream-start');
    await onLocation(const DriverLocation(20.653, -103.7));
  }
  @override
  Future<void> stop() async { events.add('stream-stop'); }
  @override
  Future<void> dispose() => stop();
}

void main() {
  testWidgets('RC9.5 presence: ONLINE precedes GPS; readiness confirms heartbeat',
      (tester) async {
    final events = <String>[];
    final backend = _FakeBackend(events);
    final driver = DriverController.production(
      backend: backend, location: _FakeLocation(events));
    await driver.bootstrap();
    expect(driver.signedIn, true);
    expect(await driver.setOnlineAsync(true), true);
    expect(driver.online, true);
    expect(events.indexOf('availability:true'), lessThan(events.indexOf('gps')));
    expect(events.indexOf('gps'), lessThan(events.indexOf('readiness')));
    final before = backend.gpsWrites;
    await tester.pump(const Duration(seconds: 41));
    await tester.pump();
    expect(backend.gpsWrites, greaterThan(before),
        reason: 'GPS must refresh even when the driver is stationary');
    expect(await driver.setOnlineAsync(false), true);
    expect(driver.online, false);
    driver.dispose();
  });

  testWidgets('RC9.5 does not show ONLINE if server rejects GPS presence',
      (tester) async {
    final events = <String>[];
    final backend = _FakeBackend(events)..fresh = false;
    final driver = DriverController.production(
      backend: backend, location: _FakeLocation(events));
    await driver.bootstrap();
    expect(await driver.setOnlineAsync(true), false);
    expect(driver.online, false);
    expect(backend.online, false);
    expect(events, contains('availability:false'));
    driver.dispose();
  });
}
