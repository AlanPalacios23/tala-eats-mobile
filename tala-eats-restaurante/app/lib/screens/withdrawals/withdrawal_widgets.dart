import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/withdrawal.dart';
import '../../state/withdrawal_state.dart';
import '../../widgets/buttons.dart';

// ---------------------------------------------------------------------------
// Textos compartidos
// ---------------------------------------------------------------------------

const String kBalanceUnavailableTitle = 'Saldo no disponible';
const String kBalanceUnavailableDetail = 'Pendiente de habilitación';
const String kTransfersDisabledTitle = 'Retiros no habilitados';
const String kTransfersDisabledMessage =
    'Puedes revisar cómo funcionará el retiro, pero en esta versión la app '
    'no envía solicitudes ni mueve dinero.';

/// «9 oct 2026, 14:05»
String withdrawalDateLabel(DateTime date) =>
    '${shortDate(date)} ${date.year}, ${clockTime(date)}';

String bankStatusLabel(BankAccountStatus status) {
  switch (status) {
    case BankAccountStatus.notLinked:
      return 'No vinculada';
    case BankAccountStatus.pendingVerification:
      return 'Verificación pendiente';
    case BankAccountStatus.verified:
      return 'Verificada';
    case BankAccountStatus.restricted:
      return 'Bloqueada / en revisión';
    case BankAccountStatus.unavailable:
      return 'Estado no disponible';
  }
}

class BlockerCopy {
  const BlockerCopy(this.title, this.detail);
  final String title;
  final String detail;
}

BlockerCopy blockerCopy(WithdrawalBlocker blocker) {
  switch (blocker) {
    case WithdrawalBlocker.transfersDisabled:
      return const BlockerCopy(
        'Retiros en preparación',
        'Esta versión de la app no envía retiros.',
      );
    case WithdrawalBlocker.serviceNotConnected:
      return const BlockerCopy(
        'Servicio de retiros pendiente',
        'Tala Eats aún no conecta tu cuenta con el servicio de pagos.',
      );
    case WithdrawalBlocker.balanceUnavailable:
      return const BlockerCopy(
        kBalanceUnavailableTitle,
        'Solo mostramos un saldo cuando Tala Eats lo confirma.',
      );
    case WithdrawalBlocker.noFunds:
      return const BlockerCopy(
        'Sin saldo para retirar',
        'Cuando tengas saldo liberado podrás solicitarlo aquí.',
      );
    case WithdrawalBlocker.fundsOnHold:
      return const BlockerCopy(
        'Fondos pendientes de liberación',
        'Tus ventas recientes aún están en periodo de liberación.',
      );
    case WithdrawalBlocker.reconciling:
      return const BlockerCopy(
        'Conciliando movimientos',
        'Espera a que Tala Eats termine de conciliar tus ventas.',
      );
    case WithdrawalBlocker.bankNotLinked:
      return const BlockerCopy(
        'Cuenta bancaria no vinculada',
        'Vincúlala en el registro seguro de Stripe.',
      );
    case WithdrawalBlocker.bankPending:
      return const BlockerCopy(
        'Cuenta en verificación',
        'Stripe está revisando los datos de tu cuenta.',
      );
    case WithdrawalBlocker.bankRestricted:
      return const BlockerCopy(
        'Cuenta bloqueada o en revisión',
        'Contacta a soporte de Tala Eats para revisarla.',
      );
    case WithdrawalBlocker.bankUnavailable:
      return const BlockerCopy(
        'Estado de cuenta no disponible',
        'No pudimos confirmar tu cuenta bancaria.',
      );
    case WithdrawalBlocker.serverNotAllowed:
      return const BlockerCopy(
        'Retiros no autorizados',
        'Tala Eats todavía no autoriza retiros para tu restaurante.',
      );
  }
}

String? amountIssueMessage(
  WithdrawalAmountIssue? issue,
  WithdrawalOverview overview,
) {
  final limits = overview.limits;
  final currency = overview.balance?.currency ?? 'mxn';
  switch (issue) {
    case null:
    case WithdrawalAmountIssue.empty:
      return null;
    case WithdrawalAmountIssue.invalid:
      return 'Escribe un importe válido, por ejemplo 1500.50.';
    case WithdrawalAmountIssue.cannotValidate:
      return 'No podemos validar este importe hasta que Tala Eats confirme '
          'tu saldo disponible.';
    case WithdrawalAmountIssue.belowMinimum:
      final minimum = limits.minimumCents;
      return minimum == null
          ? 'El importe es menor al mínimo permitido.'
          : 'El mínimo por retiro es '
              '${moneyCents(minimum, currency: currency)}.';
    case WithdrawalAmountIssue.exceedsBalance:
      return 'El importe supera tu saldo disponible para retirar.';
    case WithdrawalAmountIssue.exceedsPerRequestLimit:
      final perRequest = limits.perRequestCents;
      return perRequest == null
          ? 'El importe supera el límite por retiro.'
          : 'El límite por retiro es '
              '${moneyCents(perRequest, currency: currency)}.';
    case WithdrawalAmountIssue.exceedsDailyLimit:
      final dailyRemaining = limits.dailyRemainingCents;
      return dailyRemaining == null
          ? 'El importe supera tu límite diario.'
          : 'Hoy puedes retirar hasta '
              '${moneyCents(dailyRemaining, currency: currency)}.';
  }
}

// ---------------------------------------------------------------------------
// Estado de un retiro
// ---------------------------------------------------------------------------

class WithdrawalStatusVisual {
  const WithdrawalStatusVisual(
    this.label,
    this.icon,
    this.foreground,
    this.tint,
  );

  final String label;
  final IconData icon;
  final Color foreground;
  final Color tint;

  static WithdrawalStatusVisual of(WithdrawalStatus status) {
    switch (status) {
      case WithdrawalStatus.requested:
        return const WithdrawalStatusVisual(
          'Solicitado',
          Icons.schedule_rounded,
          AppColors.inkSoft,
          AppColors.sunken,
        );
      case WithdrawalStatus.processing:
        return const WithdrawalStatusVisual(
          'En proceso',
          Icons.sync_rounded,
          AppColors.amber,
          AppColors.amberTint,
        );
      case WithdrawalStatus.paid:
        return const WithdrawalStatusVisual(
          'Pagado',
          Icons.check_circle_outline_rounded,
          AppColors.green,
          AppColors.greenTint,
        );
      case WithdrawalStatus.failed:
        return const WithdrawalStatusVisual(
          'Fallido',
          Icons.error_outline_rounded,
          AppColors.red,
          AppColors.redTint,
        );
      case WithdrawalStatus.cancelled:
        return const WithdrawalStatusVisual(
          'Cancelado',
          Icons.block_rounded,
          AppColors.inkSoft,
          AppColors.sunken,
        );
      case WithdrawalStatus.held:
        return const WithdrawalStatusVisual(
          'Retenido / en revisión',
          Icons.pause_circle_outline_rounded,
          AppColors.amber,
          AppColors.amberTint,
        );
      case WithdrawalStatus.unknown:
        return const WithdrawalStatusVisual(
          'Por confirmar',
          Icons.help_outline_rounded,
          AppColors.inkSoft,
          AppColors.sunken,
        );
    }
  }
}

/// Insignia de estado: ícono + texto + tinte (nunca solo color).
class WithdrawalStatusBadge extends StatelessWidget {
  const WithdrawalStatusBadge({super.key, required this.status});

  final WithdrawalStatus status;

  @override
  Widget build(BuildContext context) {
    final visual = WithdrawalStatusVisual.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: visual.tint,
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(visual.icon, size: 14, color: visual.foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              visual.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(
                fontSize: 12.5,
                color: visual.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila del historial: fecha, importe, destino enmascarado y estado.
class WithdrawalRecordRow extends StatelessWidget {
  const WithdrawalRecordRow({super.key, required this.record});

  final WithdrawalRecord record;

  @override
  Widget build(BuildContext context) {
    final visual = WithdrawalStatusVisual.of(record.status);
    final amount = moneyCents(record.amountCents, currency: record.currency);
    final destination = record.destinationLabel;
    return Semantics(
      container: true,
      label: 'Retiro de $amount, ${visual.label}, '
          '${withdrawalDateLabel(record.createdAt)}'
          '${destination == null ? '' : ', hacia $destination'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    amount,
                    style: AppText.subtitle.copyWith(
                      fontSize: 15.5,
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    destination == null
                        ? withdrawalDateLabel(record.createdAt)
                        : '${withdrawalDateLabel(record.createdAt)} · '
                            '$destination',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(child: WithdrawalStatusBadge(status: record.status)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cuenta bancaria
// ---------------------------------------------------------------------------

class _BankVisual {
  const _BankVisual(this.icon, this.foreground, this.tint, this.message);
  final IconData icon;
  final Color foreground;
  final Color tint;
  final String message;
}

_BankVisual _bankVisual(BankAccountStatus status) {
  switch (status) {
    case BankAccountStatus.notLinked:
      return const _BankVisual(
        Icons.account_balance_outlined,
        AppColors.inkSoft,
        AppColors.sunken,
        'Para recibir retiros vincularás tu cuenta en el registro seguro de '
            'Stripe. Tala Eats no te pedirá tu CLABE en la app ni la guarda.',
      );
    case BankAccountStatus.pendingVerification:
      return const _BankVisual(
        Icons.hourglass_bottom_rounded,
        AppColors.amber,
        AppColors.amberTint,
        'Stripe está verificando tus datos. Te avisaremos cuando la cuenta '
            'quede lista para recibir retiros.',
      );
    case BankAccountStatus.verified:
      return const _BankVisual(
        Icons.verified_user_outlined,
        AppColors.green,
        AppColors.greenTint,
        'Tus retiros se enviarán a esta cuenta.',
      );
    case BankAccountStatus.restricted:
      return const _BankVisual(
        Icons.block_rounded,
        AppColors.red,
        AppColors.redTint,
        'La cuenta necesita revisión antes de recibir retiros. Actualiza tus '
            'datos en el registro seguro o contacta a soporte.',
      );
    case BankAccountStatus.unavailable:
      return const _BankVisual(
        Icons.help_outline_rounded,
        AppColors.inkSoft,
        AppColors.sunken,
        'No pudimos consultar el estado de tu cuenta. Intenta más tarde.',
      );
  }
}

/// Estado de la cuenta bancaria con su acción. Solo muestra la cuenta
/// enmascarada cuando backend la confirmó como verificada.
class BankAccountPanel extends StatelessWidget {
  const BankAccountPanel({
    super.key,
    required this.bank,
    required this.onConfigure,
    this.busy = false,
  });

  final BankAccountSummary bank;
  final VoidCallback onConfigure;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final visual = _bankVisual(bank.status);
    final masked = bank.maskedLabel;
    final verified = bank.status == BankAccountStatus.verified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          container: true,
          label: 'Cuenta bancaria: ${bankStatusLabel(bank.status)}'
              '${masked == null ? '' : ', $masked'}',
          excludeSemantics: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: visual.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(visual.icon, size: 21, color: visual.foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      masked ?? 'Cuenta bancaria',
                      style: AppText.subtitle.copyWith(
                        fontSize: 15.5,
                        fontFeatures: AppFonts.tabular,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bankStatusLabel(bank.status),
                      style: AppText.label.copyWith(
                        fontSize: 13,
                        color: visual.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(visual.message, style: AppText.caption.copyWith(fontSize: 13.5)),
        if (!verified) ...<Widget>[
          const SizedBox(height: 14),
          AppButton(
            key: const ValueKey<String>('withdrawals-configure-bank'),
            label: bank.status == BankAccountStatus.notLinked
                ? 'Configurar cuenta bancaria'
                : 'Revisar cuenta bancaria',
            icon: Icons.open_in_new_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.compact,
            loading: busy,
            loadingLabel: 'Abriendo…',
            onPressed: onConfigure,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Lista de requisitos
// ---------------------------------------------------------------------------

/// Requisito con marca de cumplido/pendiente (ícono + texto, no solo color).
class RequirementRow extends StatelessWidget {
  const RequirementRow({
    super.key,
    required this.title,
    required this.detail,
    required this.met,
  });

  final String title;
  final String detail;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title: ${met ? 'cumplido' : 'pendiente'}. $detail',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                met
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: met ? AppColors.green : AppColors.inkFaint,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppText.label.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(detail, style: AppText.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Viñeta de texto informativo (reglas de negocio solo como texto).
class InfoBullet extends StatelessWidget {
  const InfoBullet(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 8, right: 10),
            decoration: const BoxDecoration(
              color: AppColors.inkFaint,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(text, style: AppText.caption.copyWith(fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}
