import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../state/session_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import '../widgets/fields.dart';
import '../widgets/surfaces.dart';

class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final _code = TextEditingController();
  String? _codeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.session.loadTwoFactorSetup();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final value = _code.text.trim();
    if (value.length != 6) {
      setState(() => _codeError = 'Escribe los 6 dígitos de tu autenticador.');
      return;
    }
    if (_codeError != null) setState(() => _codeError = null);
    await widget.session.confirmTwoFactor(value);
  }

  /// Clave en bloques de 4 para copiarla a mano sin errores.
  static String _grouped(String secret) {
    final clean = secret.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  Future<void> _copySecret(String secret) async {
    await Clipboard.setData(ClipboardData(text: secret.replaceAll(' ', '')));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showAppSnack(
      context,
      'Clave copiada. Pégala en tu app autenticadora.',
      tone: AlertTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.gutter),
              children: <Widget>[
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: _ShieldBadge(),
                ),
                const SizedBox(height: 20),
                const Text('Protege tu restaurante', style: AppText.display),
                const SizedBox(height: 10),
                const Text(
                  'Antes de operar, Tala Eats requiere verificación en dos pasos para cuentas de restaurante.',
                  style: AppText.bodySoft,
                ),
                const SizedBox(height: 24),
                if (widget.session.securityLoading && widget.session.twoFactorSetup == null)
                  const SurfaceCard(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (widget.session.twoFactorSetup != null)
                  SurfaceCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text('1. Agrega Tala Eats a tu autenticador', style: AppText.subtitle),
                        const SizedBox(height: 8),
                        const Text(
                          'Abre Google Authenticator, Microsoft Authenticator o una app TOTP y agrega esta clave:',
                          style: AppText.bodySoft,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          decoration: BoxDecoration(
                            color: AppColors.sunken,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: SelectableText(
                                  _grouped(widget.session.twoFactorSetup!.secret),
                                  style: AppText.title.copyWith(
                                    fontFeatures: AppFonts.tabular,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const ValueKey<String>('copyTwoFactorSecret'),
                                tooltip: 'Copiar clave',
                                onPressed: () => _copySecret(
                                  widget.session.twoFactorSetup!.secret,
                                ),
                                icon: const Icon(Icons.copy_rounded),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text('2. Confirma el código', style: AppText.subtitle),
                        const SizedBox(height: 12),
                        AppField(
                          controller: _code,
                          label: 'Código de 6 dígitos',
                          hint: '000000',
                          helper: _codeError == null
                              ? 'Lo muestra tu app autenticadora y cambia cada 30 segundos.'
                              : null,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          autofillHints: const <String>[AutofillHints.oneTimeCode],
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (_) {
                            if (_codeError != null) setState(() => _codeError = null);
                          },
                          onSubmitted: (_) => _confirm(),
                        ),
                        if (_codeError != null) ...<Widget>[
                          const SizedBox(height: 10),
                          InlineAlert(title: _codeError!),
                        ],
                      ],
                    ),
                  ),
                if (widget.session.securityFailure != null) ...<Widget>[
                  const SizedBox(height: 18),
                  InlineAlert.failure(widget.session.securityFailure!),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: 'Activar seguridad y continuar',
                  loadingLabel: 'Verificando…',
                  loading: widget.session.securityLoading && widget.session.twoFactorSetup != null,
                  onPressed: widget.session.twoFactorSetup == null ? null : _confirm,
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Cerrar sesión',
                  variant: AppButtonVariant.ghost,
                  onPressed: widget.session.securityLoading ? null : () => widget.session.signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Distintivo de seguridad (sustituye al logotipo para una pantalla limpia).
class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 64,
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.brandTint,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.shield_outlined,
              color: AppColors.brandText,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}
