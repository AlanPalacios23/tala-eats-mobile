import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/order_submission_guard.dart';
import 'package:talaeats_users/pending_checkout_recovery.dart';
import 'package:talaeats_users/production_api.dart';

Map<String, dynamic> checkout() => <String, dynamic>{
  'restaurant_id': 1, 'payment_method': 'cash', 'order_type': 'pickup',
  'items': <Map<String, dynamic>>[<String, dynamic>{'menu_item_id': 1, 'quantity': 1}],
};

void main() {
  test('Write-ahead encrypted reference is saved BEFORE network POST', () async {
    String? disk;
    final events = <String>[];
    final guard = OrderSubmissionGuard(
      beforeSend: (ref) async { events.add('save'); disk = '7|$ref'; },
      afterResolution: () async { events.add('clear'); disk = null; },
    );
    final result = await guard.submit(checkout(), (payload) async {
      events.add('post');
      expect(disk, '7|' + payload['client_reference'].toString());
      return <String, dynamic>{'id': 23};
    });
    expect(result['id'], 23);
    expect(events, <String>['save', 'post', 'clear']);
    expect(disk, isNull);
  });

  test('Crash with lost ACK: new process recovers existing order via GET only', () async {
    String? disk;
    var posts = 0;
    final guard = OrderSubmissionGuard(
      beforeSend: (ref) async { disk = '9|$ref'; },
      afterResolution: () async { disk = null; },
    );
    await expectLater(guard.submit(checkout(), (_) async {
      posts++;
      throw ApiException(0, 'Lost response after COMMIT');
    }), throwsA(isA<ApiException>()));
    expect(posts, 1);
    final ref = disk!.split('|').last;
    final recovered = await PendingCheckoutRecovery.recover(
      userId: 9, signedIn: true, activeReference: null,
      read: () async => disk,
      lookup: (reference) async => <String, dynamic>{
        'id': 101, 'user_id': 9, 'client_reference': reference,
      },
      clear: () async { disk = null; },
      stillCurrent: () => true,
    );
    expect(recovered!['client_reference'], ref);
    expect(posts, 1);
    expect(disk, isNull);
  });

  test('Write failure never starts a checkout', () async {
    var posts = 0;
    final guard = OrderSubmissionGuard(
      beforeSend: (_) async => throw ApiException(0, 'Keystore unavailable'),
    );
    await expectLater(guard.submit(checkout(), (_) async {
      posts++;
      return <String, dynamic>{'id': 1};
    }), throwsA(isA<ApiException>()));
    expect(posts, 0);
  });

  test('Unknown, offline, server failure preserve the journal', () async {
    for (final status in <int>[0, 404, 500]) {
      var removed = false;
      await expectLater(PendingCheckoutRecovery.recover(
        userId: 12, signedIn: true, activeReference: null,
        read: () async => '12|ref-a',
        lookup: (_) async => throw ApiException(status, 'Synthetic'),
        clear: () async { removed = true; },
        stillCurrent: () => true,
      ), throwsA(isA<ApiException>()));
      expect(removed, isFalse);
    }
  });

  test('Different owner or invalid reference cannot query or clear', () async {
    for (final pending in <String>['88|ref-a', '12|bad ref']) {
      var reads = 0;
      await expectLater(PendingCheckoutRecovery.recover(
        userId: 12, signedIn: true, activeReference: null,
        read: () async => pending,
        lookup: (_) async { reads++; return <String, dynamic>{}; },
        clear: () async => fail('Never clear foreign order'),
        stillCurrent: () => true,
      ), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
      expect(reads, 0);
    }
  });

  test('Mismatched GET owner/id/reference must preserve the journal', () async {
    for (final response in <Map<String, dynamic>>[
      <String, dynamic>{'id': 5, 'user_id': 99, 'client_reference': 'ref-a'},
      <String, dynamic>{'id': 5, 'user_id': 4, 'client_reference': 'ref-b'},
      <String, dynamic>{'id': 0, 'user_id': 4, 'client_reference': 'ref-a'},
    ]) {
      var removed = false;
      await expectLater(PendingCheckoutRecovery.recover(
        userId: 4, signedIn: true, activeReference: null,
        read: () async => '4|ref-a', lookup: (_) async => response,
        clear: () async { removed = true; }, stillCurrent: () => true,
      ), throwsA(isA<ApiException>()));
      expect(removed, isFalse);
    }
  });

  test('Logout during GET never erases a future session journal', () async {
    var active = true;
    var removed = false;
    await expectLater(PendingCheckoutRecovery.recover(
      userId: 4, signedIn: true, activeReference: null,
      read: () async => '4|ref-a',
      lookup: (_) async {
        active = false;
        return <String, dynamic>{'id': 5, 'user_id': 4, 'client_reference': 'ref-a'};
      },
      clear: () async { removed = true; },
      stillCurrent: () => active,
    ), throwsA(isA<ApiException>()));
    expect(removed, isFalse);
  });

  test('Same-process retry retains key without GET or journal removal', () async {
    var queried = false;
    var removed = false;
    final recovered = await PendingCheckoutRecovery.recover(
      userId: 4, signedIn: true, activeReference: 'ref-a',
      read: () async => '4|ref-a',
      lookup: (_) async { queried = true; return <String, dynamic>{}; },
      clear: () async { removed = true; }, stillCurrent: () => true,
    );
    expect(recovered, isNull);
    expect(queried, isFalse);
    expect(removed, isFalse);
  });

  test('Confirmed 422 releases encrypted journal', () async {
    var cleared = false;
    final guard = OrderSubmissionGuard(
      beforeSend: (_) async {},
      afterResolution: () async { cleared = true; },
    );
    await expectLater(guard.submit(checkout(), (_) async {
      throw ApiException(422, 'Validation rejected');
    }), throwsA(isA<ApiException>()));
    expect(cleared, isTrue);
  });
}
