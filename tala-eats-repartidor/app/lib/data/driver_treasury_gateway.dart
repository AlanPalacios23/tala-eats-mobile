// RC9 Node Treasury: a single authenticated financial truth for drivers.
// Earnings from completed deliveries are not bank-withdrawable funds.
// All amounts are transmitted as integer-cent strings. No CLABE/secrets here.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'remote_api.dart';

const bool kDriverBankWithdrawalUiEnabled = bool.fromEnvironment(
  'TALA_EATS_DRIVER_WITHDRAWAL_REQUEST_UI_ENABLED', defaultValue: false,
);

class DriverTreasurySnapshot {
  const DriverTreasurySnapshot({
    required this.driverId,
    required this.withdrawableCents,
    required this.requestedCents,
    required this.bankStatus,
    required this.canRequest,
    required this.eligible,
    required this.blockers,
    required this.history,
  });

  final int driverId;
  final int withdrawableCents;
  final int requestedCents;
  final String bankStatus;
  final bool canRequest;
  final bool eligible;
  final List<String> blockers;
  final List<DriverTreasuryEntry> history;

  static int _cents(Object? raw) {
    if (raw is! String || !RegExp(r'^\d{1,12}$').hasMatch(raw)) {
      throw const FormatException('Centavos del servidor no verificados');
    }
    final value = int.tryParse(raw);
    if (value == null || value < 0) throw const FormatException('Importe inválido');
    return value;
  }

  factory DriverTreasurySnapshot.parse(
    int driverId, Object? balanceData, Object? historyData,
  ) {
    if (balanceData is! Map<String, dynamic> ||
        historyData is! Map<String, dynamic> ||
        balanceData['payee_kind'] != 'driver' ||
        balanceData['payee_id'] != driverId ||
        historyData['payee_kind'] != 'driver' ||
        historyData['payee_id'] != driverId ||
        balanceData['currency'] != 'MXN' ||
        balanceData['unit'] != 'centavos' ||
        balanceData['server_allows_requests'] is! bool ||
        balanceData['payout_execution_enabled'] is! bool ||
        balanceData['bank'] is! Map ||
        historyData['withdrawals'] is! List) {
      throw const FormatException('Respuesta financiera no autorizada');
    }
    final bank = balanceData['bank'] as Map;
    final blockers = balanceData['blockers'];
    if (blockers is! List || blockers.any((item) => item is! String)) {
      throw const FormatException('Bloqueos financieros sin verificar');
    }
    final amount = _cents(balanceData['withdrawable_cents']);
    final pending = _cents(balanceData['already_requested_cents']);
    final entries = (historyData['withdrawals'] as List).map((raw) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Movimiento inválido');
      }
      return DriverTreasuryEntry.parse(raw);
    }).toList(growable: false);
    return DriverTreasurySnapshot(
      driverId: driverId,
      withdrawableCents: amount,
      requestedCents: pending,
      bankStatus: bank['status']?.toString() ?? 'unavailable',
      canRequest: kDriverBankWithdrawalUiEnabled &&
          balanceData['server_allows_requests'] == true &&
          balanceData['payout_execution_enabled'] == true &&
          bank['status'] == 'verified' &&
          blockers.isEmpty &&
          amount >= 100,
      eligible: balanceData['eligible'] == true,
      blockers: List<String>.unmodifiable(blockers.cast<String>()),
      history: List<DriverTreasuryEntry>.unmodifiable(entries),
    );
  }
}

class DriverTreasuryEntry {
  const DriverTreasuryEntry(this.id, this.amountCents, this.status, this.createdAt);
  final String id;
  final int amountCents;
  final String status;
  final DateTime createdAt;
  factory DriverTreasuryEntry.parse(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final cents = DriverTreasurySnapshot._cents(data['amount_cents']);
    final date = DateTime.tryParse((data['created_at'] ?? '').toString());
    final status = data['status'];
    if (id.isEmpty || date == null || status is! String ||
        !const <String>{
          'reserved','submitted','unknown','review_required',
          'paid','failed','canceled',
        }.contains(status)) {
      throw const FormatException('Movimiento financiero no reconocido');
    }
    return DriverTreasuryEntry(id, cents, status, date);
  }
}

String driverMoneyCents(int amount) {
  final pesos = amount ~/ 100;
  final cents = (amount % 100).toString().padLeft(2, '0');
  return '\$$pesos.$cents MXN';
}

class DriverTreasuryGateway {
  DriverTreasuryGateway(this.api, {FlutterSecureStorage? store})
      : _store = store ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );
  final RemoteApi api;
  final FlutterSecureStorage _store;

  Future<int> _driverId() async {
    final who = await api.get('/auth/me');
    if (who is! Map || who['role'] != 'driver' ||
        who['id'] is! int || (who['id'] as int) <= 0) {
      throw const FormatException('Identidad del repartidor no verificada');
    }
    return who['id'] as int;
  }

  Future<DriverTreasurySnapshot> load() async {
    final id = await _driverId();
    // Separate authorized reads; a failed request must never become a $0.
    final balance = await api.get('/withdrawals/driver/$id/balance');
    final history = await api.get('/withdrawals/driver/$id/history');
    return DriverTreasurySnapshot.parse(id, balance, history);
  }

  String _key(int id) => 'tala_driver_rc9_pending_withdrawal_$id';

  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// Requests stay physically OFF until both mobile release and Node approve.
  /// If network times out, the persisted key is reused and the operator must
  /// check history; a second amount is never silently submitted.
  Future<String> request({
    required DriverTreasurySnapshot snapshot,
    required int amountCents,
    required String totp,
  }) async {
    if (!snapshot.canRequest || !kDriverBankWithdrawalUiEnabled ||
        amountCents < 100 || amountCents > snapshot.withdrawableCents ||
        !RegExp(r'^\d{6}$').hasMatch(totp)) {
      throw StateError('Retiro bloqueado por verificación de cuenta o saldo');
    }
    final id = await _driverId();
    if (id != snapshot.driverId) throw StateError('Cambió la identidad del repartidor');
    final key = _key(id);
    final previous = await _store.read(key: key);
    String requestId;
    if (previous != null) {
      final data = jsonDecode(previous);
      if (data is! Map || data['amount_cents'] != amountCents ||
          data['request_key'] is! String) {
        throw StateError('Retiro anterior pendiente de conciliación');
      }
      requestId = data['request_key'] as String;
    } else {
      requestId = _uuid();
      await _store.write(key: key, value: jsonEncode({
        'amount_cents': amountCents, 'request_key': requestId,
      }));
    }
    final reply = await api.post('/withdrawals/driver/$id/request',body:{
      'amount_cents': amountCents.toString(),
      'request_key':requestId,'totp':totp,
    });
    if (reply is! Map || reply['bank_payout_created'] != false ||
        reply['amount_cents'] != amountCents.toString() ||
        reply['currency'] != 'mxn' || reply['id'] == null ||
        !const {'reserved','submitted','unknown','review_required'}
            .contains(reply['state'])) {
      throw StateError('Estado del retiro incierto; revisar historial');
    }
    await _store.delete(key:key);
    return reply['id'].toString();
  }
}
