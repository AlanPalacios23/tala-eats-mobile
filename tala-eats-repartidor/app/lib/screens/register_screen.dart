import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class RegisterDriverScreen extends StatefulWidget {
  const RegisterDriverScreen({super.key, required this.controller});

  final DriverController controller;

  @override
  State<RegisterDriverScreen> createState() => _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends State<RegisterDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();

  bool _existingAccount = false;
  bool _obscure = true;
  bool _submitted = false;
  bool _sent = false;
  String _vehicle = 'Motocicleta';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _otp.dispose();
    super.dispose();
  }

  String? _nameError(String? raw) {
    if (_existingAccount) {
      return null;
    }
    final value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return 'Ingresa tu nombre completo.';
    }
    if (value.length < 2) {
      return 'Ingresa un nombre válido.';
    }
    if (value.length > 120) {
      return 'El nombre es demasiado largo.';
    }
    return null;
  }

  String? _phoneError(String? raw) {
    final value = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (value.isEmpty) {
      return 'Ingresa tu teléfono.';
    }
    if (value.length < 7) {
      return 'Revisa el número de teléfono.';
    }
    if ((raw ?? '').trim().length > 30) {
      return 'El teléfono es demasiado largo.';
    }
    return null;
  }

  String? _passwordError(String? raw) {
    final base = Validators.passwordError(raw);
    if (base != null) {
      return base;
    }
    if ((raw ?? '').length > 128) {
      return 'La contraseña es demasiado larga.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    final ok = await widget.controller.submitDriverApplication(
      existingAccount: _existingAccount,
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      phone: _phone.text.trim(),
      vehicle: _vehicle,
      otp: _otp.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (ok) {
      setState(() => _sent = true);
      return;
    }
    showAppSnack(
      context,
      widget.controller.lastErrorMessage ??
          'No pudimos enviar tu solicitud. Intenta de nuevo.',
      icon: Icons.error_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final loading = widget.controller.applying;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final screenWidth = MediaQuery.sizeOf(context).width;
          final compact = screenWidth <= 360 || textScale >= 1.25;
          final horizontalPadding = compact ? 16.0 : 20.0;

          InputDecoration fieldDecoration({
            required String label,
            required IconData icon,
            Widget? suffixIcon,
          }) => InputDecoration(
                labelText: label,
                prefixIcon: compact ? null : Icon(icon),
                suffixIcon: suffixIcon,
                suffixIconConstraints: compact && suffixIcon != null
                    ? const BoxConstraints(minWidth: 44, minHeight: 48)
                    : null,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 16,
                  vertical: 16,
                ),
              );

          return Scaffold(
            appBar: AppBar(
              title: const Text('Ser repartidor'),
            ),
            body: SafeArea(
              child: _sent
                  ? _Success(onDone: () => Navigator.of(context).pop())
                  : SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        18,
                        horizontalPadding,
                        36,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: AutofillGroup(
                            child: Form(
                              key: _formKey,
                              autovalidateMode: _submitted
                                  ? AutovalidateMode.onUserInteraction
                                  : AutovalidateMode.disabled,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  BrandLockup(center: compact),
                                  const SizedBox(height: Space.xl),
                                  Text(
                                    'Únete a la red de repartidores.',
                                    textAlign: compact ? TextAlign.center : TextAlign.start,
                                    style: TextStyle(
                                      color: kInk,
                                      fontSize: compact ? 24 : 28,
                                      fontWeight: FontWeight.w800,
                                      height: 1.08,
                                      letterSpacing: compact ? -.4 : -.7,
                                    ),
                                  ),
                                  const SizedBox(height: Space.s),
                                  Text(
                                    'Primero creamos tu cuenta Tala Eats y enviamos tu solicitud de repartidor. Tu acceso se activa cuando ADMIN la aprueba.',
                                    textAlign: compact ? TextAlign.center : TextAlign.start,
                                    style: AppText.bodyMuted,
                                  ),
                                  const SizedBox(height: Space.l),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ChoiceChip(
                                        key: const Key('register-mode-new'),
                                        label: Text(compact ? 'Cuenta nueva' : 'Crear cuenta nueva'),
                                        selected: !_existingAccount,
                                        onSelected: loading
                                            ? null
                                            : (_) => setState(() {
                                                  _existingAccount = false;
                                                  _submitted = false;
                                                }),
                                      ),
                                      ChoiceChip(
                                        key: const Key('register-mode-existing'),
                                        label: Text(compact ? 'Cuenta existente' : 'Ya tengo cuenta Tala Eats'),
                                        selected: _existingAccount,
                                        onSelected: loading
                                            ? null
                                            : (_) => setState(() {
                                                  _existingAccount = true;
                                                  _submitted = false;
                                                }),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: Space.l),
                                  if (!_existingAccount) ...[
                                    TextFormField(
                                      key: const Key('register-name'),
                                      controller: _name,
                                      enabled: !loading,
                                      textCapitalization: TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.name],
                                      validator: _nameError,
                                      decoration: fieldDecoration(
                                        label: compact ? 'Nombre' : 'Nombre completo',
                                        icon: Icons.person_outline_rounded,
                                      ),
                                    ),
                                    const SizedBox(height: Space.m),
                                  ],
                                  TextFormField(
                                    key: const Key('register-email'),
                                    controller: _email,
                                    enabled: !loading,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    validator: Validators.emailError,
                                    decoration: fieldDecoration(
                                      label: 'Correo',
                                      icon: Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: Space.m),
                                  TextFormField(
                                    key: const Key('register-phone'),
                                    controller: _phone,
                                    enabled: !loading,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9+() -]'),
                                      ),
                                    ],
                                    autofillHints: const [AutofillHints.telephoneNumber],
                                    validator: _phoneError,
                                    decoration: fieldDecoration(
                                      label: 'Teléfono',
                                      icon: Icons.phone_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: Space.m),
                                  TextFormField(
                                    key: const Key('register-password'),
                                    controller: _password,
                                    enabled: !loading,
                                    obscureText: _obscure,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: _existingAccount
                                        ? const [AutofillHints.password]
                                        : const [AutofillHints.newPassword],
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    validator: _passwordError,
                                    decoration: fieldDecoration(
                                      label: compact
                                          ? 'Contraseña'
                                          : (_existingAccount
                                              ? 'Contraseña'
                                              : 'Crea una contraseña'),
                                      icon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        tooltip: _obscure
                                            ? 'Mostrar contraseña'
                                            : 'Ocultar contraseña',
                                        onPressed: loading
                                            ? null
                                            : () => setState(
                                                  () => _obscure = !_obscure,
                                                ),
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_existingAccount) ...[
                                    const SizedBox(height: Space.m),
                                    TextFormField(
                                      key: const Key('register-otp'),
                                      controller: _otp,
                                      enabled: !loading,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      maxLength: 6,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: fieldDecoration(
                                        label: compact ? 'Código 2FA' : 'Código 2FA (si aplica)',
                                        icon: Icons.phonelink_lock_rounded,
                                      ).copyWith(counterText: ''),
                                    ),
                                  ],
                                  const SizedBox(height: Space.m),
                                  DropdownButtonFormField<String>(
                                    key: const Key('register-vehicle'),
                                    initialValue: _vehicle,
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Motocicleta',
                                        child: Text('Motocicleta'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Automóvil',
                                        child: Text('Automóvil'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Bicicleta',
                                        child: Text('Bicicleta'),
                                      ),
                                    ],
                                    onChanged: loading
                                        ? null
                                        : (value) {
                                            if (value != null) {
                                              setState(() => _vehicle = value);
                                            }
                                          },
                                    decoration: fieldDecoration(
                                      label: compact ? 'Vehículo' : 'Vehículo principal',
                                      icon: Icons.two_wheeler_rounded,
                                    ),
                                  ),
                                  const SizedBox(height: Space.l),
                                  InlineNotice(
                                    icon: Icons.verified_user_outlined,
                                    text: compact
                                        ? 'Tu acceso de repartidor se activa únicamente cuando TALA EATS ADMIN aprueba la solicitud.'
                                        : 'La cuenta no obtiene permisos de repartidor automáticamente. La solicitud queda pendiente de revisión y aprobación en TALA EATS ADMIN.',
                                  ),
                                  const SizedBox(height: Space.l),
                                  PrimaryButton(
                                    key: const Key('register-submit'),
                                    label: compact
                                        ? (_existingAccount
                                            ? 'Enviar solicitud'
                                            : 'Crear cuenta y solicitar acceso')
                                        : (_existingAccount
                                            ? 'Enviar solicitud con mi cuenta'
                                            : 'Crear cuenta y enviar solicitud'),
                                    loading: loading,
                                    loadingLabel: 'Enviando solicitud…',
                                    icon: Icons.arrow_forward_rounded,
                                    stackOnNarrow: true,
                                    onPressed: loading ? null : _submit,
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

class _Success extends StatelessWidget {
  const _Success({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLockup(center: true),
                const SizedBox(height: Space.xxl),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kGreen.withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 38,
                    color: kGreen,
                  ),
                ),
                const SizedBox(height: Space.l),
                const Text(
                  'Solicitud enviada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kInk,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: Space.s),
                const Text(
                  'Tu cuenta ya existe en Tala Eats y tu solicitud de repartidor quedó pendiente de aprobación. Cuando ADMIN la apruebe, usa el mismo correo y contraseña para entrar.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: Space.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onDone,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Volver a iniciar sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
