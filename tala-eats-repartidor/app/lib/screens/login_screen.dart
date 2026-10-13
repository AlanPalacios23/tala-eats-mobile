import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final DriverController controller;

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

  bool _obscure = true;
  bool _submitted = false;
  bool _authFailed = false;
  bool _recovering = false;
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    _email.addListener(_onInput);
    _password.addListener(_onInput);
    _otp.addListener(_onInput);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _otp.dispose();
    _passwordFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _onInput() {
    if (mounted) setState(() => _authFailed = false);
  }

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty &&
      _password.text.isNotEmpty &&
      (!widget.controller.requiresOtp || _otp.text.trim().length == 6) &&
      !widget.controller.authenticating;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      Haptics.warning();
      setState(() => _shake++);
      return;
    }
    final ok = await widget.controller.signIn(
      email: _email.text.trim(),
      password: _password.text,
      otp: _otp.text.trim(),
    );
    if (!mounted || ok) return;
    Haptics.warning();
    setState(() {
      _authFailed = true;
      _shake++;
    });
    if (widget.controller.requiresOtp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocus.requestFocus();
      });
    }
  }

  Future<void> _recover() async {
    final email = _email.text.trim();
    if (!Validators.isEmail(email)) {
      setState(() {
        _submitted = true;
        _shake++;
      });
      Haptics.warning();
      return;
    }
    setState(() => _recovering = true);
    final ok = await widget.controller.requestPasswordRecovery(email);
    if (!mounted) return;
    setState(() => _recovering = false);
    if (!ok) {
      showAppSnack(
        context,
        widget.controller.lastErrorMessage ?? 'No pudimos enviar la solicitud.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    await showAppSheet<void>(
      context: context,
      title: 'Revisa tu correo',
      subtitle: 'Si la cuenta existe, Tala Eats enviará instrucciones de recuperación.',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InlineNotice(
            icon: Icons.security_rounded,
            text: 'Por seguridad, no confirmamos si un correo está registrado.',
          ),
          const SizedBox(height: Space.l),
          OutlinedButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final loading = widget.controller.authenticating;
          final otpRequired = widget.controller.requiresOtp;
          // Pantallas bajas (o teclado abierto en equipos pequeños): se
          // compacta el encabezado para que el formulario quede visible.
          final compact = MediaQuery.sizeOf(context).height < 680 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.25;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(24, compact ? 16 : 28, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _submitted
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Entrance(child: BrandLockup()),
                            SizedBox(height: compact ? Space.xxl : 44),
                            Entrance(
                              delay: const Duration(milliseconds: 50),
                              child: Text(
                                'Entra y empieza tu ruta.',
                                style: TextStyle(
                                  color: kInk,
                                  fontSize: compact ? 27 : 32,
                                  fontWeight: FontWeight.w800,
                                  height: 1.08,
                                  letterSpacing: -.9,
                                ),
                              ),
                            ),
                            const SizedBox(height: Space.s + 2),
                            const Entrance(
                              delay: Duration(milliseconds: 80),
                              child: Text(
                                'Tus entregas, ganancias y recorrido en un solo lugar.',
                                style: AppText.bodyMuted,
                              ),
                            ),
                            SizedBox(height: compact ? Space.xl : Space.xxxl - 4),
                            Entrance(
                              delay: const Duration(milliseconds: 110),
                              child: Shake(
                                trigger: _shake,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      key: const Key('login-email'),
                                      controller: _email,
                                      enabled: !loading,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      textCapitalization: TextCapitalization.none,
                                      validator: Validators.emailError,
                                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                                      decoration: const InputDecoration(
                                        labelText: 'Correo',
                                        prefixIcon: Icon(Icons.mail_outline_rounded),
                                      ),
                                    ),
                                    const SizedBox(height: Space.m),
                                    TextFormField(
                                      key: const Key('login-password'),
                                      controller: _password,
                                      focusNode: _passwordFocus,
                                      enabled: !loading,
                                      obscureText: _obscure,
                                      keyboardType: TextInputType.visiblePassword,
                                      textInputAction: otpRequired ? TextInputAction.next : TextInputAction.done,
                                      autofillHints: const [AutofillHints.password],
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      validator: Validators.passwordError,
                                      onFieldSubmitted: (_) => otpRequired ? _otpFocus.requestFocus() : _submit(),
                                      decoration: InputDecoration(
                                        labelText: 'Contraseña',
                                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                                        suffixIcon: IconButton(
                                          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                                          onPressed: () => setState(() => _obscure = !_obscure),
                                          icon: StateSwitcher(
                                            duration: Motion.micro,
                                            rise: 0,
                                            animateSize: false,
                                            alignment: Alignment.center,
                                            child: Icon(
                                              _obscure
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              key: ValueKey(_obscure),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Reveal(
                                      visible: otpRequired,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: Space.m),
                                        child: TextFormField(
                                          key: const Key('login-otp'),
                                          controller: _otp,
                                          focusNode: _otpFocus,
                                          enabled: !loading,
                                          keyboardType: TextInputType.number,
                                          textInputAction: TextInputAction.done,
                                          inputFormatters: <TextInputFormatter>[
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(6),
                                          ],
                                          validator: otpRequired
                                              ? (value) => (value ?? '').length == 6
                                                  ? null
                                                  : 'Ingresa los 6 dígitos.'
                                              : null,
                                          onFieldSubmitted: (_) => _submit(),
                                          decoration: const InputDecoration(
                                            labelText: 'Código de verificación',
                                            helperText: 'Código de tu autenticador',
                                            prefixIcon: Icon(Icons.phonelink_lock_rounded),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: loading || _recovering ? null : _recover,
                                child: StateSwitcher(
                                  duration: Motion.short,
                                  rise: 0,
                                  animateSize: false,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _recovering
                                        ? 'Enviando…'
                                        : '¿Olvidaste tu contraseña?',
                                    key: ValueKey(_recovering),
                                  ),
                                ),
                              ),
                            ),
                            Reveal(
                              visible: _authFailed,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: Space.m),
                                child: NoticeBanner(
                                  key: const Key('login-error'),
                                  icon: otpRequired
                                      ? Icons.phonelink_lock_rounded
                                      : Icons.error_outline_rounded,
                                  // Pedir el código no es un error: tono de
                                  // marca. Credenciales rechazadas: rojo.
                                  tone: otpRequired ? Tone.brand : Tone.error,
                                  message: widget.controller.lastErrorMessage ??
                                      'No pudimos iniciar sesión. Revisa tus datos.',
                                ),
                              ),
                            ),
                            Entrance(
                              delay: const Duration(milliseconds: 150),
                              child: PrimaryButton(
                                key: const Key('login-submit'),
                                label: otpRequired ? 'Verificar y entrar' : 'Entrar',
                                icon: Icons.arrow_forward_rounded,
                                loading: loading,
                                loadingLabel: 'Entrando…',
                                onPressed: _canSubmit ? _submit : null,
                              ),
                            ),
                            const SizedBox(height: Space.m),
                            OutlinedButton.icon(
                              key: const Key('create-driver-account'),
                              onPressed: loading
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => RegisterDriverScreen(
                                            controller: widget.controller,
                                          ),
                                        ),
                                      ),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('Crear cuenta para repartir'),
                            ),
                            const SizedBox(height: Space.l + 2),
                            const Entrance(
                              delay: Duration(milliseconds: 190),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_outlined, size: 16, color: kMuted),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text('Acceso exclusivo para repartidores', style: AppText.caption),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
