// Integración REST de retiros. Saldo y autorización son SIEMPRE del servidor.
// v0.5.12: compatible con el contrato del backend v1.6.3 HOTFIX3, no con v1.6.2.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/failures.dart';
import '../../models/withdrawal.dart';
import '../withdrawal_gateway.dart';
import 'remote_api.dart';

/// Un intento de retiro incierto queda registrado de forma cifrada en Android.
/// No se guardan TOTP, CLABE, saldo ni credenciales de Stripe.
abstract class WithdrawalAttemptJournal {
  Future<String?> read(int recipientId);
  Future<void> write(int recipientId, String value);
  Future<void> clear(int recipientId);
}

class SecureWithdrawalAttemptJournal implements WithdrawalAttemptJournal {
  SecureWithdrawalAttemptJournal({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;
  String _key(int id) => 'tala_restaurant_withdrawal_attempt_v1_$id';
  @override
  Future<String?> read(int id) => _storage.read(key: _key(id));
  @override
  Future<void> write(int id, String value) =>
      _storage.write(key: _key(id), value: value);
  @override
  Future<void> clear(int id) => _storage.delete(key: _key(id));
}

/// Permite ver datos reales de Stripe Connect sin inventar ni inferir un saldo.
/// Cuando el servidor aún es v1.6.2, la consulta falla y el CTA permanece
/// bloqueado (nunca se interpreta 404/503 como $0 o como permiso).
class RemoteWithdrawalGateway extends WithdrawalGateway {
  RemoteWithdrawalGateway(this.api,
      {this.recipientId, WithdrawalAttemptJournal? journal})
      : journal = journal ?? SecureWithdrawalAttemptJournal();

  final RemoteApi api;
  final int? recipientId;
  final WithdrawalAttemptJournal journal;

  @override
  bool get isConnected => recipientId != null && recipientId! > 0;

  @override
  WithdrawalGateway forRecipient(int id) =>
      RemoteWithdrawalGateway(api, recipientId: id, journal: journal);

  String get _path {
    final id = recipientId;
    if (id == null || id <= 0) {
      throw const AppFailure(FailureKind.permissionDenied,
          'No pudimos confirmar qué restaurante está conectado.');
    }
    return '/withdrawals/restaurant/$id';
  }

  Map<String, dynamic> _jsonMap(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const AppFailure(FailureKind.server,
          'El servicio de retiros devolvió una respuesta incompatible.');
    }
    return data;
  }

  @override
  Future<WithdrawalOverview> fetchOverview() async {
    Map<String, dynamic> data;
    try {
      data = _jsonMap(await api.get('$_path/balance'));
    } on AppFailure catch (failure) {
      // Solo "no existe balance" o "función aún desactivada" permite
      // consultar el alta bancaria. NO ocultamos 401/403, problemas de red,
      // errores de validación o fallos inesperados del servidor.
      final balanceNotAvailable = failure.kind == FailureKind.notFound ||
          (failure.kind == FailureKind.server &&
              (failure.detail ?? '').toLowerCase().contains('habilitad'));
      if (!balanceNotAvailable) rethrow;
      final restaurant = recipientId;
      if (restaurant == null || restaurant <= 0) rethrow;
      // RC9 Node Connect uses merchant-owner endpoints, not Python /withdrawals.
      final connect = _jsonMap(await api.get(
          '/owner/finance/connect/$restaurant/status'));
      final accountStatus = connect['ready'] == true
          ? 'pending_verification' : 'not_linked';
      final bankStatus = 'pending_review';
      // En v1.6.4 incluso una cuenta Stripe lista no es un banco autorizado
      // para retiros; siempre permanece bloqueado hasta la conciliación.
      return WithdrawalOverview(
        integration: WithdrawalIntegration.connected,
        bank: BankAccountSummary(
          status: accountStatus == 'not_linked'
              ? BankAccountStatus.notLinked
              : <String>{'pending_verification', 'verified'}
                      .contains(accountStatus) &&
                  <String>{'pending_review', 'not_linked'}
                      .contains(bankStatus)
                  ? BankAccountStatus.pendingVerification
                  : BankAccountStatus.unavailable,
          bankName: null,
          last4: null,
        ),
        serverAllowsRequests: false,
      );
    }
    final balance = WithdrawalBalance.fromJson(data);
    if (!balance.isMxn || balance.withdrawableCents < 0 ||
        balance.alreadyRequestedCents < 0 ||
        (balance.eligibleCents != null && balance.eligibleCents! < 0)) {
      throw const AppFailure(FailureKind.server,
          'El saldo recibido no está validado en MXN.');
    }
    // El backend v1.6.3 inicial no publica estado bancario ni permisos.
    // Con ese contrato antiguo: consulta visible, RETIRO BLOQUEADO.
    final bank = data['bank'];
    final controls = data['limits'];
    final bool allowed = data['server_allows_requests'] == true &&
        bank is Map<String, dynamic> && controls is Map<String, dynamic>;
    final bankMap = bank is Map<String, dynamic> ? bank : <String, dynamic>{};
    final limitsMap = controls is Map<String, dynamic>
        ? controls : <String, dynamic>{};
    final status = switch (bankMap['status']?.toString()) {
      'verified' => BankAccountStatus.verified,
      'not_linked' => BankAccountStatus.notLinked,
      'pending' => BankAccountStatus.pendingVerification,
      'restricted' => BankAccountStatus.restricted,
      _ => BankAccountStatus.unavailable,
    };
    int? positiveInt(Object? value) =>
        value is int && value >= 0 ? value : null;
    final verifiedBank = status == BankAccountStatus.verified;
    final last4 = bankMap['last4'];
    // No mostrar nombres/últimos dígitos de datos bancarios no certificados.
    final cleanLast4 = verifiedBank && last4 is String &&
            RegExp(r'^\d{4}$').hasMatch(last4)
        ? last4 : null;
    return WithdrawalOverview(
      integration: WithdrawalIntegration.connected,
      balance: balance,
      bank: BankAccountSummary(
        status: status,
        bankName: verifiedBank ? bankMap['bank_name']?.toString() : null,
        last4: cleanLast4,
      ),
      limits: WithdrawalLimits(
        minimumCents: positiveInt(limitsMap['minimum_cents']),
        perRequestCents: positiveInt(limitsMap['per_request_cents']),
        dailyRemainingCents: positiveInt(limitsMap['daily_remaining_cents']),
      ),
      serverAllowsRequests: allowed && verifiedBank &&
          cleanLast4 != null &&
          positiveInt(limitsMap['per_request_cents']) != null &&
          positiveInt(limitsMap['daily_remaining_cents']) != null,
      reconciling: data['reconciling'] == true,
    );
  }

  @override
  Future<List<WithdrawalRecord>> fetchHistory() async {
    final raw = await api.get('$_path/history');
    // Node RC9 returns {withdrawals: [...]}; older Python returned a list.
    final items = raw is Map<String, dynamic> ? raw['withdrawals'] : raw;
    if (items is! List) {
      throw const AppFailure(FailureKind.server,
          'Historial de retiros no disponible.');
    }
    return List<WithdrawalRecord>.unmodifiable(items.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Historial de retiros inválido');
      }
      return WithdrawalRecord.fromJson(item);
    }));
  }

  @override
  Future<bool> bankAccessRequiresTotp() async {
    final id = recipientId;
    if (id == null || id < 1) {
      throw const AppFailure(FailureKind.permissionDenied,
          'No se confirmó el restaurante para validar el banco.');
    }
    final status = _jsonMap(await api.get(
        '/owner/finance/connect/$id/status'));
    if (status['owner_approved'] is! bool) {
      throw const AppFailure(FailureKind.server,
          'No fue posible validar el estado de Stripe Connect.');
    }
    return true; // Backend v1.6.4 exige step-up en el alta y en el acceso.
  }

  @override
  Future<Uri?> createBankOnboardingLink({String? totp}) async {
    if (totp == null || !RegExp(r'^\d{6}$').hasMatch(totp)) {
      throw const AppFailure(FailureKind.validation, 'Código 2FA inválido.');
    }
    final result = _jsonMap(await api.post(
      '/owner/finance/connect/$recipientId/onboarding-link',
      body: <String, dynamic>{'totp': totp},
    ));
    final raw = result['url'];
    if (raw is! String) {
      throw const AppFailure(FailureKind.server, 'Stripe no entregó un enlace de registro.');
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        !const {'connect.stripe.com', 'dashboard.stripe.com'}.contains(uri.host)) {
      throw const AppFailure(FailureKind.server, 'Enlace de Stripe inválido.');
    }
    return uri;
  }

  @override
  Future<WithdrawalReceipt> requestWithdrawal({
    required int amountCents,
    required String totp,
    required String idempotencyKey,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(totp) ||
        !RegExp(r'^[A-Za-z0-9][A-Za-z0-9:_-]{15,95}$').hasMatch(idempotencyKey) ||
        amountCents < 100) {
      throw const AppFailure(FailureKind.validation,
          'Revisa el importe y el código de verificación.');
    }
    final id = recipientId;
    if (id == null || id <= 0) {
      throw const AppFailure(FailureKind.permissionDenied,
          'Restaurante no autenticado para retiros.');
    }
    // Node RC9 requires a stable UUID-shaped client key. Keep the original
    // 128-bit random bytes from our secure generator; never regenerate on retry.
    final uuid = idempotencyKey.length == 32 &&
            RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(idempotencyKey)
        ? '${idempotencyKey.substring(0, 8)}-'
          '${idempotencyKey.substring(8, 12)}-'
          '${idempotencyKey.substring(12, 16)}-'
          '${idempotencyKey.substring(16, 20)}-'
          '${idempotencyKey.substring(20, 32)}'.toLowerCase()
        : idempotencyKey;
    if (!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(uuid)) {
      throw const AppFailure(FailureKind.validation,
          'Identificador de solicitud inválido.');
    }
    final previous = await journal.read(id);
    var effectiveKey = uuid;
    if (previous != null) {
      Map<String, dynamic> saved;
      try {
        saved = jsonDecode(previous) as Map<String, dynamic>;
      } catch (_) {
        throw const AppFailure(FailureKind.conflict,
            'Retiro anterior pendiente de conciliación. Contacta a soporte.');
      }
      if (saved['amount_cents'] != amountCents ||
          saved['idempotency_key'] is! String ||
          !RegExp(r'^[a-fA-F0-9-]{36}$')
              .hasMatch(saved['idempotency_key'] as String)) {
        throw const AppFailure(FailureKind.conflict,
            'Existe una solicitud anterior por revisar. Consulta el historial antes de otro retiro.');
      }
      effectiveKey = saved['idempotency_key'] as String;
    } else {
      await journal.write(id, jsonEncode(<String, dynamic>{
        'amount_cents': amountCents,
        'idempotency_key': effectiveKey,
      }));
    }
    final json = _jsonMap(await api.post('$_path/request',
      idempotencyKey: effectiveKey,
      body: <String, dynamic>{
        'amount_cents': amountCents.toString(),
        'request_key': effectiveKey,
        'totp': totp,
      },
    ));
    final amount = _intOrNull(json['amount_cents']);
    final currency = json['currency'];
    final identifier = json['withdrawal_id'] ?? json['id'];
    final created = DateTime.tryParse((json['created_at'] ?? '').toString());
    final state = (json['state'] ?? '').toString();
    if (amount == null || amount != amountCents ||
        currency.toString().toLowerCase() != 'mxn' ||
        identifier == null || created == null ||
        !const <String>{'reserved', 'submitted', 'unknown', 'review_required'}
            .contains(state) ||
        json['bank_payout_created'] != false) {
      // The bank may have received a request. Retain its idempotency key
      // rather than interpreting a malformed 202 as successful transfer.
      throw const AppFailure(FailureKind.server,
          'El estado del retiro es incierto. Revisa el historial antes de repetir.');
    }
    await journal.clear(id);
    return WithdrawalReceipt(
      id: identifier.toString(), amountCents: amount,
      currency: 'mxn', receivedAt: created.toLocal(),
    );
  }
}

int? _intOrNull(Object? raw) {
  if (raw is int && raw >= 0) return raw;
  if (raw is String && RegExp(r'^\d{1,12}).hasMatch(raw)) {
    return int.tryParse(raw);
  }
  return null;
}
).hasMatch(raw)) {
    return int.tryParse(raw);
  }
  return null;
}
