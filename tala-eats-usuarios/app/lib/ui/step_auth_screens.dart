part of '../main.dart';

/// Local Tala Eats email/password account (never a Google account).
enum TalaEmailMode { signIn, signUp }

class TalaStepAuthScreen extends StatefulWidget {
  const TalaStepAuthScreen({super.key, required this.model, required this.onBack,
    this.initialMode = TalaEmailMode.signIn});
  final TalaModel model;
  final VoidCallback onBack;
  final TalaEmailMode initialMode;
  @override
  State<TalaStepAuthScreen> createState() => _TalaStepAuthScreenState();
}

class _TalaStepAuthScreenState extends State<TalaStepAuthScreen> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final inputFocus = FocusNode();
  late TalaEmailMode mode = widget.initialMode;
  int step = 0;
  bool visiblePassword = false;
  bool busy = false;
  String error = '';

  @override
  void dispose() {
    firstName.dispose(); lastName.dispose(); email.dispose(); password.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  int get finalStep => mode == TalaEmailMode.signUp ? 3 : 1;
  bool get passwordStep => step == finalStep;
  TextEditingController get active {
    if (mode == TalaEmailMode.signIn) return step == 0 ? email : password;
    return <TextEditingController>[firstName, lastName, email, password][step];
  }
  bool get valid {
    final String value = active.text.trim();
    if (mode == TalaEmailMode.signUp && step < 2) {
      return value.length >= 2 && value.length <= 80;
    }
    if (step != finalStep) {
      return value.length <= 254 &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    }
    if (mode == TalaEmailMode.signIn) return password.text.isNotEmpty;
    return password.text.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(password.text) &&
      RegExp(r'[a-z]').hasMatch(password.text) &&
      RegExp(r'[0-9]').hasMatch(password.text);
  }

  String get heading {
    if (mode == TalaEmailMode.signIn) {
      return step == 0 ? 'Ingresa tu correo\npara iniciar sesión'
        : 'Ingresa tu contraseña\npara iniciar sesión';
    }
    return <String>['¡Hola!\n¿Cuál es tu nombre?', '¿Cuál es tu apellido?',
      'Por último, agrega tu\ncorreo electrónico',
      'Crea tu contraseña\nde TALA EATS'][step];
  }
  String get placeholder {
    if (mode == TalaEmailMode.signIn) {
      return step == 0 ? 'Tu correo' : 'Tu contraseña';
    }
    return <String>['Tu nombre', 'Tu apellido', 'Tu correo', 'Tu contraseña'][step];
  }

  void refocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) inputFocus.requestFocus();
  });
  void switchMode(TalaEmailMode next) {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() { mode = next; step = 0; error = ''; });
    refocus();
  }
  void goBack() {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (step == 0) { widget.onBack(); return; }
    setState(() { step--; error = ''; });
    refocus();
  }

  Future<void> next() async {
    if (busy || !valid) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (step < finalStep) {
      setState(() { step++; error = ''; });
      refocus();
      return;
    }
    if (mode == TalaEmailMode.signUp) {
      await showConsent();
    } else {
      await signIn();
    }
  }

  Future<void> signIn() async {
    setState(() { busy = true; error = ''; });
    final bool ok = await widget.model.login(email.text, password.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (!ok) {
        error = widget.model.blockedRole.isNotEmpty
          ? 'Esta cuenta pertenece a otra aplicación de TALA EATS.'
          : (widget.model.lastError.isNotEmpty
            ? widget.model.lastError : 'Comprueba tu correo y contraseña.');
      }
    });
    if (ok) HapticFeedback.lightImpact();
  }

  Future<void> register() async {
    if (busy) return;
    setState(() { busy = true; error = ''; });
    // Existing backend takes one name field: join both required inputs.
    final String fullName = firstName.text.trim() + ' ' + lastName.text.trim();
    final bool ok = await widget.model.registerCustomer(
      fullName, email.text, password.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (!ok) error = widget.model.lastError.isNotEmpty
        ? widget.model.lastError : 'No pudimos crear la cuenta.';
    });
    if (ok) HapticFeedback.lightImpact();
  }

  Future<void> showConsent() async {
    bool acceptedTerms = false, acceptedPrivacy = false;
    final bool? approved = await showModalBottomSheet<bool>(
      context: context, useSafeArea: true, isScrollControlled: true,
      showDragHandle: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (BuildContext sheet) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Términos y condiciones',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800,
                  color: Colors.black)),
              const SizedBox(height: 17),
              const Divider(),
              CheckboxListTile(
                key: const ValueKey<String>('consentTerms'),
                activeColor: kBrandDeep, contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: acceptedTerms,
                onChanged: (bool? v) => update(() => acceptedTerms = v ?? false),
                title: const Text('Acepto los Términos y Condiciones de TALA EATS.'),
                subtitle: Align(alignment: Alignment.centerLeft, child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    premiumRoute(const TermsAndConditionsScreen())),
                  child: const Text('Leer términos'),
                )),
              ),
              CheckboxListTile(
                key: const ValueKey<String>('consentPrivacy'),
                activeColor: kBrandDeep, contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: acceptedPrivacy,
                onChanged: (bool? v) => update(() => acceptedPrivacy = v ?? false),
                title: const Text('Acepto el Aviso de Privacidad.'),
                subtitle: Align(alignment: Alignment.centerLeft, child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    premiumRoute(PrivacyNoticeScreen(
                      supportEmail: widget.model.supportEmail))),
                  child: const Text('Leer aviso de privacidad'),
                )),
              ),
              const SizedBox(height: 10),
              FilledButton(
                key: const ValueKey<String>('legalAccept'),
                style: FilledButton.styleFrom(backgroundColor: kBrandDeep,
                  minimumSize: const Size.fromHeight(56)),
                onPressed: acceptedTerms && acceptedPrivacy
                  ? () => Navigator.of(sheet).pop(true) : null,
                child: const Text('Aceptar'),
              ),
            ],
          )),
        ),
      ),
    );
    if (!mounted || approved != true) return;
    // Marketing preferences are intentionally absent until the backend
    // can persist consent separately from mandatory terms and privacy.
    await register();
  }

  @override
  Widget build(BuildContext context) {
    final bool signup = mode == TalaEmailMode.signUp;
    final double width = MediaQuery.sizeOf(context).width;
    final bool emailStep = !passwordStep &&
      ((signup && step == 2) || (!signup && step == 0));
    return Scaffold(
      key: const ValueKey<String>('talaStepAuth'),
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: IconButton(
              key: const ValueKey<String>('stepBack'),
              tooltip: 'Regresar',
              icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.black, size: 31),
              onPressed: goBack,
            )),
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 22, 25, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  signup ? 'CREAR CUENTA · PASO ${step + 1} DE 4'
                    : 'INICIAR SESIÓN · PASO ${step + 1} DE 2',
                  style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280), letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: (step + 1) / (signup ? 4 : 2),
                    backgroundColor: const Color(0xFFEDEDED),
                    valueColor: const AlwaysStoppedAnimation<Color>(kBrandDeep),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25, 30, 25, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(heading, key: const ValueKey<String>('stepTitle'),
                  style: TextStyle(
                    color: Colors.black, height: 1.13, letterSpacing: -0.9,
                    fontSize: width < 355 ? 29 : 34,
                    fontWeight: FontWeight.w800,
                  )),
                const SizedBox(height: 42),
                TextField(
                  key: ValueKey<String>('stepInput' + step.toString()),
                  controller: active,
                  focusNode: inputFocus,
                  keyboardType: emailStep
                    ? TextInputType.emailAddress : TextInputType.text,
                  textCapitalization: signup && step < 2
                    ? TextCapitalization.words : TextCapitalization.none,
                  autocorrect: signup && step < 2,
                  enableSuggestions: !passwordStep,
                  obscureText: passwordStep && !visiblePassword,
                  autofillHints: passwordStep
                    ? <String>[signup
                      ? AutofillHints.newPassword : AutofillHints.password]
                    : emailStep ? <String>[AutofillHints.email]
                    : <String>[step == 0
                      ? AutofillHints.givenName : AutofillHints.familyName],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => next(),
                  onChanged: (_) => setState(() => error = ''),
                  style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w700,
                    fontSize: width < 355 ? 25 : 30,
                  ),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: const TextStyle(
                      color: Color(0xFFBEC4CD),
                      fontWeight: FontWeight.w600),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    suffixIcon: passwordStep ? IconButton(
                      tooltip: visiblePassword
                        ? 'Ocultar contraseña' : 'Mostrar contraseña',
                      onPressed: () => setState(
                        () => visiblePassword = !visiblePassword),
                      icon: Icon(visiblePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    ) : null,
                  ),
                ),
                if (passwordStep && signup) ...<Widget>[
                  const SizedBox(height: 12),
                  const Text(
                    'Mínimo 8 caracteres, mayúscula, minúscula y número. '
                    'Usa una contraseña nueva de TALA EATS, no la de Google.',
                    style: TextStyle(fontSize: 13, height: 1.4,
                      color: Color(0xFF666B74)),
                  ),
                ],
                if (error.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFDCD0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.cloud_off_outlined,
                              color: Color(0xFFB83B14), size: 20),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(error,
                                key: const ValueKey<String>('stepError'),
                                style: const TextStyle(
                                  color: Color(0xFF873013),
                                  fontSize: 13, height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (passwordStep && !signup)
                          TextButton.icon(
                            key: const ValueKey<String>('retrySignIn'),
                            onPressed: valid && !busy ? signIn : null,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Volver a intentar'),
                          ),
                      ],
                    ),
                  ),
                ],
                if (step == 0) ...<Widget>[
                  const SizedBox(height: 18),
                  TextButton(
                    key: const ValueKey<String>('switchMode'),
                    onPressed: () => switchMode(signup
                      ? TalaEmailMode.signIn : TalaEmailMode.signUp),
                    child: Text(signup
                      ? '¿Ya tienes cuenta? Iniciar sesión'
                      : '¿Aún no tienes cuenta? Crear cuenta en TALA EATS'),
                  ),
                ],
                if (passwordStep && !signup)
                  TextButton(
                    onPressed: () => Navigator.of(context).push(premiumRoute(
                      ForgotPasswordScreen(model: widget.model))),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
              ],
            ),
          )),
          Padding(padding: const EdgeInsets.fromLTRB(20, 10, 25, 18),
            child: Align(alignment: Alignment.centerRight,
              child: busy
                ? const Padding(padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: kBrandDeep))
                : FilledButton(
                    key: const ValueKey<String>('stepNext'),
                    onPressed: valid ? next : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: kBrandDeep,
                      disabledBackgroundColor: const Color(0xFFFFD1C2),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(18),
                      minimumSize: const Size(62, 62),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 23),
                  ),
            )),
        ],
      )),
    );
  }
}
