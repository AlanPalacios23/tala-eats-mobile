import 'package:flutter/material.dart';

import '../core/failures.dart';
import '../core/theme.dart';
import 'buttons.dart';

/// Estado de pantalla/sección: vacío, error u offline. Siempre propone una
/// acción concreta cuando existe.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.tone = StateTone.neutral,
    this.compact = false,
  });

  /// Error o sin conexión a partir de un [AppFailure].
  factory StateView.failure(
    AppFailure failure, {
    Key? key,
    required VoidCallback onRetry,
    bool compact = false,
  }) {
    final offline = failure.isConnectivity;
    return StateView(
      key: key,
      icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_outlined,
      title: failure.title,
      message: failure.message,
      actionLabel: 'Reintentar',
      onAction: onRetry,
      tone: offline ? StateTone.warning : StateTone.danger,
      compact: compact,
    );
  }

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final StateTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    switch (tone) {
      case StateTone.neutral:
        fg = AppColors.inkSoft;
        bg = AppColors.sunken;
        break;
      case StateTone.positive:
        fg = AppColors.green;
        bg = AppColors.greenTint;
        break;
      case StateTone.warning:
        fg = AppColors.amber;
        bg = AppColors.amberTint;
        break;
      case StateTone.danger:
        fg = AppColors.red;
        bg = AppColors.redTint;
        break;
    }
    return Semantics(
      liveRegion: tone != StateTone.neutral,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : AppSpace.xxl,
          vertical: compact ? AppSpace.lg : AppSpace.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Ícono sobre un anillo suave (mismo lenguaje visual que la
            // pantalla de espera).
            Container(
              width: compact ? 64 : 92,
              height: compact ? 64 : 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: compact ? 48 : 64,
                height: compact ? 48 : 64,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                ),
                child: Icon(icon, color: fg, size: compact ? 22 : 30),
              ),
            ),
            SizedBox(height: compact ? 12 : 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title.copyWith(fontSize: compact ? 17 : 19),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.bodySoft.copyWith(fontSize: 14.5),
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              SizedBox(height: compact ? 14 : 22),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.dark,
                size: AppButtonSize.compact,
                expand: false,
                icon: tone == StateTone.neutral ? null : Icons.refresh_rounded,
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...<Widget>[
              const SizedBox(height: 6),
              TextButton(
                onPressed: onSecondary,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size(44, 44),
                ),
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum StateTone { neutral, positive, warning, danger }

/// Confirmación breve: círculo verde que se dibuja con un check.
class SuccessMark extends StatelessWidget {
  const SuccessMark({super.key, this.size = 76});

  final double size;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, const Duration(milliseconds: 420));
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final scale = 0.86 + 0.14 * t;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12 + 0.88 * t),
              shape: BoxShape.circle,
            ),
            child: CustomPaint(
              painter: _CheckPainter(progress: t),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final checkProgress = ((progress - 0.35) / 0.65).clamp(0.0, 1.0);
    if (checkProgress <= 0) return;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final a = Offset(size.width * 0.29, size.height * 0.52);
    final b = Offset(size.width * 0.44, size.height * 0.66);
    final c = Offset(size.width * 0.72, size.height * 0.37);
    final path = Path()..moveTo(a.dx, a.dy);
    if (checkProgress < 0.4) {
      final t = checkProgress / 0.4;
      path.lineTo(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
    } else {
      final t = (checkProgress - 0.4) / 0.6;
      path
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx + (c.dx - b.dx) * t, b.dy + (c.dy - b.dy) * t);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
