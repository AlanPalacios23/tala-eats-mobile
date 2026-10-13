import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/withdrawal.dart';
import '../../state/operations_controller.dart' show LoadStatus;
import '../../state/withdrawal_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/fields.dart';
import '../../widgets/surfaces.dart';
import 'withdrawal_confirmation.dart';
import 'withdrawal_widgets.dart';

/// Requisitos que se muestran aparte de los tres fijos (habilitación, saldo y
/// cuenta bancaria).
const Set<WithdrawalBlocker> _extraBlockers = <WithdrawalBlocker>{
  WithdrawalBlocker.noFunds,
  WithdrawalBlocker.fundsOnHold,
  WithdrawalBlocker.reconciling,
  WithdrawalBlocker.serverNotAllowed,
};

/// Pantalla B — «Nuevo retiro».
///
/// En v0.5.11 se puede recorrer para conocer el proceso, pero el botón final
/// permanece deshabilitado («Retiros no habilitados»): no se envía ninguna
/// solicitud ni se mueve dinero.
class NewWithdrawalScreen extends StatefulWidget {
  const NewWithdrawalScreen({super.key, required this.controller});

  final WithdrawalController controller;

  @override
  State<NewWithdrawalScreen> createState() => _NewWithdrawalScreenState();
}

class _NewWithdrawalScreenState extends State<NewWithdrawalScreen> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _confirm(int amountCents) async {
    final c = widget.controller;
    if (!c.canRequest || c.submitting) return;
    final overview = c.effectiveOverview;
    final currency = overview.balance?.currency ?? 'mxn';
    final destination =
        overview.bank.maskedLabel ?? 'tu cuenta bancaria verificada';
    final receipt = await showWithdrawalTwoFactorSheet(
      context,
      amountLabel: moneyCents(amountCents, currency: currency),
      destinationLabel: destination,
      onConfirm: (code) => c.submit(amountCents: amountCents, totp: code),
    );
    if (!mounted) return;
    if (receipt == null) return;
    _amount.clear();
    c.load();
    Navigator.of(context).pushReplacement(
      appRoute<void>(
        WithdrawalReceiptScreen(
          receipt: receipt,
          destinationLabel: destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Nuevo retiro'),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final c = widget.controller;
    final overview = c.effectiveOverview;
    final loading = c.overview == null && c.overviewStatus != LoadStatus.failure;
    final balance = overview.hasVerifiedBalance ? overview.balance : null;
    final currency = balance?.currency ?? 'mxn';
    final blockers = c.blockers;
    final raw = _amount.text;
    final issue = validateWithdrawalAmount(raw, overview);
    final issueText = amountIssueMessage(issue, overview);
    final amountCents = parseAmountCents(raw) ?? 0;
    final canContinue = c.canRequest && issue == null && amountCents > 0;
    final masked = overview.bank.maskedLabel;
    final servicesReady = c.transfersEnabled &&
        overview.isConnected &&
        overview.serverAllowsRequests;
    final extras = blockers.where(_extraBlockers.contains).toList();

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.sm,
              AppSpace.gutter,
              AppSpace.xxl,
            ),
            children: <Widget>[
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (!c.transfersEnabled) ...<Widget>[
                        const InlineAlert(
                          key: ValueKey<String>('withdrawal-disabled-banner'),
                          title: 'Vista previa: no se mueve dinero',
                          message: kTransfersDisabledMessage,
                          tone: AlertTone.warning,
                          icon: Icons.lock_outline_rounded,
                        ),
                        const SizedBox(height: AppSpace.lg),
                      ],
                      _AvailableLine(
                        loading: loading,
                        balance: balance,
                      ),
                      const SizedBox(height: AppSpace.xl),
                      AppField(
                        fieldKey:
                            const ValueKey<String>('withdrawal-amount-field'),
                        controller: _amount,
                        label: 'Importe a retirar',
                        hint: '0.00',
                        prefixText: r'$ ',
                        helper: 'En pesos mexicanos (MXN). Usa punto para '
                            'centavos.',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                          LengthLimitingTextInputFormatter(12),
                        ],
                        onChanged: (_) {
                          c.resetDraft();
                          setState(() {});
                        },
                      ),
                      if (issueText != null) ...<Widget>[
                        const SizedBox(height: 10),
                        _IssueLine(
                          text: issueText,
                          warning: issue == WithdrawalAmountIssue.cannotValidate,
                        ),
                      ],
                      const SectionHeader('Antes de retirar'),
                      SurfaceCard(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            RequirementRow(
                              title: 'Retiros habilitados',
                              detail: servicesReady
                                  ? 'Tala Eats autorizó retiros para tu '
                                      'restaurante.'
                                  : 'Próximamente. Esta versión no envía '
                                      'retiros.',
                              met: servicesReady,
                            ),
                            RequirementRow(
                              title: 'Saldo confirmado por Tala Eats',
                              detail: balance == null
                                  ? '$kBalanceUnavailableTitle · '
                                      '${kBalanceUnavailableDetail.toLowerCase()}.'
                                  : 'Disponible: ${moneyCents(balance.withdrawableCents, currency: currency)}.',
                              met: balance != null,
                            ),
                            RequirementRow(
                              title: 'Cuenta bancaria verificada',
                              detail:
                                  masked ?? bankStatusLabel(overview.bank.status),
                              met: overview.bank.status ==
                                  BankAccountStatus.verified,
                            ),
                            for (final blocker in extras)
                              RequirementRow(
                                title: blockerCopy(blocker).title,
                                detail: blockerCopy(blocker).detail,
                                met: false,
                              ),
                          ],
                        ),
                      ),
                      if (amountCents > 0) ...<Widget>[
                        const SectionHeader('Resumen'),
                        _Summary(
                          amount: moneyCents(amountCents, currency: currency),
                          destination: masked,
                        ),
                      ],
                      const SizedBox(height: AppSpace.lg),
                      const InfoBullet(
                        'Al confirmar te pediremos el código de 6 dígitos de '
                        'tu autenticador.',
                      ),
                      const InfoBullet(
                        'El tiempo de llegada lo confirma el banco; la app no '
                        'lo estima.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _BottomBar(
          transfersEnabled: c.transfersEnabled,
          submitting: c.submitting,
          onPressed: canContinue ? () => _confirm(amountCents) : null,
        ),
      ],
    );
  }
}

class _AvailableLine extends StatelessWidget {
  const _AvailableLine({required this.loading, required this.balance});

  final bool loading;
  final WithdrawalBalance? balance;

  @override
  Widget build(BuildContext context) {
    final value = balance;
    final String title;
    final String detail;
    if (loading) {
      title = 'Consultando saldo…';
      detail = 'Un momento.';
    } else if (value == null) {
      title = kBalanceUnavailableTitle;
      detail = kBalanceUnavailableDetail;
    } else {
      title = moneyCents(value.withdrawableCents, currency: value.currency);
      detail = 'Confirmado por Tala Eats';
    }
    return Semantics(
      container: true,
      label: 'Disponible para retirar: $title. $detail.',
      excludeSemantics: true,
      child: SurfaceCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.sunken,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 21,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Disponible para retirar', style: AppText.caption),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: AppText.subtitle.copyWith(
                      fontSize: 17,
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
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

class _IssueLine extends StatelessWidget {
  const _IssueLine({required this.text, required this.warning});

  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.amber : AppColors.red;
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey<String>('withdrawal-amount-issue'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              warning ? Icons.info_outline_rounded : Icons.error_outline_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppText.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.amount, required this.destination});

  final String amount;

  /// Cuenta enmascarada solo si backend la verificó.
  final String? destination;

  @override
  Widget build(BuildContext context) {
    final target = destination ?? 'tu cuenta bancaria (pendiente de verificar)';
    return Semantics(
      container: true,
      label: 'Vas a solicitar $amount hacia $target.',
      excludeSemantics: true,
      child: SurfaceCard(
        key: const ValueKey<String>('withdrawal-summary'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Vas a solicitar', style: AppText.caption),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(amount, style: AppText.figure),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.account_balance_outlined,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'hacia $target',
                    style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Recibir la solicitud no significa que el dinero ya fue '
              'depositado.',
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.transfersEnabled,
    required this.submitting,
    required this.onPressed,
  });

  final bool transfersEnabled;
  final bool submitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Con el teclado abierto se oculta la nota para no tapar el formulario.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.md,
          AppSpace.gutter,
          AppSpace.md,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppButton(
                  key: const ValueKey<String>('withdrawal-submit'),
                  label: transfersEnabled
                      ? 'Continuar'
                      : kTransfersDisabledTitle,
                  icon: transfersEnabled
                      ? Icons.arrow_forward_rounded
                      : Icons.lock_outline_rounded,
                  loading: submitting,
                  loadingLabel: 'Enviando…',
                  size: AppButtonSize.large,
                  onPressed: onPressed,
                ),
                if (!keyboardOpen) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    transfersEnabled
                        ? 'Revisa el resumen antes de continuar.'
                        : 'Se habilitará cuando Tala Eats conecte los retiros '
                            'con Stripe. No se envió ninguna solicitud.',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
