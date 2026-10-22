import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import 'common.dart';

/// Self-service Stripe Connect onboarding. No client-side money movement.
class WithdrawalPreviewCard extends StatefulWidget {
  const WithdrawalPreviewCard({super.key, this.controller});

  final DriverController? controller;

  @override
  State<WithdrawalPreviewCard> createState() => _WithdrawalPreviewCardState();
}

class _WithdrawalPreviewCardState extends State<WithdrawalPreviewCard> {
  bool _loading = false;
  String? _status;

  Future<void> _openConnect() async {
    if (_loading) return;
    final backend = widget.controller?.connectBackend;
    if (backend == null) {
      _message('El registro bancario estará disponible al iniciar sesión con tu cuenta de repartidor.');
      return;
    }
    setState(() => _loading = true);
    try {
      final who = await backend.api.get('/auth/me');
      if (who is! Map || who['role'] != 'driver' || who['id'] is! int) {
        throw StateError('Identidad de repartidor no confirmada');
      }
      final id = who['id'] as int;
      final status = await backend.api.get('/withdrawals/driver/$id/connect/status');
      if (status is! Map) {
        throw StateError('Respuesta de Stripe no confirmada');
      }
      // The Node RC7 contract is explicit: there is no active Stripe Connect
      // recipient account or onboarding capability. Do not request TOTP or
      // pretend that a bank can be linked while the backend says disabled.
      if (status['configuration'] == 'disabled-node-staging' ||
          status['recipient_transfer_capability_active'] == false &&
              status['withdrawals_enabled'] == false) {
        if (mounted) {
          setState(() => _status = 'disabled');
          _message('Stripe Connect todavía no está habilitado. No hay retiros disponibles.');
        }
        return;
      }
      if (status['status'] is! String) {
        throw StateError('Estado Stripe Connect desconocido');
      }
      if (mounted) setState(() => _status = status['status'] as String);
      // Every banking link requires fresh TOTP step-up (including first registration).
      final otp = await _bankStepUpDialog();
      if (!mounted || otp == null) return;
      final response = await backend.api.post('/withdrawals/driver/$id/connect/onboarding',
        body: {'totp': otp});
      if (response is! Map || response['url'] is! String) {
        throw StateError('Enlace bancario ausente');
      }
      final link = Uri.tryParse(response['url'] as String);
      if (link == null || link.scheme != 'https' ||
          !{'connect.stripe.com', 'dashboard.stripe.com'}.contains(link.host)) {
        throw StateError('Enlace bancario no autorizado');
      }
      final opened = await launchUrl(link, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError('No se pudo abrir Stripe');
      if (mounted) _message('Completa el registro en Stripe. Vuelve a Ganancias para consultar el estado.');
    } catch (_) {
      if (mounted) _message('No pudimos confirmar Stripe Connect. Tu dinero no se movió. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enableTwoFactor() async {
    final backend = widget.controller?.connectBackend;
    if (backend == null || _loading) return;
    setState(() => _loading = true);
    try {
      final setup = await backend.api.post('/v9/security/2fa/setup', body: {});
      if (setup is! Map || setup['secret'] is! String || (setup['secret'] as String).isEmpty) {
        throw StateError('No se pudo iniciar 2FA');
      }
      if (!mounted) return;
      final field = TextEditingController();
      try {
        final response = await showDialog<String>(context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Activar verificación 2FA'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Agrega esta clave en Google o Microsoft Authenticator. Después confirma el código.'),
              const SizedBox(height: 12),
              SelectableText(setup['secret'] as String),
              const SizedBox(height: 12),
              TextField(controller: field, maxLength: 6, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Código de 6 dígitos')),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(onPressed: () {
                if (RegExp(r'^\d{6}$').hasMatch(field.text.trim())) {
                  Navigator.pop(ctx, field.text.trim());
                }
              }, child: const Text('Confirmar')),
            ],
          ));
        if (!mounted || response == null) return;
        final checked = await backend.api.post('/v9/security/2fa/confirm',
          body: {'code': response});
        if (checked is! Map || checked['enabled'] != true) throw StateError('Código no aceptado');
        if (mounted) _message('2FA activo. Ya puedes registrar tu banco en Stripe.');
      } finally {
        field.clear(); field.dispose();
      }
    } catch (_) {
      if (mounted) _message('No se pudo activar 2FA. Si ya está activo, usa tu aplicación Authenticator.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sensitive Express banking access requires fresh authenticator code.
  Future<String?> _bankStepUpDialog() async {
    final code = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verifica tu identidad'),
          content: TextField(
            controller: code, keyboardType: TextInputType.number,
            maxLength: 6, obscureText: true,
            decoration: const InputDecoration(labelText: 'Código 2FA',
              helperText: 'Para administrar tu banco en Stripe.'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            TextButton(onPressed: () {
              if (RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
                Navigator.pop(dialogContext, code.text.trim());
              }
            }, child: const Text('Continuar')),
          ],
        ),
      );
    } finally {
      code.clear();
      code.dispose();
    }
  }

  void _message(String value) {
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: const Text('Cuenta bancaria'),
      content: Text(value),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
    ));
  }

  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Row(children: [Icon(Icons.account_balance_wallet_outlined, color: kInk),
        SizedBox(width: Space.m),
        Expanded(child: Text('Configura tus retiros', style: AppText.title))]),
      const SizedBox(height: Space.s),
      const Text('Vincula tu banco de forma segura con Stripe. Tus ganancias registradas no son saldo retirable.', style: AppText.bodyMuted),
      if (_status != null) ...[
        const SizedBox(height: Space.s),
        Text('Estado bancario: ${_status == 'verified' ? 'Identidad verificada' : 'Verificación pendiente'}', style: AppText.caption),
      ],
      const SizedBox(height: Space.l),
      SizedBox(height: 52, child: OutlinedButton.icon(
        key: const ValueKey<String>('driver-withdraw-earnings'),
        onPressed: _loading ? null : _openConnect,
        icon: const Icon(Icons.account_balance_outlined),
        label: Text(_loading ? 'Verificando…' : 'Configurar cuenta bancaria'),
      )),
      const SizedBox(height: Space.s),
      TextButton.icon(onPressed: _loading ? null : _enableTwoFactor,
        icon: const Icon(Icons.verified_user_outlined),
        label: const Text('Activar 2FA para proteger mis retiros')),
      const SizedBox(height: Space.s),
      const Text('Los retiros reales solo se habilitan con saldo confirmado y autorización de TALA EATS.',
        style: AppText.caption, textAlign: TextAlign.center),
    ]),
  );
}
