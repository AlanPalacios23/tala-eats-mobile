import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/order_submission_guard.dart';
import 'package:talaeats_users/production_api.dart';

Map<String, dynamic> draft({int quantity = 1}) => <String, dynamic>{
  'restaurant_id': 7,
  'address': 'Synthetic only',
  'order_type': 'pickup',
  'payment_method': 'cash',
  'items': <Map<String, dynamic>>[
    <String, dynamic>{'menu_item_id': 9, 'quantity': quantity},
  ],
};

void main() {
  test('P0 coalesces two active taps and sends only one request', () async {
    final guard = OrderSubmissionGuard();
    final response = Completer<Map<String, dynamic>>();
    int called = 0;
    final Future<Map<String, dynamic>> first = guard.submit(draft(), (body) {
      called++;
      expect(body['client_reference'], startsWith('android-7-'));
      return response.future;
    });
    final Future<Map<String, dynamic>> second = guard.submit(draft(), (_) {
      fail('Double tap must not make a second HTTP request');
    });
    expect(identical(first, second), isTrue);
    expect(called, 1);
    response.complete(<String, dynamic>{'id': 101, 'status': 'received'});
    expect((await first)['id'], 101);
    expect((await second)['id'], 101);
    expect(guard.unresolvedClientReference, isNull);
  });

  test('P0 timeout after commit preserves same key, body and header on retry', () async {
    final guard = OrderSubmissionGuard();
    final refs = <String>[];
    Future<Map<String, dynamic>> submit(Map<String, dynamic> body) async {
      refs.add(body['client_reference'] as String);
      expect(orderIdempotencyKeyFor('POST', '/orders', body), refs.last);
      if (refs.length == 1) throw ApiException(0, 'Network cut after commit');
      return <String, dynamic>{'id': 101};
    }
    await expectLater(guard.submit(draft(), submit),
        throwsA(isA<ApiException>()));
    expect(guard.unresolvedClientReference, isNotNull);
    final ok = await guard.submit(draft(), submit);
    expect(ok['id'], 101);
    expect(refs.length, 2);
    expect(refs.first, refs.last);
    expect(guard.unresolvedClientReference, isNull);
  });

  test('P0 5xx or 409 ambiguous errors preserve reference', () async {
    for (final code in <int>[408, 409, 429, 500, 503]) {
      final guard = OrderSubmissionGuard();
      final refs = <String>[];
      Future<Map<String, dynamic>> failRequest(Map<String, dynamic> body) async {
        refs.add(body['client_reference'] as String);
        throw ApiException(code, 'Synthetic ambiguous response');
      }
      await expectLater(guard.submit(draft(), failRequest),
          throwsA(isA<ApiException>()));
      await expectLater(guard.submit(draft(), failRequest),
          throwsA(isA<ApiException>()));
      expect(refs.length, 2);
      expect(refs[0], refs[1]);
    }
  });

  test('P0 changed cart cannot create another order while previous is uncertain', () async {
    final guard = OrderSubmissionGuard();
    var calls = 0;
    Future<Map<String, dynamic>> offline(Map<String, dynamic> body) async {
      calls++;
      throw ApiException(0, 'Offline after commit');
    }
    await expectLater(guard.submit(draft(), offline),
        throwsA(isA<ApiException>()));
    await expectLater(guard.submit(draft(quantity: 2), offline),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'HTTP', 409)));
    expect(calls, 1);
  });

  test('P0 confirmed validation reject releases attempt', () async {
    final guard = OrderSubmissionGuard();
    final refs = <String>[];
    Future<Map<String, dynamic>> send(Map<String, dynamic> body) async {
      refs.add(body['client_reference'] as String);
      if (refs.length == 1) throw ApiException(422, 'Invalid item');
      return <String, dynamic>{'id': 303};
    }
    await expectLater(guard.submit(draft(), send),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 422)));
    final result = await guard.submit(draft(quantity: 2), send);
    expect(result['id'], 303);
    expect(refs.length, 2);
    expect(refs[1], isNot(refs[0]));
  });

  test('P0 order key is not accidentally added to other endpoints', () {
    const ref = 'android-7-0123456789abcdef';
    final body = <String, dynamic>{'client_reference': ref};
    expect(orderIdempotencyKeyFor('POST', '/orders', body), ref);
    expect(orderIdempotencyKeyFor('GET', '/orders', body), isNull);
    expect(orderIdempotencyKeyFor('POST', '/payments/stripe/checkout', body), isNull);
    expect(orderIdempotencyKeyFor('POST', '/orders', <String, dynamic>{}), isNull);
    expect(orderIdempotencyKeyFor('POST', '/orders', <String, dynamic>{
      'client_reference': 'unsafe / injection',
    }), isNull);
  });

  test('P0 late result from logged-out session cannot erase new attempt', () async {
    final guard = OrderSubmissionGuard();
    final oldResponse = Completer<Map<String, dynamic>>();
    final freshResponse = Completer<Map<String, dynamic>>();
    final old = guard.submit(draft(), (_) => oldResponse.future);
    final oldReference = guard.unresolvedClientReference;
    guard.clearAfterConfirmedResolution(); // logout changes attempt generation
    final fresh = guard.submit(draft(quantity: 2), (_) => freshResponse.future);
    final newReference = guard.unresolvedClientReference;
    expect(newReference, isNot(oldReference));
    oldResponse.complete(<String, dynamic>{'id': 1});
    await old;
    expect(guard.unresolvedClientReference, newReference);
    freshResponse.complete(<String, dynamic>{'id': 2});
    expect((await fresh)['id'], 2);
    expect(guard.unresolvedClientReference, isNull);
  });

  test('P0 body remains unchanged for every retry and caller draft untouched', () async {
    final guard = OrderSubmissionGuard();
    final payload = draft();
    final sent = <String>[];
    Future<Map<String, dynamic>> sender(Map<String, dynamic> body) async {
      sent.add(body.toString());
      if (sent.length == 1) throw ApiException(502, 'Synthetic outage');
      return <String, dynamic>{'id': 111};
    }
    await expectLater(guard.submit(payload, sender), throwsA(isA<ApiException>()));
    await guard.submit(payload, sender);
    expect(sent[0], sent[1]);
    expect(payload.containsKey('client_reference'), false);
  });
}
