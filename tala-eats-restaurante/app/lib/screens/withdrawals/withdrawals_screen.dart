import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/failures.dart';
import '../../data/withdrawal_gateway.dart';
import '../../models/withdrawal.dart';
import '../../state/operations_controller.dart' show LoadStatus;
import '../../state/withdrawal_state.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/motion.dart';
import '../../widgets/states.dart';
import '../../widgets/surfaces.dart';
import 'new_withdrawal_screen.dart';
import 'withdrawal_history_screen.dart';
import 'withdrawal_widgets.dart';

/// Abre una URL efímera y autorizada emitida por backend (por ejemplo, con
/// `url_launcher`). Esta versión no incluye ninguna implementación: sin
/// opener, la app explica el registro bancario en lugar de abrir enlaces.
typedef WithdrawalLinkOpener = Future<bool> Function(Uri uri);

/// Pantalla A — «Mis retiros». Primera entrada desde Finanzas.
///
/// Muestra por separado: disponible para retirar, en proceso, cuenta bancaria
/// e historial. Sin saldo confirmado por el servicio de retiros nunca muestra
/// un importe.
class WithdrawalsScreen extends StatefulWidget {
  const WithdrawalsScreen({super.key, required this.gateway, this.openLink});

  final WithdrawalGateway gateway;
  final WithdrawalLinkOpener? openLink;

  @override
  State<WithdrawalsScreen> createState() => _WithdrawalsScreenState();
}

class _WithdrawalsScreenState extends State<WithdrawalsScreen>
    with WidgetsBindingObserver {
  bool _awaitingStripeReturn = false;
  late final WithdrawalController _controller =
      WithdrawalController(widget.gateway);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  // Chrome/Stripe is external. The callback page never grants banking rights:
  // always re-read the authenticated server state when Android resumes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingStripeReturn && mounted) {
      _awaitingStripeReturn = false;
      _controller.load();
    }
  }

  void _openNew() {
    Navigator.of(context).push<void>(
      appRoute<void>(NewWithdrawalScreen(controller: _controller)),
    );
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      appRoute<void>(WithdrawalHistoryScreen(controller: _controller)),
    );
  }

  Future<void> _configureBank() async {
    // Any bank onboarding or management link is a sensitive operation.
    // The server independently validates and consumes this TOTP.
    final totp = await _bankStepUpDialog();
    if (!mounted || totp == null) return;
    // Bank registration is independent of the payout execution switch.
    // Never turn a backend 403/409/503 into a misleading "not enabled" sheet.
    Uri? uri;
    try {
      uri = await _controller.bankOnboardingLink(totp: totp);
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailure.from(error);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey<String>('bank-onboarding-error'),
          title: Text(failure.title),
          content: Text(failure.message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    final opener = widget.openLink ??
        (Uri link) => launchUrl(link, mode: LaunchMode.externalApplication);
    if (uri != null) {
      bool opened;
      _awaitingStripeReturn = true;
      try {
        opened = await opener(uri);
      } catch (_) {
        opened = false;
      }
      if (!opened) _awaitingStripeReturn = false;
      if (!mounted) return;
      if (!opened) {
        showAppSnack(
          context,
          'No pudimos abrir el registro bancario. Intenta de nuevo.',
          tone: AlertTone.danger,
        );
      }
      if (opened) {
        showAppSnack(context, 'Al regresar de Stripe, revisaremos de nuevo tu banco. Si no cambia, desliza para actualizar.');
      }
      return;
    }
    await showBankOnboardingInfo(context);
  }

  /// Only for an already verified Stripe Express account. Never persist TOTP.
  Future<String?> _bankStepUpDialog() => showDialog<String>(
        context: context,
        builder: (dialogContext) => const _BankStepUpDialog(),
      );

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
        title: const Text('Mis retiros'),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return RefreshIndicator(
              color: AppColors.ink,
              onRefresh: _controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.sm,
                  AppSpace.gutter,
                  AppSpace.xxxl,
                ),
                children: <Widget>[
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _sections(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _sections() {
    final c = _controller;
    final overviewFailed = c.overviewStatus == LoadStatus.failure;
    final overviewLoading = c.overview == null && !overviewFailed;
    final overview = c.effectiveOverview;
    final bank = overviewFailed
        ? const BankAccountSummary(status: BankAccountStatus.unavailable)
        : overview.bank;

    return <Widget>[
      if (!c.transfersEnabled) ...<Widget>[
        const InlineAlert(
          key: ValueKey<String>('withdrawals-disabled-notice'),
          title: 'Registro bancario y retiros son distintos',
          message: 'Puedes registrar tu banco con Stripe Connect ahora. '
              'Enviar ganancias al banco sigue bloqueado hasta que '
              'Tala Eats confirme fondos y autorice los retiros.',
          tone: AlertTone.info,
          icon: Icons.account_balance_outlined,
        ),
        const SizedBox(height: AppSpace.md),
        if (!overviewLoading && bank.status != BankAccountStatus.verified) ...<Widget>[
          AppButton(
            key: const ValueKey<String>('connect-register-now'),
            label: 'Vincular banco con Stripe',
            icon: Icons.open_in_new_rounded,
            variant: AppButtonVariant.primary,
            loading: c.openingBankLink,
            onPressed: _configureBank,
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ],
      _BalanceCard(
        overview: overview,
        loading: overviewLoading,
        failed: overviewFailed,
        onRetry: c.loadOverview,
      ),
      const SizedBox(height: AppSpace.md),
      AppButton(
        key: const ValueKey<String>('withdrawals-open-new'),
        label: 'Retirar ganancias',
        icon: c.canRequest
            ? Icons.arrow_forward_rounded
            : Icons.lock_outline_rounded,
        variant: c.canRequest
            ? AppButtonVariant.primary
            : AppButtonVariant.secondary,
        onPressed: _openNew,
      ),
      if (!c.canRequest) ...<Widget>[
        const SizedBox(height: AppSpace.sm),
        Text(
          c.transfersEnabled
              ? 'Revisa los requisitos pendientes antes de solicitar.'
              : 'Bloqueado hasta habilitar retiros. Toca para ver los requisitos.',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ],
      const SectionHeader('Cuenta bancaria'),
      SurfaceCard(
        child: overviewLoading
            ? const _LoadingLine('Consultando tu cuenta…')
            : BankAccountPanel(
                bank: bank,
                busy: c.openingBankLink,
                onConfigure: _configureBank,
              ),
      ),
      SectionHeader(
        'Historial de retiros',
        trailing: SectionLink(
          key: const ValueKey<String>('withdrawals-open-history'),
          label: 'Ver todo',
          onTap: _openHistory,
        ),
      ),
      _HistoryPreview(controller: c),
      const SectionHeader('Cómo funcionan los retiros'),
      const SurfaceCard(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InfoBullet('Comisión Tala Eats: 15% sobre productos vendidos.'),
            InfoBullet(
              'Solo verás saldo disponible cuando Tala Eats lo confirme. El '
              'ingreso de un periodo no equivale a saldo retirable.',
            ),
            InfoBullet(
              'Los pedidos cobrados en efectivo no forman parte del saldo '
              'retirable.',
            ),
            InfoBullet(
              'Reembolsos y disputas no se incluyen en el saldo disponible.',
            ),
            InfoBullet(
              'Los límites por retiro y por día los define Tala Eats y se '
              'muestran antes de confirmar.',
            ),
            InfoBullet(
              'Cada retiro se confirma con tu código de verificación en dos '
              'pasos.',
            ),
            InfoBullet(
              'Una solicitud recibida no significa que el dinero ya llegó: '
              'verás «Pagado» solo cuando se confirme el depósito.',
            ),
          ],
        ),
      ),
    ];
  }
}

/// El controlador pertenece al ciclo de vida del propio diálogo. El Future
/// showDialog finaliza antes de terminar la animación de salida: no debemos
/// hacer dispose desde el método que lo espera.
class _BankStepUpDialog extends StatefulWidget {
  const _BankStepUpDialog();

  @override
  State<_BankStepUpDialog> createState() => _BankStepUpDialogState();
}

class _BankStepUpDialogState extends State<_BankStepUpDialog> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.clear();
    _code.dispose();
    super.dispose();
  }

  void _continue() {
    final value = _code.text.trim();
    if (RegExp(r'^\d{6}$').hasMatch(value)) {
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Verifica tu identidad'),
        content: TextField(
          key: const ValueKey<String>('bank-onboarding-totp'),
          controller: _code,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Código de 6 dígitos',
            helperText: 'Necesario para administrar tu banco en Stripe.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(onPressed: _continue, child: const Text('Continuar')),
        ],
      );
}

/// Saldo: disponible para retirar y en proceso, por separado.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.overview,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final WithdrawalOverview overview;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final balance = overview.hasVerifiedBalance ? overview.balance : null;
    final String headline;
    final String detail;
    if (loading) {
      headline = 'Consultando saldo…';
      detail = 'Un momento.';
    } else if (failed) {
      headline = kBalanceUnavailableTitle;
      detail = 'No pudimos consultar tu saldo.';
    } else if (balance == null) {
      headline = kBalanceUnavailableTitle;
      detail = kBalanceUnavailableDetail;
    } else {
      headline = moneyCents(
        balance.withdrawableCents,
        currency: balance.currency,
      );
      final hold = balance.holdDays;
      detail = hold != null && hold > 0
          ? 'Tus ventas se liberan después de ${hold == 1 ? '1 día' : '$hold días'}.'
          : 'Confirmado por Tala Eats.';
    }
    final inProcess = balance == null
        ? 'No disponible'
        : moneyCents(balance.alreadyRequestedCents, currency: balance.currency);

    return Semantics(
      container: true,
      child: Container(
        key: const ValueKey<String>('withdrawals-balance-card'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          gradient: AppGradients.ink,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Disponible para retirar',
              style: AppText.caption.copyWith(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (balance != null && !loading)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SwapText(
                  headline,
                  style: AppText.figure.copyWith(
                    color: Colors.white,
                    fontSize: 36,
                  ),
                ),
              )
            else
              Text(
                headline,
                style: AppText.headline.copyWith(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: AppText.caption.copyWith(color: Colors.white70),
            ),
            if (failed) ...<Widget>[
              const SizedBox(height: 4),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                  textStyle: AppText.label.copyWith(fontSize: 14),
                ),
                child: const Text('Reintentar'),
              ),
            ],
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'En proceso',
                    style: AppText.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    inProcess,
                    textAlign: TextAlign.right,
                    style: AppText.label.copyWith(
                      color: Colors.white,
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Últimos movimientos del historial con estados honestos.
class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({required this.controller});

  final WithdrawalController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.historyStatus == LoadStatus.failure && c.historyFailure != null) {
      return SurfaceCard(
        child: StateView.failure(
          c.historyFailure!,
          onRetry: c.loadHistory,
          compact: true,
        ),
      );
    }
    if (c.historyStatus != LoadStatus.ready) {
      return const SurfaceCard(child: _LoadingLine('Cargando historial…'));
    }
    if (!c.gateway.isConnected) {
      return const SurfaceCard(
        child: StateView(
          compact: true,
          icon: Icons.history_rounded,
          title: 'Historial pendiente de habilitación',
          message: 'Tus retiros aparecerán aquí cuando los retiros estén '
              'disponibles.',
        ),
      );
    }
    if (c.history.isEmpty) {
      return const SurfaceCard(
        child: StateView(
          compact: true,
          icon: Icons.receipt_long_outlined,
          title: 'Aún no tienes retiros',
          message: 'Cada solicitud aparecerá aquí con su estado.',
        ),
      );
    }
    final visible = c.history.take(3).toList(growable: false);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < visible.length; i++) ...<Widget>[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            WithdrawalRecordRow(record: visible[i]),
          ],
        ],
      ),
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: AppText.bodySoft),
      ),
    );
  }
}

/// Explica el registro bancario alojado mientras no exista un enlace
/// autorizado por backend. La app no captura datos bancarios.
Future<void> showBankOnboardingInfo(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Registro bancario seguro',
            style: AppText.title.copyWith(fontSize: 21),
          ),
          const SizedBox(height: 10),
          const Text(
            'Puedes registrar tu cuenta bancaria con Stripe Connect antes de '
            'que estén disponibles los retiros. El registro requiere '
            'la verificación 2FA y autorización del servidor. '
            'Si Stripe no envía un enlace, vuelve a intentarlo o consulta soporte.',
            style: AppText.bodySoft,
          ),
          const SizedBox(height: 12),
          const InfoBullet(
            'La app no te pide tu CLABE ni guarda números de cuenta.',
          ),
          const InfoBullet(
            'Al terminar verás aquí el estado de tu cuenta: verificación '
            'pendiente, verificada o en revisión.',
          ),
          const InfoBullet('El registro bancario no habilita por sí solo retiros de dinero.'),
          const SizedBox(height: 20),
          AppButton(
            key: const ValueKey<String>('bank-info-close'),
            label: 'Entendido',
            variant: AppButtonVariant.dark,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}
