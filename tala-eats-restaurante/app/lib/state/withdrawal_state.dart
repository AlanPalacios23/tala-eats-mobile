import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/failures.dart';
import '../data/withdrawal_gateway.dart';
import '../models/withdrawal.dart';
import 'operations_controller.dart' show LoadStatus;

/// Motivos por los que hoy no se puede solicitar un retiro. La UI los muestra
/// como requisitos pendientes; ninguno se resuelve en el cliente.
enum WithdrawalBlocker {
  /// Esta versión de la app no envía retiros (interruptor de release).
  transfersDisabled,

  /// El servicio de retiros aún no está conectado.
  serviceNotConnected,

  /// El servidor no confirmó un saldo retirable.
  balanceUnavailable,

  /// Saldo confirmado en cero.
  noFunds,

  /// Hay ventas elegibles todavía en periodo de liberación.
  fundsOnHold,

  /// El servidor está conciliando movimientos.
  reconciling,

  bankNotLinked,
  bankPending,
  bankRestricted,
  bankUnavailable,

  /// El servidor no autorizó solicitudes para esta cuenta.
  serverNotAllowed,
}

/// Problemas del importe escrito. Los límites solo se aplican si el servidor
/// los envía.
enum WithdrawalAmountIssue {
  empty,
  invalid,
  belowMinimum,
  exceedsBalance,
  exceedsPerRequestLimit,
  exceedsDailyLimit,

  /// Sin saldo verificado no se puede validar ningún importe.
  cannotValidate,
}

List<WithdrawalBlocker> withdrawalBlockers(
  WithdrawalOverview overview, {
  required bool transfersEnabled,
}) {
  final blockers = <WithdrawalBlocker>[];
  if (!transfersEnabled) blockers.add(WithdrawalBlocker.transfersDisabled);
  if (!overview.isConnected) {
    blockers.add(WithdrawalBlocker.serviceNotConnected);
  }
  final balance = overview.balance;
  if (!overview.hasVerifiedBalance || balance == null) {
    blockers.add(WithdrawalBlocker.balanceUnavailable);
  } else if (balance.withdrawableCents <= 0) {
    blockers.add(
      (balance.eligibleCents ?? 0) > 0
          ? WithdrawalBlocker.fundsOnHold
          : WithdrawalBlocker.noFunds,
    );
  }
  if (overview.reconciling) blockers.add(WithdrawalBlocker.reconciling);
  switch (overview.bank.status) {
    case BankAccountStatus.notLinked:
      blockers.add(WithdrawalBlocker.bankNotLinked);
      break;
    case BankAccountStatus.pendingVerification:
      blockers.add(WithdrawalBlocker.bankPending);
      break;
    case BankAccountStatus.restricted:
      blockers.add(WithdrawalBlocker.bankRestricted);
      break;
    case BankAccountStatus.unavailable:
      blockers.add(WithdrawalBlocker.bankUnavailable);
      break;
    case BankAccountStatus.verified:
      break;
  }
  if (overview.isConnected && !overview.serverAllowsRequests) {
    blockers.add(WithdrawalBlocker.serverNotAllowed);
  }
  return blockers;
}

WithdrawalAmountIssue? validateWithdrawalAmount(
  String raw,
  WithdrawalOverview overview,
) {
  if (raw.trim().isEmpty) return WithdrawalAmountIssue.empty;
  final cents = parseAmountCents(raw);
  if (cents == null || cents <= 0) return WithdrawalAmountIssue.invalid;
  final balance = overview.balance;
  if (!overview.hasVerifiedBalance || balance == null) {
    return WithdrawalAmountIssue.cannotValidate;
  }
  final limits = overview.limits;
  final minimum = limits.minimumCents;
  if (minimum != null && cents < minimum) {
    return WithdrawalAmountIssue.belowMinimum;
  }
  if (cents > balance.withdrawableCents) {
    return WithdrawalAmountIssue.exceedsBalance;
  }
  final perRequest = limits.perRequestCents;
  if (perRequest != null && cents > perRequest) {
    return WithdrawalAmountIssue.exceedsPerRequestLimit;
  }
  final daily = limits.dailyRemainingCents;
  if (daily != null && cents > daily) {
    return WithdrawalAmountIssue.exceedsDailyLimit;
  }
  return null;
}

enum WithdrawalSubmitKind {
  /// Bloqueado por esta versión o por requisitos: no se llamó al servicio.
  blocked,

  /// Ya había un envío en curso (doble toque): no se llamó al servicio.
  ignored,

  /// El servidor recibió la solicitud (no significa depósito).
  received,

  failed,
}

class WithdrawalSubmitOutcome {
  const WithdrawalSubmitOutcome._(this.kind, {this.receipt, this.failure});

  const WithdrawalSubmitOutcome.blocked()
      : this._(WithdrawalSubmitKind.blocked);

  const WithdrawalSubmitOutcome.ignored()
      : this._(WithdrawalSubmitKind.ignored);

  const WithdrawalSubmitOutcome.received(WithdrawalReceipt receipt)
      : this._(WithdrawalSubmitKind.received, receipt: receipt);

  const WithdrawalSubmitOutcome.failed(AppFailure failure)
      : this._(WithdrawalSubmitKind.failed, failure: failure);

  final WithdrawalSubmitKind kind;
  final WithdrawalReceipt? receipt;
  final AppFailure? failure;
}

/// Estado de la experiencia de Retiros. Sin endpoints propios: todo pasa por
/// [WithdrawalGateway]. No guarda códigos 2FA ni datos bancarios.
class WithdrawalController extends ChangeNotifier {
  WithdrawalController(
    this.gateway, {
    this.transfersEnabled = kWithdrawalTransfersEnabled,
  });

  final WithdrawalGateway gateway;

  /// Solo controla solicitudes de dinero; nunca bloquea el alta bancaria.
  final bool transfersEnabled;

  bool _disposed = false;

  LoadStatus overviewStatus = LoadStatus.initial;
  WithdrawalOverview? overview;
  AppFailure? overviewFailure;

  LoadStatus historyStatus = LoadStatus.initial;
  List<WithdrawalRecord> history = const <WithdrawalRecord>[];
  AppFailure? historyFailure;

  bool _submitting = false;
  bool _openingBankLink = false;
  String? _idempotencyKey;

  bool get submitting => _submitting;
  bool get openingBankLink => _openingBankLink;

  /// Lo que la UI muestra mientras carga o si el servicio falla: nunca un
  /// saldo, siempre «no disponible».
  WithdrawalOverview get effectiveOverview =>
      overview ?? const WithdrawalOverview.notConnected();

  List<WithdrawalBlocker> get blockers => withdrawalBlockers(
        effectiveOverview,
        transfersEnabled: transfersEnabled,
      );

  bool get canRequest =>
      transfersEnabled && overviewStatus == LoadStatus.ready && blockers.isEmpty;

  Future<void> load() async {
    await Future.wait<void>(<Future<void>>[loadOverview(), loadHistory()]);
  }

  Future<void> loadOverview() async {
    if (overviewStatus == LoadStatus.loading) return;
    overviewStatus = LoadStatus.loading;
    overviewFailure = null;
    _notify();
    try {
      overview = await gateway.fetchOverview();
      overviewStatus = LoadStatus.ready;
    } catch (error) {
      overview = null;
      overviewFailure = AppFailure.from(error);
      overviewStatus = LoadStatus.failure;
    }
    _notify();
  }

  Future<void> loadHistory() async {
    if (historyStatus == LoadStatus.loading) return;
    historyStatus = LoadStatus.loading;
    historyFailure = null;
    _notify();
    try {
      final records = await gateway.fetchHistory();
      final sorted = List<WithdrawalRecord>.of(records)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      history = List<WithdrawalRecord>.unmodifiable(sorted);
      historyStatus = LoadStatus.ready;
    } catch (error) {
      historyFailure = AppFailure.from(error);
      historyStatus = LoadStatus.failure;
    }
    _notify();
  }

  /// Pide al servicio la URL efímera del onboarding bancario. Protegido contra
  /// doble toque. `null` = aún no disponible.
  Future<Uri?> bankOnboardingLink({String? totp}) async {
    if (_openingBankLink) return null;
    _openingBankLink = true;
    _notify();
    try {
      // Propagate provider/auth errors to the UI. A null link means only
      // that a gateway intentionally has no onboarding URL (e.g. QA/local).
      return await gateway.createBankOnboardingLink(totp: totp);
    } finally {
      _openingBankLink = false;
      _notify();
    }
  }

  /// Un borrador nuevo (otro importe) usa otra llave de idempotencia.
  void resetDraft() {
    _idempotencyKey = null;
  }

  /// Envía la solicitud solo si esta versión lo permite y no hay otra en
  /// curso. El código 2FA no se conserva en el controlador.
  Future<WithdrawalSubmitOutcome> submit({
    required int amountCents,
    required String totp,
  }) async {
    if (!transfersEnabled) return const WithdrawalSubmitOutcome.blocked();
    if (_submitting) return const WithdrawalSubmitOutcome.ignored();
    _submitting = true;
    _notify();
    final key = _idempotencyKey ??= newIdempotencyKey();
    try {
      final receipt = await gateway.requestWithdrawal(
        amountCents: amountCents,
        totp: totp,
        idempotencyKey: key,
      );
      _idempotencyKey = null;
      return WithdrawalSubmitOutcome.received(receipt);
    } catch (error) {
      // Se conserva la llave: reintentar no duplica la solicitud.
      return WithdrawalSubmitOutcome.failed(AppFailure.from(error));
    } finally {
      _submitting = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Llave aleatoria (128 bits, hex) para el encabezado `Idempotency-Key`.
String newIdempotencyKey([math.Random? random]) {
  final source = random ?? math.Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    buffer.write(source.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
