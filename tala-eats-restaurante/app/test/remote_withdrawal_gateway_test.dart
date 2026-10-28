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

  test('RC9 503 sin saldo permite consultar onboarding pero nunca habilita dinero', () async {
    final calls = <String>[];
    final api = RemoteApi(session: _Session(), client: MockClient((request) async {
      calls.add(request.url.path);
      if (request.url.path.endsWith('/balance')) {
        return http.Response(jsonEncode(<String, dynamic>{
          'error': 'WITHDRAWAL_BALANCE_RECONCILIATION_HOLD',
        }), 503);
      }
      return http.Response(jsonEncode(<String, dynamic>{
        'status': 'pending_verification',
        'bank': <String, dynamic>{'status': 'pending_review'},
        'server_allows_requests': false,
      }), 200);
    }));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 7, journal: _Journal());
    final status = await gateway.fetchOverview();
    expect(status.balance, isNull);
    expect(status.bank.status, BankAccountStatus.pendingVerification);
    expect(status.serverAllowsRequests, false);
    expect(calls, <String>[
      '/api/v1/withdrawals/restaurant/7/balance',
      '/api/v1/withdrawals/restaurant/7/connect/status',
    ]);
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

  test('payout 202 conserva idempotencia y nunca indica depósito', () async {
    final journal = _Journal();
    var calls = 0;
    final api = RemoteApi(session: _Session(), client: MockClient((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/withdrawals/restaurant/7/request');
      expect(request.headers['authorization'], 'Bearer token-de-prueba');
      expect(request.headers['idempotency-key'], 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'amount_cents': '24000',
        'request_key': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'totp': '123456',
      });
      return http.Response(jsonEncode(<String, dynamic>{
        'id': '25', 'amount_cents': '24000', 'currency': 'MXN',
        'status': 'submitted', 'created_at': '2026-10-12T12:30:00Z',
      }), 202);
    }));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 7, journal: journal);
    final result = await gateway.requestWithdrawal(amountCents: 24000,
        totp: '123456', idempotencyKey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    expect(result.status, WithdrawalStatus.requested);
    expect(calls, 1);
    expect(journal.saved, isEmpty);
  });

  test('fallo ambiguo retiene la misma llave y bloquea otro importe', () async {
    final journal = _Journal();
    final keys = <String>[];
    final api = RemoteApi(session: _Session(), client: MockClient((request) async {
      keys.add(request.headers['idempotency-key']!);
      return http.Response('indeterminado', 503);
    }));
    final gateway = RemoteWithdrawalGateway(api, recipientId: 7, journal: journal);
    for (final key in ['bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'cccccccccccccccccccccccccccccccc']) {
      await expectLater(gateway.requestWithdrawal(amountCents: 20000,
          totp: '123456', idempotencyKey: key), throwsA(isA<AppFailure>()));
    }
    expect(keys, <String>['bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb','bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb']);
    expect(journal.saved.containsKey(7), true);
    await expectLater(gateway.requestWithdrawal(amountCents: 21000,
        totp: '123456', idempotencyKey: 'dddddddddddddddddddddddddddddddd'),
        throwsA(isA<AppFailure>()));
    expect(keys.length, 2);
  });

  test('estado Stripe reserved/submitted/review_required no se confunde con pagado', () {
    expect(withdrawalStatusFromBackend('reserved'), WithdrawalStatus.requested);
    expect(withdrawalStatusFromBackend('submitted'), WithdrawalStatus.processing);
    expect(withdrawalStatusFromBackend('review_required'), WithdrawalStatus.held);
    expect(withdrawalStatusFromBackend('paid'), WithdrawalStatus.paid);
  });
}
