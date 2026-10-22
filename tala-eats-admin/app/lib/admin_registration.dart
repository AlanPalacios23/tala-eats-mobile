import 'package:flutter/material.dart';
import 'admin_api.dart';

/// Registro estándar del backend compartido. No crea cuentas privilegiadas.
class AdminRegistrationScreen extends StatefulWidget {
  const AdminRegistrationScreen({super.key, required this.api});
  final AdminApi api;

  @override
  State<AdminRegistrationScreen> createState() => _AdminRegistrationScreenState();
}

class _AdminRegistrationScreenState extends State<AdminRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.registerCustomer(_name.text, _email.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(_email.text.trim().toLowerCase());
    } on AdminApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo crear la cuenta.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Crear cuenta')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Color(0xFFF56A21), size: 50),
                      const SizedBox(height: 14),
                      const Text('Nueva cuenta Tala Eats',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 25, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text(
                        'La cuenta se registra como usuario estándar. '
                        'Un administrador autorizado deberá habilitar tu '
                        'acceso al equipo de operaciones por un proceso privado. '
                        'Este formulario nunca otorga permisos ADMIN.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.black54, height: 1.35)),
                      const SizedBox(height: 25),
                      TextFormField(
                        controller: _name,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder()),
                        validator: (s) =>
                            (s?.trim().length ?? 0) < 2
                                ? 'Escribe al menos dos caracteres'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.alternate_email),
                            border: OutlineInputBorder()),
                        validator: (s) {
                          final email = s?.trim() ?? '';
                          return !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)
                              ? 'Ingresa un correo válido'
                              : null;
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        maxLength: 128,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Contraseña (mín. 8 caracteres)',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            icon: Icon(_hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _hidePassword = !_hidePassword),
                          ),
                        ),
                        validator: (s) =>
                            (s?.length ?? 0) < 8
                                ? 'Usa al menos ocho caracteres'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirm,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (s) => s != _password.text
                            ? 'Las contraseñas no coinciden'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!,
                          style: const TextStyle(color: Color(0xFFAF2E28)),
                          textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: _busy
                            ? const SizedBox.square(dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Crear cuenta estándar'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('Ya tengo cuenta · Iniciar sesión'),
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
