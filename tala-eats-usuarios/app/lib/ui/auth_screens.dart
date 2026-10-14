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
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = '';
    });
    final bool ok = await widget.model.login(email.text, password.text);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      loading = false;
      error = widget.model.blockedRole.isNotEmpty
          ? 'Esta cuenta pertenece a otra aplicación de Tala Eats.'
          : (widget.model.lastError.isNotEmpty ? widget.model.lastError : 'Revisa tu correo y contraseña e inténtalo de nuevo.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return FoodPhotoAuthScaffold(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('login-email'),
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              autocorrect: false,
              style: const TextStyle(color: kInk),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('login-password'),
              controller: password,
              obscureText: hidePassword,
              style: const TextStyle(color: kInk),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) { if (!loading) submit(); },
              autofillHints: const <String>[AutofillHints.password],
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: FoodPhotoAuthScaffold.whiteLink,
                onPressed: () => Navigator.of(context).push(
                  premiumRoute(ForgotPasswordScreen(model: widget.model)),
                ),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
            if (error.isNotEmpty) ...<Widget>[
              AuthNotice(
                icon: Icons.error_outline_rounded,
                text: error,
                danger: true,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: const ValueKey<String>('login-submit'),
              onPressed: loading ? null : submit,
              child: BusyLabel(busy: loading, label: 'Iniciar sesión'),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 0,
              children: <Widget>[
                TextButton(
                  style: FoodPhotoAuthScaffold.whiteLink,
                  onPressed: () => Navigator.of(context).push(
                    premiumRoute(SignUpScreen(model: widget.model)),
                  ),
                  child: const Text('Crear cuenta'),
                ),
                TextButton(
                  style: FoodPhotoAuthScaffold.whiteLink,
                  onPressed: () => Navigator.of(context).push(
                    premiumRoute(const TermsAndConditionsScreen()),
                  ),
                  child: const Text('Términos'),
                ),
                TextButton(
                  style: FoodPhotoAuthScaffold.whiteLink,
                  onPressed: () => Navigator.of(context).push(
                    premiumRoute(PrivacyNoticeScreen(
                      supportEmail: widget.model.supportEmail,
                    )),
                  ),
                  child: const Text('Privacidad'),
                ),
              ],
            ),
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
    } else if (!email.text.trim().contains('@')) {
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
    return FoodPhotoAuthScaffold(
      title: 'Crear cuenta',
      showBack: true,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('signup-name'),
              controller: name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              style: const TextStyle(color: kInk),
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('signup-email'),
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const <String>[AutofillHints.email],
              style: const TextStyle(color: kInk),
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('signup-password'),
              controller: password,
              obscureText: hidePassword,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              style: const TextStyle(color: kInk),
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
            if (password.text.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                passwordStrong
                    ? 'Contraseña segura'
                    : '8 caracteres, mayúscula, minúscula y número',
                style: TextStyle(
                  color: passwordStrong ? const Color(0xFFD3FFE3) : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: const <Shadow>[Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('signup-confirm-password'),
              controller: confirm,
              obscureText: hideConfirm,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              style: const TextStyle(color: kInk),
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                prefixIcon: const Icon(Icons.verified_user_outlined),
                suffixIcon: IconButton(
                  tooltip: hideConfirm ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  onPressed: () => setState(() => hideConfirm = !hideConfirm),
                  icon: Icon(hideConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
            ),
            const SizedBox(height: 7),
            CheckboxListTile(
              key: const ValueKey<String>('signup-legal-accept'),
              value: accepted,
              onChanged: (bool? value) => setState(() => accepted = value ?? false),
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Acepto los Términos y el Aviso de privacidad',
                style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            if (error.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              AuthNotice(icon: Icons.error_outline_rounded, text: error, danger: true),
            ],
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey<String>('signup-submit'),
              onPressed: submit,
              child: const Text('Crear cuenta'),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: <Widget>[
                TextButton(
                  style: FoodPhotoAuthScaffold.whiteLink,
                  onPressed: () => Navigator.of(context).push(
                    premiumRoute(const TermsAndConditionsScreen()),
                  ),
                  child: const Text('Términos'),
                ),
                TextButton(
                  style: FoodPhotoAuthScaffold.whiteLink,
                  onPressed: () => Navigator.of(context).push(
                    premiumRoute(PrivacyNoticeScreen(supportEmail: widget.model.supportEmail)),
                  ),
                  child: const Text('Privacidad'),
                ),
              ],
            ),
          ],
        ),
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
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = '';
    });
    final bool ok = await widget.model.requestPasswordReset(email.text);
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
    return FoodPhotoAuthScaffold(
      showBack: true,
      title: sent ? 'Revisa tu correo' : 'Recuperar contraseña',
      child: AnimatedSwitcher(
        duration: TalaMotion.of(context, TalaMotion.reveal),
        child: sent
            ? Column(
                key: const ValueKey<String>('auth-mail-sent'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Si la cuenta existe, recibirás un enlace para restablecer tu contraseña.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver a iniciar sesión'),
                  ),
                ],
              )
            : Column(
                key: const ValueKey<String>('auth-recover-form'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    key: const ValueKey<String>('recover-email'),
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    autofillHints: const <String>[AutofillHints.email],
                    style: const TextStyle(color: kInk),
                    onSubmitted: (_) { if (!loading) submit(); },
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  if (error.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    AuthNotice(icon: Icons.error_outline_rounded, text: error, danger: true),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    key: const ValueKey<String>('recover-submit'),
                    onPressed: loading ? null : submit,
                    child: BusyLabel(busy: loading, label: 'Enviar enlace'),
                  ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          const Text('Te enviaremos un enlace seguro a tu correo para que definas una nueva contraseña.', style: TalaText.body),
          const SizedBox(height: 18),
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
            const AuthNotice(icon: Icons.mark_email_read_rounded, text: 'Listo. Revisa tu correo y abre el enlace para crear la nueva contraseña.'),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: loading ? null : submit, child: BusyLabel(busy: loading, label: sent ? 'Reenviar enlace' : 'Enviar enlace seguro')),
        ],
      ),
    );
  }
}

/// Shared auth layout: brand lockup, strong title, calm form area.
/// Acceso minimalista: fotografía suministrada por el propietario y controles
/// encima, sin banners/textos promocionales. Se usa solamente en login,
/// registro y recuperación para no cambiar otros flujos de seguridad.
class FoodPhotoAuthScaffold extends StatelessWidget {
  const FoodPhotoAuthScaffold({
    super.key,
    required this.child,
    this.title,
    this.showBack = false,
  });

  final Widget child;
  final String? title;
  final bool showBack;

  static final ButtonStyle whiteLink = TextButton.styleFrom(
    foregroundColor: Colors.white,
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final InputDecorationThemeData input = theme.inputDecorationTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF19191C),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: Image(
                key: ValueKey<String>('auth-food-photo'),
                image: AssetImage('assets/images/auth_food_cover.webp'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0x480B0810),
                        Color(0x0C100D15),
                        Color(0x66120A0E),
                        Color(0xE807070A),
                      ],
                      stops: <double>[0, 0.28, 0.54, 1],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints bounds) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: math.max(0, bounds.maxHeight - 38)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            SizedBox(
                              height: 48,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: showBack
                                    ? Material(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        shape: const CircleBorder(),
                                        child: IconButton(
                                          tooltip: 'Regresar',
                                          onPressed: () => Navigator.of(context).maybePop(),
                                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 430),
                                child: Theme(
                                  data: theme.copyWith(
                                    inputDecorationTheme: input.copyWith(
                                      fillColor: const Color(0xF5FFFFFF),
                                      hintStyle: const TextStyle(color: kMuted),
                                      labelStyle: const TextStyle(color: kInkSoft),
                                      floatingLabelStyle: const TextStyle(color: kBrandDeep, fontWeight: FontWeight.w700),
                                      prefixIconColor: kInkSoft,
                                      suffixIconColor: kInkSoft,
                                    ),
                                    checkboxTheme: CheckboxThemeData(
                                      fillColor: WidgetStateProperty.resolveWith(
                                        (Set<WidgetState> states) => states.contains(WidgetState.selected)
                                            ? kBrand
                                            : Colors.white,
                                      ),
                                      checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
                                      side: const BorderSide(color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      if (title != null) ...<Widget>[
                                        Text(
                                          title!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            height: 1.15,
                                            shadows: <Shadow>[
                                              Shadow(color: Colors.black54, blurRadius: 14),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                      ],
                                      child,
                                    ],
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
      ),
    );
  }
}

class PremiumAuthScaffold extends StatelessWidget {
  const PremiumAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.eyebrow = '',
    this.showBack = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAF6),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: AuthBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        height: 48,
                        child: Row(
                          children: <Widget>[
                            if (showBack)
                              TalaCircleButton(icon: Icons.arrow_back_rounded, tooltip: 'Regresar', onPressed: () => Navigator.of(context).maybePop())
                            else
                              const AuthBrandMark(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Reveal(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (eyebrow.isNotEmpty) ...<Widget>[
                              Text(eyebrow, style: TalaText.overline),
                              const SizedBox(height: 8),
                            ],
                            Text(title, style: TalaText.display),
                            const SizedBox(height: 8),
                            Text(subtitle, style: TalaText.muted.copyWith(fontSize: 15)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Reveal(index: 2, child: Material(type: MaterialType.transparency, child: child)),
                    ],
                  ),
                ),
              ),
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

/// Legal acknowledgement under the login form (links open the real documents).
class LegalLoginNotice extends StatelessWidget {
  const LegalLoginNotice({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Text(
          'Al iniciar sesión aceptas los Términos y Condiciones de Uso y reconoces el Aviso de Privacidad de Tala Eats. Precios, disponibilidad y cargos se confirman antes de finalizar cada pedido.',
          textAlign: TextAlign.center,
          style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 2),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 2,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).push(premiumRoute(const TermsAndConditionsScreen())),
              child: const Text('Términos y Condiciones'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).push(premiumRoute(PrivacyNoticeScreen(supportEmail: model.supportEmail))),
              child: const Text('Aviso de Privacidad'),
            ),
          ],
        ),
      ],
    );
  }
}
