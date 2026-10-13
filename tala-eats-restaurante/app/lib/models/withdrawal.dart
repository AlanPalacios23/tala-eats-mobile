// Modelos de presentación para Retiros (v0.5.11).
//
// Importante: estos modelos NO calculan saldos, comisiones ni netos. Solo
// transportan lo que entregue el servicio de retiros cuando exista. Mientras
// la app no esté conectada, la UI muestra «Saldo no disponible» y nunca un
// importe inventado ni $0.

import '../core/format.dart';

/// Estado de la conexión con el servicio de retiros.
enum WithdrawalIntegration {
  /// La app todavía no está conectada al servicio de retiros (esta versión).
  notConnected,

  /// Los datos vienen del servicio de retiros de Tala Eats.
  connected,
}

/// Estado de la cuenta bancaria de cobro (onboarding alojado de Stripe
/// Connect, administrado por backend). La app nunca captura CLABE.
enum BankAccountStatus {
  notLinked,
  pendingVerification,
  verified,
  restricted,

  /// El servicio no pudo informar el estado.
  unavailable,
}

class BankAccountSummary {
  const BankAccountSummary({
    required this.status,
    this.bankName,
    this.last4,
  });

  const BankAccountSummary.notLinked()
      : status = BankAccountStatus.notLinked,
        bankName = null,
        last4 = null;

  final BankAccountStatus status;

  /// Nombre comercial del banco entregado por backend (opcional).
  final String? bankName;

  /// Últimos dígitos entregados por backend. Nunca se muestran completos.
  final String? last4;

  /// «BBVA ···· 1234» solo cuando backend confirmó la verificación y entregó
  /// al menos 4 dígitos. Si llegara un número largo, solo se usan los 4
  /// últimos. En cualquier otro caso devuelve `null`.
  String? get maskedLabel {
    if (status != BankAccountStatus.verified) return null;
    final digits = (last4 ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return null;
    final tail = digits.substring(digits.length - 4);
    final bank = (bankName ?? '').trim();
    return '${bank.isEmpty ? 'Cuenta' : bank} ···· $tail';
  }
}

/// Saldo de retiros según el contrato PREDEPLOY v1.6.3
/// (`GET /api/v1/withdrawals/restaurant/{restaurant_id}/balance`).
///
/// Todos los importes están en centavos y son exactamente los que entrega el
/// servidor. La app no resta, suma ni estima nada.
class WithdrawalBalance {
  const WithdrawalBalance({
    required this.currency,
    required this.withdrawableCents,
    required this.alreadyRequestedCents,
    this.eligibleCents,
    this.providerAvailableCents,
    this.holdDays,
  });

  /// Lectura estricta del contrato. Si faltan los campos imprescindibles
  /// lanza [FormatException] para que la UI muestre «Saldo no disponible» en
  /// lugar de un cero ficticio.
  factory WithdrawalBalance.fromJson(Map<String, dynamic> json) {
    final withdrawable = _intValue(json['withdrawable_cents']);
    final requested = _intValue(json['already_requested_cents']);
    if (withdrawable == null || requested == null) {
      throw const FormatException('Saldo de retiros incompleto.');
    }
    final currency = (json['currency'] ?? '').toString().trim();
    return WithdrawalBalance(
      currency: currency.isEmpty ? 'mxn' : currency.toLowerCase(),
      withdrawableCents: withdrawable,
      alreadyRequestedCents: requested,
      eligibleCents: _intValue(json['eligible_cents']),
      providerAvailableCents: _intValue(json['provider_available_cents']),
      holdDays: _intValue(json['hold_days']),
    );
  }

  final String currency;

  /// `withdrawable_cents`: lo único que la UI presenta como «Disponible para
  /// retirar».
  final int withdrawableCents;

  /// `already_requested_cents`: se presenta como «En proceso».
  final int alreadyRequestedCents;

  /// `eligible_cents` (informativo, no se presenta como retirable).
  final int? eligibleCents;

  /// `provider_available_cents` (informativo, no se presenta como retirable).
  final int? providerAvailableCents;

  /// `hold_days`: días de retención informados por backend.
  final int? holdDays;

  bool get isMxn => currency.toLowerCase() == 'mxn';
}

/// Límites dictados por el servidor. Ningún valor se codifica en la app:
/// si el servidor no los envía, la UI no los menciona.
class WithdrawalLimits {
  const WithdrawalLimits({
    this.minimumCents,
    this.perRequestCents,
    this.dailyRemainingCents,
  });

  final int? minimumCents;
  final int? perRequestCents;
  final int? dailyRemainingCents;
}

/// Fotografía completa de la pantalla «Mis retiros».
class WithdrawalOverview {
  const WithdrawalOverview({
    required this.integration,
    required this.bank,
    this.balance,
    this.limits = const WithdrawalLimits(),
    this.serverAllowsRequests = false,
    this.reconciling = false,
  });

  /// Lo que la app conoce hoy: servicio no conectado, sin saldo verificado y
  /// sin cuenta vinculada a través de Tala Eats.
  const WithdrawalOverview.notConnected()
      : integration = WithdrawalIntegration.notConnected,
        bank = const BankAccountSummary.notLinked(),
        balance = null,
        limits = const WithdrawalLimits(),
        serverAllowsRequests = false,
        reconciling = false;

  final WithdrawalIntegration integration;
  final BankAccountSummary bank;

  /// `null` = saldo no verificado. La UI nunca lo sustituye por $0.
  final WithdrawalBalance? balance;
  final WithdrawalLimits limits;

  /// Autorización explícita del servidor para solicitar retiros.
  final bool serverAllowsRequests;

  /// El servidor informa que está conciliando movimientos.
  final bool reconciling;

  bool get isConnected => integration == WithdrawalIntegration.connected;
  bool get hasVerifiedBalance => isConnected && balance != null;
}

/// Estados del historial (contrato futuro). «Pagado» solo se usa cuando el
/// backend lo informa como estado definitivo; nunca por un toque, una
/// animación ni una respuesta HTTP 202.
enum WithdrawalStatus {
  requested,
  processing,
  paid,
  failed,
  cancelled,
  held,
  unknown,
}

WithdrawalStatus withdrawalStatusFromBackend(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'requested':
    case 'pending':
    case 'reserved':
      return WithdrawalStatus.requested;
    case 'processing':
    case 'in_transit':
    case 'submitted':
      return WithdrawalStatus.processing;
    case 'paid':
      return WithdrawalStatus.paid;
    case 'failed':
      return WithdrawalStatus.failed;
    case 'cancelled':
    case 'canceled':
      return WithdrawalStatus.cancelled;
    case 'held':
    case 'on_hold':
    case 'review':
    case 'under_review':
    case 'review_required':
      return WithdrawalStatus.held;
    default:
      return WithdrawalStatus.unknown;
  }
}

/// Fila del historial (`GET .../history`: `id`, `amount_cents`, `currency`,
/// `status`, `created_at`).
class WithdrawalRecord {
  const WithdrawalRecord({
    required this.id,
    required this.amountCents,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.destinationLabel,
  });

  factory WithdrawalRecord.fromJson(Map<String, dynamic> json) {
    final amount = _intValue(json['amount_cents']);
    final created = DateTime.tryParse((json['created_at'] ?? '').toString());
    final id = (json['id'] ?? '').toString().trim();
    if (amount == null || created == null || id.isEmpty) {
      throw const FormatException('Retiro incompleto.');
    }
    final currency = (json['currency'] ?? '').toString().trim();
    return WithdrawalRecord(
      id: id,
      amountCents: amount,
      currency: currency.isEmpty ? 'mxn' : currency.toLowerCase(),
      status: withdrawalStatusFromBackend((json['status'] ?? '').toString()),
      createdAt: created.toLocal(),
    );
  }

  final String id;
  final int amountCents;
  final String currency;
  final WithdrawalStatus status;
  final DateTime createdAt;

  /// Destino ya enmascarado por backend (p. ej. «BBVA ···· 1234»), si existe.
  final String? destinationLabel;
}

/// Acuse de recepción de una solicitud. Equivale a `202 Accepted`: la
/// solicitud fue recibida, NO depositada.
class WithdrawalReceipt {
  const WithdrawalReceipt({
    required this.id,
    required this.amountCents,
    required this.currency,
    required this.receivedAt,
  });

  final String id;
  final int amountCents;
  final String currency;
  final DateTime receivedAt;

  /// Una solicitud recién recibida siempre está «Solicitada».
  WithdrawalStatus get status => WithdrawalStatus.requested;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// `$1,284.50 MXN` a partir de centavos, sin pasar por `double`.
String moneyCents(int cents, {String currency = 'mxn'}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = money(abs ~/ 100, cents: false);
  final fraction = (abs % 100).toString().padLeft(2, '0');
  final code = currency.trim().isEmpty ? 'MXN' : currency.trim().toUpperCase();
  return '${negative ? '-' : ''}$whole.$fraction $code';
}

/// Convierte lo escrito por el usuario a centavos sin errores de redondeo.
/// Acepta «1500», «1500.5», «1500,50» y «$ 1,500.50». Devuelve `null` si no
/// es un importe válido (más de 2 decimales, vacío o demasiado grande).
int? parseAmountCents(String raw) {
  var clean = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (clean.isEmpty) return null;
  // «1,500.50»: la coma es separador de miles si después hay un punto.
  if (clean.contains('.') && clean.contains(',')) {
    clean = clean.replaceAll(',', '');
  } else {
    clean = clean.replaceAll(',', '.');
  }
  final parts = clean.split('.');
  if (parts.length > 2) return null;
  final whole = parts[0].isEmpty ? '0' : parts[0];
  final fraction = parts.length == 2 ? parts[1] : '';
  if (fraction.length > 2 || whole.length > 9) return null;
  final pesos = int.tryParse(whole);
  final cents = int.tryParse(fraction.padRight(2, '0'));
  if (pesos == null || cents == null) return null;
  return pesos * 100 + cents;
}
