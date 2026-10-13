import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../state/session_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/motion.dart';
import '../widgets/surfaces.dart';
import '../widgets/ticket.dart';
import 'login_screen.dart';
import 'onboarding/onboarding_screen.dart';

/// Primera apertura: bienvenida breve con el alta presentada como comanda
/// de tres pasos. CTA principal fijo abajo.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.session});

  final SessionController session;

  void _create(BuildContext context) {
    Navigator.of(context).push<void>(
      appRoute<void>(OnboardingScreen(session: session)),
    );
  }

  void _login(BuildContext context) {
    Navigator.of(context).push<void>(
      appRoute<void>(LoginScreen(session: session, showBack: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Halo de marca estático en la esquina superior (decorativo).
          const IgnorePointer(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _WelcomeGlow()),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter,
                          AppSpace.xxl,
                          AppSpace.gutter,
                          AppSpace.xxl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Entrance(child: BrandLockup()),
                            const SizedBox(height: 40),
                            Entrance(
                              delay: const Duration(milliseconds: 60),
                              child: Semantics(
                                header: true,
                                child: const Text(
                                  'Bienvenido a\nTala Eats Restaurante',
                                  style: AppText.display,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Entrance(
                              delay: Duration(milliseconds: 110),
                              child: Text(
                                'Da de alta tu negocio, publica tu primer producto y '
                                'empieza a recibir pedidos desde un solo panel.',
                                style: AppText.bodySoft,
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Entrance(
                              delay: Duration(milliseconds: 170),
                              child: _SetupTicket(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Entrance(
                      delay: const Duration(milliseconds: 220),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter,
                          AppSpace.sm,
                          AppSpace.gutter,
                          AppSpace.lg,
                        ),
                        child: Column(
                          children: <Widget>[
                            AppButton(
                              key: const ValueKey<String>('createMyRestaurantButton'),
                              label: 'Crear mi restaurante',
                              size: AppButtonSize.large,
                              onPressed: () => _create(context),
                            ),
                            const SizedBox(height: 8),
                            AppButton(
                              key: const ValueKey<String>('alreadyHaveAccountButton'),
                              label: 'Ya tengo cuenta',
                              variant: AppButtonVariant.ghost,
                              onPressed: () => _login(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dos círculos suaves en tono de marca, parcialmente fuera de la pantalla.
class _WelcomeGlow extends CustomPainter {
  const _WelcomeGlow();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width + 30, -20);
    canvas.drawCircle(
      center,
      240,
      Paint()..color = AppColors.brand.withValues(alpha: 0.06),
    );
    canvas.drawCircle(
      center,
      150,
      Paint()..color = AppColors.brand.withValues(alpha: 0.07),
    );
  }

  @override
  bool shouldRepaint(_WelcomeGlow oldDelegate) => false;
}

class _SetupTicket extends StatelessWidget {
  const _SetupTicket();

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      header: Row(
        children: <Widget>[
          const Expanded(
            child: Text('Tu alta', style: AppText.subtitle),
          ),
          Text(
            'Unos 3 minutos',
            style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      body: const Column(
        children: <Widget>[
          _Step(
            number: 1,
            title: 'Tu cuenta',
            detail: 'Nombre, correo y teléfono del propietario.',
          ),
          _Step(
            number: 2,
            title: 'Tu restaurante',
            detail: 'Nombre, tipo de comida y foto de portada.',
          ),
          _Step(
            number: 3,
            title: 'Tu primer producto',
            detail: 'Foto, precio, categoría y stock.',
            last: true,
          ),
        ],
      ),
      footer: Row(
        children: <Widget>[
          const Icon(
            Icons.storefront_outlined,
            size: 18,
            color: AppColors.inkSoft,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Al terminar enviaremos tu solicitud para revisión.',
              style: AppText.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final int number;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Column(
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.line,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppText.subtitle),
                    const SizedBox(height: 2),
                    Text(detail, style: AppText.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
