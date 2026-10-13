import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/failures.dart';
import '../core/theme.dart';
import '../state/session_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import '../widgets/fields.dart';
import '../widgets/surfaces.dart';
import 'onboarding/onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session, this.showBack = false});

  final SessionController session;

  /// `true` cuando se abre desde la bienvenida (ruta apilada).
  final bool showBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _passwordFocus = FocusNode();
  final _otpFocus = FocusNode();
  bool _loading = false;
  bool _submitted = false;
  bool _needsOtp = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    _passwordFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _failure = null;
    });
    final failure = await widget.session.signIn(
      _email.text,
      _password.text,
      otp: _needsOtp ? _otp.text : '',
    );
    if (!mounted) return;
    if (failure != null) {
      if (failure.kind == FailureKind.twoFactorRequired) {
        HapticFeedback.selectionClick();
        setState(() {
          _loading = false;
          _needsOtp = true;
          _failure = failure;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _otpFocus.requestFocus());
        return;
      }
      HapticFeedback.heavyImpact();
      setState(() {
        _loading = false;
        _failure = failure;
      });
      return;
    }
    TextInput.finishAutofillContext();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openOnboarding() {
    Navigator.of(context).push<void>(
      appRoute<void>(OnboardingScreen(session: widget.session)),
    );
  }

  void _clearFailure(String _) {
    if (_failure != null) setState(() => _failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: widget.showBack
          ? AppBar(
              leading: IconButton(
                tooltip: 'Volver',
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            )
          : null,
      body: SafeArea(
        top: !widget.showBack,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: AutofillGroup(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    widget.showBack ? AppSpace.sm : 40,
                    AppSpace.gutter,
                    AppSpace.xxl,
                  ),
                  children: <Widget>[
                    if (!widget.showBack) ...<Widget>[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BrandLockup(),
                      ),
                      const SizedBox(height: 40),
                    ],
                    Semantics(
                      header: true,
                      child: const Text(
                        'Bienvenido de vuelta',
                        style: AppText.display,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Entra para atender pedidos, cocina y menú de tu restaurante.',
                      style: AppText.bodySoft,
                    ),
                    const SizedBox(height: 28),
                    AppField(
                      fieldKey: const ValueKey<String>('loginEmail'),
                      controller: _email,
                      label: 'Correo',
                      hint: 'nombre@correo.com',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const <String>[
                        AutofillHints.email,
                        AutofillHints.username,
                      ],
                      autocorrect: false,
                      prefixIcon: Icons.mail_outline_rounded,
                      validator: Validators.email,
                      onChanged: (value) {
                        _clearFailure(value);
                        if (_needsOtp) setState(() => _needsOtp = false);
                      },
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                    ),
                    const SizedBox(height: 18),
                    PasswordField(
                      fieldKey: const ValueKey<String>('loginPassword'),
                      controller: _password,
                      focusNode: _passwordFocus,
                      onChanged: (value) {
                        _clearFailure(value);
                        if (_needsOtp) setState(() => _needsOtp = false);
                      },
                      validator: (value) => (value ?? '').isEmpty
                          ? 'Escribe tu contraseña.'
                          : null,
                      onSubmitted: (_) => _needsOtp ? _otpFocus.requestFocus() : _submit(),
                    ),
                    AnimatedSize(
                      duration: Motion.of(context, Motion.base),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: !_needsOtp
                          ? const SizedBox(width: double.infinity, height: 0)
                          : Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: AppField(
                                fieldKey: const ValueKey<String>('loginOtp'),
                                controller: _otp,
                                focusNode: _otpFocus,
                                label: 'Código de verificación',
                                hint: '000000',
                                helper: 'Escribe el código de 6 dígitos de tu autenticador.',
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: (value) => !_needsOtp
                                    ? null
                                    : (value ?? '').trim().length == 6
                                        ? null
                                        : 'Escribe los 6 dígitos.',
                                onChanged: _clearFailure,
                                onSubmitted: (_) => _submit(),
                              ),
                            ),
                    ),
                    AnimatedSize(
                      duration: Motion.of(context, Motion.base),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: failure == null
                          ? const SizedBox(width: double.infinity, height: 0)
                          : Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: InlineAlert.failure(failure),
                            ),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      key: const ValueKey<String>('loginSubmitButton'),
                      label: _needsOtp ? 'Verificar e iniciar sesión' : 'Iniciar sesión',
                      loadingLabel: _needsOtp ? 'Verificando…' : 'Entrando…',
                      loading: _loading,
                      size: AppButtonSize.large,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 28),
                    const Divider(),
                    const SizedBox(height: 20),
                    Text(
                      '¿Tu restaurante aún no está en Tala Eats?',
                      textAlign: TextAlign.center,
                      style: AppText.caption.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      key: const ValueKey<String>('createRestaurantAccountButton'),
                      label: 'Crear mi restaurante',
                      variant: AppButtonVariant.secondary,
                      onPressed: _loading ? null : _openOnboarding,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
