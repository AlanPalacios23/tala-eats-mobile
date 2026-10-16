import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/customer_native_push.dart';
import 'package:talaeats_users/production_api.dart';

class _PushApi extends TalaApi {
  final List<String> paths = <String>[];
  Map<String, dynamic>? posted;

  @override
  Future<dynamic> get(String path) async {
    paths.add('GET ' + path);
    if (path == '/mobile-push/config') {
      return <String, dynamic>{
        'enabled': false, 'provider': 'fcm',
        'platforms': <String>['android', 'ios'],
      };
    }
    throw StateError('Unexpected GET ' + path);
  }

  @override
  Future<dynamic> put(String path, [Object? body]) async {
    paths.add('PUT ' + path);
    posted = Map<String, dynamic>.from(body! as Map);
    if (path == '/mobile-push/devices') {
      return <String, dynamic>{
        'registered': true, 'application': 'customer',
        'marketing_opt_in': false,
      };
    }
    if (path.endsWith('/preferences')) {
      return <String, dynamic>{'marketing_opt_in': false};
    }
    throw StateError('Unexpected PUT ' + path);
  }

  @override
  Future<dynamic> delete(String path) async {
    paths.add('DELETE ' + path);
    if (path == '/mobile-push/devices/test-device-123') {
      return <String, dynamic>{'registered': false};
    }
    throw StateError('Unexpected DELETE ' + path);
  }
}

void main() {
  test('Firebase Android stays disabled without explicit project options', () {
    expect(CustomerNativePush.firebaseConfigured, isFalse);
  });

  test('FCM config and register customer-only, Android-only', () async {
    final api = _PushApi();
    final config = await api.customerPushConfig();
    expect(config['enabled'], false);
    final result = await api.registerCustomerPush(
      token: 'fcm-token-mock-very-long-not-real-1234567890',
      deviceId: 'test-device-123',
    );
    expect(result['registered'], true);
    expect(api.posted, <String, dynamic>{
      'token': 'fcm-token-mock-very-long-not-real-1234567890',
      'device_id': 'test-device-123',
      'application': 'customer',
      'platform': 'android',
      'marketing_opt_in': false,
    });
    expect(api.paths, <String>[
      'GET /mobile-push/config', 'PUT /mobile-push/devices',
    ]);
  });

  test('Marketing preference is provider-confirmed; unregister on logout', () async {
    final api = _PushApi();
    final updated = await api.changeCustomerPushMarketing('test-device-123', false);
    expect(updated['marketing_opt_in'], false);
    await api.unregisterCustomerPush('test-device-123');
    expect(api.paths, <String>[
      'PUT /mobile-push/devices/test-device-123/preferences',
      'DELETE /mobile-push/devices/test-device-123',
    ]);
    expect(api.posted, <String, dynamic>{'marketing_opt_in': false});
  });

  test('FCM rejects malformed IDs and very short tokens before HTTP', () async {
    final api = _PushApi();
    await expectLater(api.registerCustomerPush(token: 'short',
      deviceId: 'test-device-123'), throwsArgumentError);
    await expectLater(api.changeCustomerPushMarketing('bad id', false),
        throwsArgumentError);
    await expectLater(api.unregisterCustomerPush('../admin'),
        throwsArgumentError);
    expect(api.paths, isEmpty);
  });
}
