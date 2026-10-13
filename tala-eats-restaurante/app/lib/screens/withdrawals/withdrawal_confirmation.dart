import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/withdrawal.dart';
import '../../state/withdrawal_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/fields.dart';
import 'withdrawal_widgets.dart';

/// Paso 2FA del retiro (preparado para cuando backend lo autorice).
///
/// El código solo vive en el campo mientras la hoja está abierta: se envía al
/// servidor a través de [onConfirm], no se valida localmente (solo formato de
/// 6 dígitos), no se guarda y se borra al fallar o cerrar.
Future<WithdrawalReceipt?> showWithdrawalTwoFactorSheet(
  BuildContext context, {
  required String amountLabel,
  required String destinationLabel,
  required Future<WithdrawalSubmitOutcome> Function(String code) onConfirm,
}) {
  return showModalBottomSheet<WithdrawalReceipt>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => WithdrawalTwoFactorSheet(
      amountLabel: amountLabel,
      destinationLabel: destinationLabel,
      onConfirm: onConfirm,
    ),
  );
}

class WithdrawalTwoFactorSheet extends StatefulWidget {
  const WithdrawalTwoFactorSheet({
    super.key,
    required this.amountLabel,
    required this.destinationLabel,
    required this.onConfirm,
  });

  final String amountLabel;
  final String destinationLabel;
  final Future<WithdrawalSubmitOutcome> Function(String code) onConfirm;

  @override
  State<WithdrawalTwoFactorSheet> createState() =>
      _WithdrawalTwoFactorSheetState();
}

class _WithdrawalTwoFactorSheetState extends State<WithdrawalTwoFactorSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.clear();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _error = 'Escribe los 6 dígitos de tu autenticador.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await widget.onConfirm(code);
    if (!mounted) return;
    switch (outcome.kind) {
      case WithdrawalSubmitKind.received:
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(outcome.receipt);
        break;
      case WithdrawalSubmitKind.ignored:
        // Ya había un envío en curso: no se duplicó la solicitud.
        setState(() => _busy = false);
        break;
      case WithdrawalSubmitKind.blocked:
        _code.clear();
        setState(() {
          _busy = false;
          _error = 'Los retiros no están habilitados. No se envió ninguna '
              'solicitud.';
        });
        break;
      case WithdrawalSubmitKind.failed:
        _code.clear();
        setState(() {
          _busy = false;
          _error = outcome.failure?.message ??
              'No pudimos enviar la solicitud. Intenta de nuevo.';
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Confirma con tu código',
              style: AppText.title.copyWith(fontSize: 21),
            ),
            const SizedBox(height: 8),
            Text(
              'Vas a solicitar ${widget.amountLabel} hacia '
              '${widget.destinationLabel}.',
              style: AppText.bodySoft,
            ),
            const SizedBox(height: 20),
            AppField(
              fieldKey: const ValueKey<String>('withdrawal-otp-field'),
              controller: _code,
              label: 'Código de verificación',
              hint: '000000',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enabled: !_busy,
              autofillHints: const <String>[AutofillHints.oneTimeCode],
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 12),
              InlineAlert(
                key: const ValueKey<String>('withdrawal-otp-error'),
                title: error,
              ),
            ],
            const SizedBox(height: 20),
            AppButton(
              key: const ValueKey<String>('withdrawal-otp-confirm'),
              label: 'Confirmar solicitud',
              loadingLabel: 'Enviando…',
              loading: _busy,
              variant: AppButtonVariant.dark,
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: 12),
            const Text(
              'Tu código se envía directo a Tala Eats para validarlo. La app no '
              'lo guarda.',
              textAlign: TextAlign.center,
              style: AppText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

/// Acuse de una solicitud recibida. Distingue claramente «solicitud
/// recibida» de «dinero depositado».
class WithdrawalReceiptScreen extends StatelessWidget {
  const WithdrawalReceiptScreen({
    super.key,
    required this.receipt,
    required this.destinationLabel,
  });

  final WithdrawalReceipt receipt;
  final String destinationLabel;

  @override
  Widget build(BuildContext context) {
    final amount = moneyCents(receipt.amountCents, currency: receipt.currency);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Solicitud recibida'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.lg,
                AppSpace.gutter,
                AppSpace.xxl,
              ),
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.sunken,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      size: 30,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: const Text(
                    'Recibimos tu solicitud',
                    style: AppText.headline,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Solicitaste $amount hacia $destinationLabel el '
                  '${withdrawalDateLabel(receipt.receivedAt)}.',
                  style: AppText.bodySoft,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: WithdrawalStatusBadge(status: receipt.status),
                ),
                const SizedBox(height: 20),
                const InlineAlert(
                  title: 'Aún no es un depósito',
                  message: 'El dinero todavía no está en tu cuenta. Verás '
                      '«Pagado» en tu historial solo cuando se confirme el '
                      'depósito.',
                  tone: AlertTone.info,
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: 'Listo',
                  variant: AppButtonVariant.dark,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
