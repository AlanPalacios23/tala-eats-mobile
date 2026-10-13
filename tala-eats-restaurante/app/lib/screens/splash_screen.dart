import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/surfaces.dart';

/// Arranque: marca centrada que aparece en 260 ms. Si la restauración de
/// sesión tarda, aparece una línea de progreso discreta tras 700 ms (nunca
/// un spinner grande).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Halo de marca estático detrás del logotipo (sin animación
          // permanente: la pantalla de arranque dura muy poco).
          const CustomPaint(painter: _GlowPainter()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: reduced ? 1.0 : 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
                  ),
                  child: const BrandMark(size: 84),
                ),
                const SizedBox(height: 20),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: reduced ? 1.0 : 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 520),
                  curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: const Column(
                    children: <Widget>[
                      Text(
                        'Tala Eats',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 30,
                          height: 1,
                          letterSpacing: -0.6,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Panel para restaurantes',
                        style: AppText.bodySoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const _DelayedProgress(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DelayedProgress extends StatelessWidget {
  const _DelayedProgress();

  @override
  Widget build(BuildContext context) {
    // La curva mantiene opacidad 0 durante ~700 ms y luego aparece.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: const Interval(0.7, 1, curve: Curves.easeOut),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: const SizedBox(
        width: 96,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: LinearProgressIndicator(
            minHeight: 3,
            color: AppColors.brand,
            backgroundColor: AppColors.line,
          ),
        ),
      ),
    );
  }
}

/// Dos círculos suaves en tono de marca detrás del logotipo.
class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    canvas.drawCircle(
      center,
      150,
      Paint()..color = AppColors.brand.withValues(alpha: 0.06),
    );
    canvas.drawCircle(
      center,
      96,
      Paint()..color = AppColors.brand.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) => false;
}
