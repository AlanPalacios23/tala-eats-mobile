part of '../main.dart';

// ---------------------------------------------------------------------------
// Auth: login, registro, verificación, recuperación y cambio de contraseña.
// Same flows and model calls as v1.0.8; only layout, rhythm and feedback.
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.model});

  final TalaModel model;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  bool hidePassword = true;
  bool loading = false;
  String error = '';

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading) return;
    FocusScope.of(context).unfocus();
    final String address = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
      setState(() => error = 'Escribe un correo electrónico válido.');
      return;
    }
    if (password.text.isEmpty) {
      setState(() => error = 'Escribe tu contraseña.');
      return;
    }
    setState(() {
      loading = true;
      error = '';
    });
    final bool ok = await widget.model.login(address, password.text);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    final String message = widget.model.blockedRole.isNotEmpty
        ? 'Esta cuenta pertenece a otra aplicación de Tala Eats.'
        : (widget.model.lastError.isNotEmpty
            ? widget.model.lastError
            : 'Revisa tu correo y contraseña e inténtalo de nuevo.');
    // The customer login has no OTP field. Never suppress backend MFA
    // requirements: affected legacy accounts need a secure support recovery.
    final String safeMessage = RegExp(r'(2fa|otp|autenticador)', caseSensitive: false)
            .hasMatch(message)
        ? 'Tu cuenta requiere verificación adicional. Comunícate con soporte para recuperar el acceso.'
        : message;
    setState(() {
      loading = false;
      error = safeMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumAuthScaffold(
      title: 'Bienvenido de vuelta',
      subtitle: 'Tu comida favorita, más cerca.',
      showFoodImage: true,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.alternate_email_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: hidePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              onSubmitted: (_) { if (!loading) submit(); },
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  onPressed: () => setState(() => hidePassword = !hidePassword),
                  icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(premiumRoute(ForgotPasswordScreen(model: widget.model))),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
            AnimatedSize(
              duration: TalaMotion.of(context, TalaMotion.select),
              curve: TalaMotion.ease,
              child: error.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AuthNotice(key: ValueKey<String>(error), icon: Icons.error_outline_rounded, text: error, danger: true),
                    ),
            ),
            FilledButton(
              onPressed: loading ? null : submit,
              child: BusyLabel(busy: loading, label: 'Iniciar sesión'),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              runSpacing: 0,
              children: <Widget>[
                const Text('¿Aún no tienes cuenta?', style: TextStyle(color: Color(0xFF171717), fontWeight: FontWeight.w800, fontSize: 13)),
                TextButton(
                  onPressed: () => Navigator.of(context).push(premiumRoute(SignUpScreen(model: widget.model))),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LegalLoginNotice(model: widget.model),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.model});

  final TalaModel model;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController name = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirm = TextEditingController();
  bool hidePassword = true;
  bool hideConfirm = true;
  bool accepted = false;
  String error = '';

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  bool get hasLength => password.text.length >= 8;
  bool get hasUpper => RegExp(r'[A-Z]').hasMatch(password.text);
  bool get hasLower => RegExp(r'[a-z]').hasMatch(password.text);
  bool get hasNumber => RegExp(r'[0-9]').hasMatch(password.text);
  bool get passwordStrong => hasLength && hasUpper && hasLower && hasNumber;

  void submit() {
    FocusScope.of(context).unfocus();
    String next = '';
    if (name.text.trim().length < 2) {
      next = 'Escribe tu nombre.';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim())) {
      next = 'Escribe un correo válido.';
    } else if (!passwordStrong) {
      next = 'Tu contraseña todavía no cumple los requisitos.';
    } else if (password.text != confirm.text) {
      next = 'Las contraseñas no coinciden.';
    } else if (!accepted) {
      next = 'Acepta los términos y el aviso de privacidad.';
    }
    if (next.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => error = next);
      return;
    }
    setState(() => error = '');
    Navigator.of(context).push(
      premiumRoute(
        VerifyAccountScreen(
          model: widget.model,
          name: name.text.trim(),
          email: email.text.trim(),
          password: password.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumAuthScaffold(
      showBack: true,
      title: 'Crea tu cuenta',
      showSecondaryImage: true,
      subtitle: 'Un minuto y quedas listo para pedir en Tala Eats.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.alternate_email_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: hidePassword,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Crea una contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => hidePassword = !hidePassword),
                icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 10),
          PasswordRequirements(hasLength: hasLength, hasUpper: hasUpper, hasLower: hasLower, hasNumber: hasNumber),
          const SizedBox(height: 12),
          TextField(
            controller: confirm,
            obscureText: hideConfirm,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => submit(),
            decoration: InputDecoration(
              labelText: 'Confirma tu contraseña',
              prefixIcon: const Icon(Icons.verified_user_outlined),
              suffixIcon: IconButton(
                tooltip: hideConfirm ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => hideConfirm = !hideConfirm),
                icon: Icon(hideConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              value: accepted,
              onChanged: (bool? value) {
                HapticFeedback.selectionClick();
                setState(() => accepted = value ?? false);
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              visualDensity: VisualDensity.compact,
              title: const Text('Acepto los Términos y el Aviso de privacidad.', style: TextStyle(fontSize: 13, height: 1.35, color: kInkSoft)),
            ),
          ),
          Wrap(
            spacing: 4,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).push(premiumRoute(const TermsAndConditionsScreen())),
                child: const Text('Leer términos'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(premiumRoute(PrivacyNoticeScreen(supportEmail: widget.model.supportEmail))),
                child: const Text('Leer aviso de privacidad'),
              ),
            ],
          ),
          AnimatedSize(
            duration: TalaMotion.of(context, TalaMotion.select),
            curve: TalaMotion.ease,
            child: error.isEmpty
                ? const SizedBox(width: double.infinity, height: 8)
                : Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 14),
                    child: AuthNotice(key: ValueKey<String>(error), icon: Icons.info_outline_rounded, text: error, danger: true),
                  ),
          ),
          FilledButton(onPressed: submit, child: const Text('Continuar')),
          const SizedBox(height: 14),
          const QuietNote(icon: Icons.shield_outlined, text: 'Nunca compartas tu contraseña. Tala Eats no te la pedirá por mensaje.'),
        ],
      ),
    );
  }
}

class VerifyAccountScreen extends StatefulWidget {
  const VerifyAccountScreen({super.key, required this.model, required this.name, required this.email, required this.password});

  final TalaModel model;
  final String name;
  final String email;
  final String password;

  @override
  State<VerifyAccountScreen> createState() => _VerifyAccountScreenState();
}

class _VerifyAccountScreenState extends State<VerifyAccountScreen> {
  bool loading = false;
  String error = '';

  Future<void> createAccount() async {
    setState(() {
      loading = true;
      error = '';
    });
    final bool ok = await widget.model.registerCustomer(widget.name, widget.email, widget.password);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        loading = false;
        error = widget.model.lastError.isEmpty ? 'No pudimos crear la cuenta.' : widget.model.lastError;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumAuthScaffold(
      showBack: true,
      title: 'Confirma tus datos',
      showSecondaryImage: true,
      subtitle: 'Revisa que tu correo sea correcto. Lo usarás para entrar y recuperar tu cuenta.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TalaCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: kSoftOrange, shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, color: kBrand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.title),
                      const SizedBox(height: 2),
                      Text(widget.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.muted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            AuthNotice(icon: Icons.error_outline_rounded, text: error, danger: true),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: loading ? null : createAccount, child: BusyLabel(busy: loading, label: 'Crear cuenta y entrar')),
          const SizedBox(height: 8),
          TextButton(onPressed: loading ? null : () => Navigator.of(context).maybePop(), child: const Text('Editar datos')),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.model});

  final TalaModel model;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController email = TextEditingController();
  String error = '';
  bool loading = false;
  bool sent = false;

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading) return;
    FocusScope.of(context).unfocus();
    final String address = email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
      setState(() => error = 'Escribe un correo electrónico válido.');
      return;
    }
    setState(() {
      loading = true;
      error = '';
    });
    final bool ok = await widget.model.requestPasswordReset(address);
    if (!mounted) return;
    if (ok) HapticFeedback.lightImpact();
    setState(() {
      loading = false;
      sent = ok;
      error = ok ? '' : (widget.model.lastError.isEmpty ? 'Escribe un correo válido.' : widget.model.lastError);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumAuthScaffold(
      showBack: true,
      title: sent ? 'Revisa tu correo' : 'Recupera tu contraseña',
      showSecondaryImage: true,
      subtitle: sent
          ? 'Recibimos tu solicitud. Si la cuenta existe y el servicio de correo está disponible, recibirás un enlace seguro.'
          : 'Solicita un enlace seguro para crear una nueva contraseña.',
      child: AnimatedSwitcher(
        duration: TalaMotion.of(context, TalaMotion.reveal),
        child: sent
            ? Column(
                key: const ValueKey<String>('sent'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(child: SuccessOrb(icon: Icons.mark_email_read_rounded)),
                  const SizedBox(height: 22),
                  const QuietNote(icon: Icons.info_outline_rounded, text: 'Si no lo ves en unos minutos, revisa las carpetas de spam o promociones.'),
                  const SizedBox(height: 18),
                  OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver al inicio de sesión')),
                ],
              )
            : Column(
                key: const ValueKey<String>('form'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.email],
                    autocorrect: false,
                    onSubmitted: (_) {
                      if (!loading) submit();
                    },
                    decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.alternate_email_rounded)),
                  ),
                  if (error.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    AuthNotice(icon: Icons.error_outline_rounded, text: error, danger: true),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(onPressed: loading ? null : submit, child: BusyLabel(busy: loading, label: 'Enviar enlace')),
                ],
              ),
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.model, required this.resetToken});

  final TalaModel model;
  final String resetToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController password = TextEditingController();
  final TextEditingController confirm = TextEditingController();
  bool hidePassword = true;
  bool hideConfirm = true;
  bool loading = false;
  String error = '';

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  bool get hasLength => password.text.length >= 8;
  bool get hasUpper => RegExp(r'[A-Z]').hasMatch(password.text);
  bool get hasLower => RegExp(r'[a-z]').hasMatch(password.text);
  bool get hasNumber => RegExp(r'[0-9]').hasMatch(password.text);
  bool get passwordStrong => hasLength && hasUpper && hasLower && hasNumber;

  Future<void> submit() async {
    if (!passwordStrong) {
      setState(() => error = 'La nueva contraseña todavía no cumple los requisitos.');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = 'Las contraseñas no coinciden.');
      return;
    }
    setState(() {
      loading = true;
      error = '';
    });
    final bool ok = await widget.model.resetPassword(widget.resetToken, password.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        loading = false;
        error = widget.model.lastError;
      });
      return;
    }
    widget.model.pendingResetToken = '';
    Navigator.of(context).pushReplacement(premiumRoute(const PasswordUpdatedScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return PremiumAuthScaffold(
      title: 'Crea una nueva contraseña',
      showSecondaryImage: true,
      subtitle: 'Elige una contraseña segura que no uses en otros servicios.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: password,
            obscureText: hidePassword,
            onChanged: (_) => setState(() {}),
            autofillHints: const <String>[AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: const Icon(Icons.lock_reset_rounded),
              suffixIcon: IconButton(
                tooltip: hidePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => hidePassword = !hidePassword),
                icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          const SizedBox(height: 10),
          PasswordRequirements(hasLength: hasLength, hasUpper: hasUpper, hasLower: hasLower, hasNumber: hasNumber),
          const SizedBox(height: 12),
          TextField(
            controller: confirm,
            obscureText: hideConfirm,
            onSubmitted: (_) {
              if (!loading) submit();
            },
            decoration: InputDecoration(
              labelText: 'Confirma la nueva contraseña',
              prefixIcon: const Icon(Icons.verified_user_outlined),
              suffixIcon: IconButton(
                tooltip: hideConfirm ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => hideConfirm = !hideConfirm),
                icon: Icon(hideConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          if (error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            AuthNotice(icon: Icons.error_outline_rounded, text: error, danger: true),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: loading ? null : submit, child: BusyLabel(busy: loading, label: 'Actualizar contraseña')),
        ],
      ),
    );
  }
}

class PasswordUpdatedScreen extends StatelessWidget {
  const PasswordUpdatedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumAuthScaffold(
      title: 'Contraseña actualizada',
      showSecondaryImage: true,
      subtitle: 'Ya puedes iniciar sesión con tu nueva contraseña.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Center(child: SuccessOrb(icon: Icons.lock_open_rounded)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst),
            child: const Text('Volver a iniciar sesión'),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.model});

  final TalaModel model;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  bool loading = false;
  String error = '';
  bool sent = false;

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = '';
    });
    final bool ok = await widget.model.requestPasswordReset(widget.model.userEmail);
    if (!mounted) return;
    if (ok) HapticFeedback.lightImpact();
    setState(() {
      loading = false;
      sent = ok;
      error = ok ? '' : widget.model.lastError;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumAuthScaffold(
      showBack: true,
      showSecondaryImage: true,
      title: 'Cambiar contraseña',
      subtitle: 'Te enviaremos un enlace seguro a tu correo para definir una nueva contraseña.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TalaCard(
            child: Row(
              children: <Widget>[
                const Icon(Icons.alternate_email_rounded, color: kBrand),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.model.userEmail, style: TalaText.title)),
              ],
            ),
          ),
          if (error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            AuthNotice(icon: Icons.error_outline_rounded, text: error, danger: true),
          ],
          if (sent) ...<Widget>[
            const SizedBox(height: 12),
            const AuthNotice(
              icon: Icons.mark_email_read_rounded,
              text: 'Listo. Revisa tu correo y abre el enlace para crear la nueva contraseña.',
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: loading ? null : submit,
            child: BusyLabel(busy: loading, label: sent ? 'Reenviar enlace' : 'Enviar enlace seguro'),
          ),
        ],
      ),
    );
  }
}

/// Premium auth layout: vivid photo hero + one clean solid form surface.
/// The photo remains original; a local dark gradient only protects white hero
/// typography. All forms share identical spacing, keyboard and reading rules.
class PremiumAuthScaffold extends StatelessWidget {
  const PremiumAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.eyebrow = '',
    this.showBack = false,
    this.showFoodImage = false,
    this.showSecondaryImage = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  final bool showFoodImage;
  final bool showSecondaryImage;

  @override
  Widget build(BuildContext context) {
    final String? background = showFoodImage
        ? 'assets/branding/login_food.png'
        : showSecondaryImage
            ? 'assets/branding/auth_secondary.jpg'
            : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          if (background != null)
            Positioned.fill(
              child: Image.asset(
                background,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                semanticLabel: 'Fotografía de comida de Tala Eats',
              ),
            )
          else
            const Positioned.fill(child: AuthBackdrop()),
          // Keep the same hero scrim behind Android's status-bar inset.
          // The hero's gradient below starts at this exact opacity; without
          // this strip a bright band appears above both auth photographs.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: const ColoredBox(
              key: ValueKey<String>('auth-status-bar-scrim'),
              color: Color(0x59000000),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints area) {
                final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
                final double heroHeight = keyboardOpen
                    ? 110
                    : math.min(238.0, math.max(158.0, area.maxHeight * 0.29));
                return SingleChildScrollView(
                  key: const ValueKey<String>('auth-scroll'),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: area.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          height: heroHeight,
                          child: Stack(
                            children: <Widget>[
                              // Gradient stays in the hero, not over the photo
                              // behind the entire viewport or form.
                              const Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: <Color>[
                                        Color(0x59000000),
                                        Color(0x96000000),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (showBack)
                                Positioned(
                                  top: 12,
                                  left: 20,
                                  child: TalaCircleButton(
                                    icon: Icons.arrow_back_rounded,
                                    tooltip: 'Regresar',
                                    onPressed: () => Navigator.of(context).maybePop(),
                                  ),
                                ),
                              Positioned(
                                left: 24,
                                right: 24,
                                bottom: keyboardOpen ? 12 : 25,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 460),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        if (eyebrow.isNotEmpty) ...<Widget>[
                                          Text(eyebrow,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              letterSpacing: 1.1,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        Text(
                                          title,
                                          key: const ValueKey<String>('auth-hero-title'),
                                          style: TextStyle(
                                            fontSize: keyboardOpen ? 24 : 32,
                                            height: 1.08,
                                            letterSpacing: -0.7,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (!keyboardOpen) ...<Widget>[
                                          const SizedBox(height: 7),
                                          Text(subtitle,
                                            style: const TextStyle(
                                              color: Color(0xFFF7F7F7),
                                              fontSize: 14,
                                              height: 1.4,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          key: const ValueKey<String>('auth-surface'),
                          constraints: BoxConstraints(
                            minHeight: math.max(0.0, area.maxHeight - heroHeight),
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 27, 24, 30),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(28),
                              topRight: Radius.circular(28),
                            ),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  inputDecorationTheme: Theme.of(context)
                                      .inputDecorationTheme.copyWith(
                                    fillColor: const Color(0xFFF7F7F7),
                                    labelStyle: const TextStyle(
                                      color: Color(0xFF393939),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    floatingLabelStyle: const TextStyle(
                                      color: Color(0xFFAB3308),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    prefixIconColor: const Color(0xFF616161),
                                    suffixIconColor: const Color(0xFF616161),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFE1E1E1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: kBrandDeep, width: 1.8),
                                    ),
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF9D2B00),
                                      textStyle: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w700,
                                      ),
                                      minimumSize: const Size(44, 42),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                  ),
                                ),
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Static warm backdrop (no looping motion).
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFFFF4EC), Color(0xFFFFFAF6), kBackground],
          stops: <double>[0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(right: -120, top: -140, child: _GlowOrb(size: 320, color: Color(0x1FFF5A1F))),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: <Color>[color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TalaLogoMark(size: 36),
        SizedBox(width: 10),
        Text('Tala Eats', style: TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
      ],
    );
  }
}

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key, required this.hasLength, required this.hasUpper, required this.hasLower, required this.hasNumber});

  final bool hasLength;
  final bool hasUpper;
  final bool hasLower;
  final bool hasNumber;

  @override
  Widget build(BuildContext context) {
    final int score = <bool>[hasLength, hasUpper, hasLower, hasNumber].where((bool item) => item).length;
    final String label = score == 0 ? 'Requisitos' : (score <= 1 ? 'Débil' : (score <= 3 ? 'Casi lista' : 'Segura'));
    final Color tone = score == 4 ? kGreen : (score == 0 ? kMuted : kBrand);
    final Duration d = TalaMotion.of(context, const Duration(milliseconds: 240));
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Seguridad de la contraseña',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: d,
                  style: TextStyle(fontSize: 12, color: tone, fontWeight: FontWeight.w800),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List<Widget>.generate(4, (int index) {
              return Expanded(
                child: AnimatedContainer(
                  duration: d,
                  curve: TalaMotion.ease,
                  height: 4,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 5),
                  decoration: BoxDecoration(color: index < score ? tone : kSunken, borderRadius: BorderRadius.circular(99)),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              PasswordRule(ok: hasLength, label: '8+ caracteres'),
              PasswordRule(ok: hasUpper, label: 'Mayúscula'),
              PasswordRule(ok: hasLower, label: 'Minúscula'),
              PasswordRule(ok: hasNumber, label: 'Número'),
            ],
          ),
        ],
      ),
    );
  }
}

class PasswordRule extends StatelessWidget {
  const PasswordRule({super.key, required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TalaMotion.of(context, TalaMotion.select),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: ok ? kSoftGreen : kSunken, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(ok ? Icons.check_rounded : Icons.circle_outlined, size: 13, color: ok ? kGreen : kSubtle),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: ok ? kGreen : kMuted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Short, elegant success emphasis (no elastic bounce, no looping).
class SuccessOrb extends StatelessWidget {
  const SuccessOrb({super.key, required this.icon, this.color = kGreen, this.soft = kSoftGreen});

  final IconData icon;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final Duration d = TalaMotion.of(context, TalaMotion.success);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: d,
      builder: (BuildContext context, double t, Widget? child) {
        final double scale = 0.72 + 0.28 * Curves.easeOutBack.transform(t.clamp(0.0, 1.0).toDouble());
        final double ring = Curves.easeOutCubic.transform(t);
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Opacity(
                opacity: (1 - ring) * 0.6,
                child: Container(
                  width: 92 + 28 * ring,
                  height: 92 + 28 * ring,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.5), width: 2)),
                ),
              ),
              Transform.scale(scale: scale, child: child),
            ],
          ),
        );
      },
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 42),
      ),
    );
  }
}

/// Discreet, clickable legal links; no translucent cards or fake buttons.
class LegalLoginNotice extends StatelessWidget {
  const LegalLoginNotice({super.key, required this.model});
  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Text(
          'Al iniciar sesión aceptas los Términos y Condiciones y reconoces el Aviso de Privacidad.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF757575), fontSize: 11, height: 1.5),
        ),
        const SizedBox(height: 2),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).push(
                premiumRoute(const TermsAndConditionsScreen())),
              child: const Text('Términos y Condiciones'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                premiumRoute(PrivacyNoticeScreen(supportEmail: model.supportEmail))),
              child: const Text('Aviso de Privacidad'),
            ),
          ],
        ),
      ],
    );
  }
}
