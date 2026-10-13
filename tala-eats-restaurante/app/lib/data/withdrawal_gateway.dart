// Contrato de retiros: backend 1.6.3 HOTFIX3 + location patch.
// La app NUNCA hace Stripe payouts directamente.
import '../core/failures.dart';
import '../models/withdrawal.dart';

/// Interruptor de esta release. Con `false`, ningún flujo de la app puede
/// enviar una solicitud de retiro, aunque un gateway futuro lo permita.
/// Cambiarlo requiere backend desplegado, pruebas y aprobación explícita.
const bool kWithdrawalTransfersEnabled = bool.fromEnvironment(
  'TALA_EATS_WITHDRAWAL_REQUEST_UI_ENABLED', defaultValue: false,
);

/// Fuente de datos de Retiros. Las implementaciones traducen errores técnicos
/// a [AppFailure] y nunca inventan importes.
abstract class WithdrawalGateway {
  const WithdrawalGateway();

  /// `true` solo cuando existe un servicio real de retiros conectado.
  bool get isConnected;

  /// Vincular al restaurante verificado antes de consultar o enviar retiros.
  WithdrawalGateway forRecipient(int recipientId) => this;

  /// Saldo, cuenta bancaria y límites dictados por el servidor.
  Future<WithdrawalOverview> fetchOverview();

  /// Historial de solicitudes, más recientes primero.
  Future<List<WithdrawalRecord>> fetchHistory();

  /// URL efímera del onboarding bancario alojado (Stripe Connect) emitida por
  /// backend. `null` si todavía no está disponible.
  /// v1.6.4 exige TOTP reciente incluso en la primera alta.
  Future<bool> bankAccessRequiresTotp() async => false;
  Future<Uri?> createBankOnboardingLink({String? totp});

  /// Envía una solicitud. El [totp] se reenvía tal cual al servidor: la app no
  /// lo valida, no lo guarda ni lo registra. Reutilizar el mismo
  /// [idempotencyKey] al reintentar la misma solicitud.
  Future<WithdrawalReceipt> requestWithdrawal({
    required int amountCents,
    required String totp,
    required String idempotencyKey,
  });
}

/// Implementación de esta versión: no hay servicio de retiros conectado.
/// No realiza llamadas de red ni guarda datos.
class DisconnectedWithdrawalGateway extends WithdrawalGateway {
  const DisconnectedWithdrawalGateway();

  @override
  bool get isConnected => false;

  @override
  Future<WithdrawalOverview> fetchOverview() async =>
      const WithdrawalOverview.notConnected();

  @override
  Future<List<WithdrawalRecord>> fetchHistory() async =>
      const <WithdrawalRecord>[];

  @override
  Future<Uri?> createBankOnboardingLink({String? totp}) async => null;

  @override
  Future<WithdrawalReceipt> requestWithdrawal({
    required int amountCents,
    required String totp,
    required String idempotencyKey,
  }) async =>
      throw const AppFailure(
        FailureKind.permissionDenied,
        'Los retiros aún no están habilitados. No se realizó ningún movimiento de dinero.',
      );
}
