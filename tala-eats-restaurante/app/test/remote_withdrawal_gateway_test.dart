import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/core/failures.dart';
import 'package:talaeats_restaurant/data/remote/remote_api.dart';
import 'package:talaeats_restaurant/data/remote/remote_withdrawal_gateway.dart';
import 'package:talaeats_restaurant/models/withdrawal.dart';

class _Session extends RemoteSessionStore {
  @override
  Future<String?> accessToken() async => 'token-de-prueba';
  @override
  Future<String?> deviceToken() async => null;
  @override
  Future<String> deviceId() async => 'dispositivo-de-prueba';
}

class _Journal implements WithdrawalAttemptJournal {
  final Map<int, String> saved = <int, String>{};
  @override
  Future<String?> read(int id) async => saved[id];
  @override
  Future<void> write(int id, String value) async { saved[id] = value; }
  @override
  Future<void> clear(int id) async { saved.remove(id); }
}

Map<String, dynamic> _balance({bool allow = true, bool bank = true}) => <String, dynamic>{
  'currency': 'MXN', 'eligible_cents': 50000,
  'already_requested_cents': 0, 'provider_available_cents': 50000,
  'withdrawable_cents': 50000, 'hold_days': 2,
  'bank': bank
      ? <String, dynamic>{'status': 'verified', 'last4': '1234', 'bank_name': 'BBVA'}
      : <String, dynamic>{'status': 'unavailable'},
  'server_allows_requests': allow,
  'limits': <String, dynamic>{'minimum_cents': 100,
    'per_request_cents': 50000, 'daily_remaining_cents': 100000},
  'reconciling': false,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('el banco y permiso vienen de servidor, nunca se inventan', () async {
    final api = RemoteApi(session: _Session(), client: MockClient((request) async {
      expect(request.url.path, '/api/v1/withdrawals/restaurant/7/balance');
      return http.Response(jsonEncode(_balance()), 200);
    }));
    final gateway = RemoteWithdrawalGateway(api, journal: _Journal()).forRecipient(7);
    final overview = await gateway.fetchOverview();
    expect(overview.balance!.withdrawableCents, 50000);
    expect(overview.bank.maskedLabel, 'BBVA ···· 1234');
    expect(overview.serverAllowsRequests, true);
  });

  test('sin autorización explícita el CTA debe quedar bloqueado', () async {
    final api = RemoteApi(session: _Session(), client: MockClient((_) async =>
        http.Response(jsonEncode(_balance(allow: false)), 200)));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 8, journal: _Journal());
    expect((await gateway.fetchOverview()).serverAllowsRequests, false);
  });

  test('backend viejo sin bank y limits no habilita enviar dinero', () async {
    final json = _balance()..remove('bank')..remove('limits');
    final api = RemoteApi(session: _Session(), client: MockClient((_) async =>
        http.Response(jsonEncode(json), 200)));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 8, journal: _Journal());
    final overview = await gateway.fetchOverview();
    expect(overview.bank.status, BankAccountStatus.unavailable);
    expect(overview.serverAllowsRequests, false);
  });

  test('v1.6.2 sin endpoint retiros devuelve error y no saldo falso', () async {
    final api = RemoteApi(session: _Session(), client: MockClient((_) async =>
        http.Response('not found', 404)));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 8, journal: _Journal());
    await expectLater(gateway.fetchOverview(), throwsA(isA<AppFailure>()));
  });

  test('401 en saldo no se oculta intentando consultar Connect', () async {
    var calls = 0;
    final api = RemoteApi(session: _Session(), client: MockClient((_) async {
      calls++;
      return http.Response('unauthorized', 401);
    }));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 7, journal: _Journal());
    await expectLater(
      gateway.fetchOverview(),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.sessionExpired)),
    );
    expect(calls, 1);
  });

  test('alta de Connect exige TOTP antes de llamar al servidor', () async {
    var calls = 0;
    final api = RemoteApi(session: _Session(), client: MockClient((_) async {
      calls++;
      return http.Response('unexpected', 500);
    }));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 7, journal: _Journal());
    await expectLater(gateway.createBankOnboardingLink(), throwsA(isA<AppFailure>()));
    await expectLater(gateway.createBankOnboardingLink(totp: '123'), throwsA(isA<AppFailure>()));
    expect(calls, 0);
  });

  test('Node RC9: 202 solo confirma una reserva, no pago al banco', () async {
    final journal = _Journal();
    var calls = 0;
    const rawKey = '0123456789abcdef0123456789abcdef';
    const uuid = '01234567-89ab-cdef-0123-456789abcdef';
    final api = RemoteApi(session: _Session(), client: MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/withdrawals/restaurant/7/request');
      expect(request.headers['authorization'], 'Bearer token-de-prueba');
      expect(request.headers['idempotency-key'], uuid);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'amount_cents': '24000', 'request_key': uuid, 'totp': '123456',
      });
      return http.Response(jsonEncode(<String, dynamic>{
        'id': '25', 'withdrawal_id': '25', 'amount_cents': '24000',
        'currency': 'mxn', 'state': 'reserved', 'bank_payout_created': false,
        'created_at': '2026-10-12T12:30:00Z',
      }), 202);
    }));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 7, journal: journal);
    final result = await gateway.requestWithdrawal(amountCents: 24000,
        totp: '123456', idempotencyKey: rawKey);
    expect(result.status, WithdrawalStatus.requested);
    expect(result.amountCents, 24000);
    expect(result.id, '25');
    expect(calls, 1);
    expect(journal.saved, isEmpty);
  });

  test('Node RC9: historia JSON con withdrawals, sin estados inventados', () async {
    final api = RemoteApi(session: _Session(), client: MockClient((request) async {
      expect(request.url.path, '/api/v1/withdrawals/restaurant/7/history');
      return http.Response(jsonEncode(<String, dynamic>{
        'payee_kind': 'restaurant', 'payee_id': 7, 'currency': 'MXN',
        'withdrawals': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '58', 'amount_cents': '1100', 'status': 'review_required',
            'created_at': '2026-10-28T04:30:00Z',
          },
        ],
      }), 200);
    }));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 7, journal: _Journal());
    final rows = await gateway.fetchHistory();
    expect(rows, hasLength(1));
    expect(rows.first.status, WithdrawalStatus.held);
    expect(rows.first.amountCents, 1100);
  });

  test('Node RC9: timeout conserva UUID y bloquea segundo importe', () async {
    final journal = _Journal();
    final keys = <String>[];
    final api = RemoteApi(session: _Session(), client: MockClient((request) async {
      keys.add(request.headers['idempotency-key']!);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['request_key'], keys.last);
      return http.Response('indeterminado', 503);
    }));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 7, journal: journal);
    for (final key in <String>[
      'aaaaaaaabbbbbbbbccccccccdddddddd',
      'eeeeeeeeffffffff1111111122222222',
    ]) {
      await expectLater(gateway.requestWithdrawal(amountCents: 20000,
          totp: '123456', idempotencyKey: key), throwsA(isA<AppFailure>()));
    }
    expect(keys, <String>[
      'aaaaaaaa-bbbb-bbbb-cccc-ccccdddddddd',
      'aaaaaaaa-bbbb-bbbb-cccc-ccccdddddddd',
    ]);
    expect(journal.saved.containsKey(7), true);
    await expectLater(gateway.requestWithdrawal(amountCents: 21000,
      totp: '123456', idempotencyKey: '33333333444444445555555566666666'),
        throwsA(isA<AppFailure>()));
    expect(keys, hasLength(2));
  });

  test('estado Stripe reserved/submitted/review_required no se confunde con pagado', () {
    expect(withdrawalStatusFromBackend('reserved'), WithdrawalStatus.requested);
    expect(withdrawalStatusFromBackend('submitted'), WithdrawalStatus.processing);
    expect(withdrawalStatusFromBackend('review_required'), WithdrawalStatus.held);
    expect(withdrawalStatusFromBackend('paid'), WithdrawalStatus.paid);
  });
}
