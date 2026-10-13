import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ===========================================================================
// SISTEMA CENTRAL DE MOTION — Tala Eats Repartidor v1.0.1 (polish integrado)
// ===========================================================================
//
// Reglas:
// * Microfeedback 120–160 ms, transiciones 200–260 ms, cambios de estado
//   importantes hasta 340 ms. Nada de loops decorativos, rebotes ni parallax.
// * Toda animación consulta [Motion.reduced]. Con "reducir movimiento" activo
//   se eliminan desplazamientos/escala y los cambios son instantáneos.
// * Ninguna animación bloquea o retrasa un CTA: los botones son interactivos
//   desde el primer frame.

/// Tokens de duración/curva y helpers de accesibilidad.
abstract final class Motion {
  /// Feedback de toque, cambios de color, press.
  static const Duration micro = Duration(milliseconds: 140);

  /// Transiciones de elementos pequeños (textos, iconos, banners).
  static const Duration short = Duration(milliseconds: 200);

  /// Transiciones normales (cards, tabs, secciones).
  static const Duration medium = Duration(milliseconds: 260);

  /// Cambios de estado importantes (etapa de entrega, éxito).
  static const Duration emphasis = Duration(milliseconds: 340);

  /// Curva estándar de entrada.
  static const Curve standard = Curves.easeOutCubic;

  /// Curva enfatizada (Material 3 "emphasized decelerate").
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Curva de salida.
  static const Curve exit = Curves.easeInCubic;

  /// Desplazamiento vertical estándar de entrada, en dp.
  static const double rise = 10;

  /// `true` cuando el sistema pide reducir/desactivar animaciones.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Devuelve [d] o [Duration.zero] si el usuario reduce movimiento.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Feedback háptico centralizado. Cortos y solo en acciones con significado.
abstract final class Haptics {
  /// Cambio de selección (tabs, toggles, adjuntar evidencia).
  static void selection() => unawaited(HapticFeedback.selectionClick());

  /// Avance de etapa confirmado.
  static void confirm() => unawaited(HapticFeedback.lightImpact());

  /// Entrega completada.
  static void success() => unawaited(HapticFeedback.mediumImpact());

  /// Acción rechazada / bloqueada.
  static void warning() => unawaited(HapticFeedback.heavyImpact());
}

// ---------------------------------------------------------------------------
// Entrance — aparición única (fade + subida corta), con retraso opcional.
// ---------------------------------------------------------------------------
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.medium,
    this.rise = Motion.rise,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Desplazamiento inicial en dp (se anima a 0).
  final double rise;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    final safeTotal = total == Duration.zero ? Motion.micro : total;
    final start = widget.delay.inMicroseconds / safeTotal.inMicroseconds;
    _controller = AnimationController(vsync: this, duration: safeTotal);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(math.min(start, .95), 1, curve: Motion.emphasized),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
      return;
    }
    if (_controller.isDismissed && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return FadeTransition(
      opacity: _progress,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.rise * (1 - _progress.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// StateSwitcher — cambio entre estados con continuidad visual.
// Entra: fade + subida corta. Sale: solo fade (más rápido). Altura animada.
// ---------------------------------------------------------------------------
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({
    super.key,
    required this.child,
    this.duration = Motion.medium,
    this.rise = Motion.rise,
    this.animateSize = true,
    this.alignment = Alignment.topCenter,
  });

  /// Debe llevar una `key` distinta por estado para disparar la transición.
  final Widget child;
  final Duration duration;
  final double rise;
  final bool animateSize;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    if (reduced) return child;
    final d = duration;
    final switcher = AnimatedSwitcher(
      duration: d,
      reverseDuration: Motion.of(context, Motion.short),
      switchInCurve: Motion.emphasized,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        fit: StackFit.passthrough,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == this.child.key;
        if (!incoming || rise == 0) {
          return FadeTransition(opacity: animation, child: child);
        }
        return FadeTransition(
          opacity: animation,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, rise * (1 - animation.value)),
              child: child,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
    if (!animateSize) return switcher;
    return AnimatedSize(
      duration: d,
      curve: Motion.standard,
      alignment: alignment,
      child: switcher,
    );
  }
}

// ---------------------------------------------------------------------------
// Reveal — muestra/oculta banners, avisos y errores con entrada/salida suave.
// ---------------------------------------------------------------------------
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.visible,
    required this.child,
    this.duration = Motion.short,
  });

  final bool visible;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => StateSwitcher(
        duration: duration,
        rise: 6,
        child: visible
            ? KeyedSubtree(key: const ValueKey('reveal-on'), child: child)
            : const SizedBox.shrink(key: ValueKey('reveal-off')),
      );
}

// ---------------------------------------------------------------------------
// TabStage — transición corta al activar una pestaña (fade-through).
// ---------------------------------------------------------------------------
class TabStage extends StatefulWidget {
  const TabStage({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<TabStage> createState() => _TabStageState();
}

class _TabStageState extends State<TabStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: widget.active ? 1.0 : 0.0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Motion.emphasized,
  );

  @override
  void didUpdateWidget(TabStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Motion.reduced(context)) {
      _controller.stop();
      return;
    }
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 8 * (1 - _curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PressableScale — microinteracción de presión (sin rebote).
// No gestiona el tap: el hijo (InkWell/botón) sigue siendo el responsable.
// ---------------------------------------------------------------------------
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = .985,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (!widget.enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: Motion.micro,
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedNumber — interpola cambios de métricas (no anima al aparecer).
// ---------------------------------------------------------------------------
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.textAlign,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      format(value),
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Semantics(
      label: format(value),
      excludeSemantics: true,
      child: Motion.reduced(context)
          ? text
          : TweenAnimationBuilder<double>(
              tween: Tween<double>(end: value),
              duration: const Duration(milliseconds: 520),
              curve: Motion.standard,
              builder: (context, v, _) => Text(
                format(v),
                style: style,
                textAlign: textAlign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// SuccessMark — check que se dibuja una vez (sin confetti ni partículas).
// ---------------------------------------------------------------------------
class SuccessMark extends StatefulWidget {
  const SuccessMark({
    super.key,
    this.size = 56,
    this.color = const Color(0xFF157A43),
    this.background = const Color(0xFFEAF6EE),
  });

  final double size;
  final Color color;
  final Color background;

  @override
  State<SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<SuccessMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
      return;
    }
    if (_controller.isDismissed && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Semantics(
      label: 'Completado',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: reduced
            ? CustomPaint(
                painter: _CheckPainter(
                  progress: 1,
                  color: widget.color,
                  background: widget.background,
                ),
              )
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _CheckPainter(
                    progress: _controller.value,
                    color: widget.color,
                    background: widget.background,
                  ),
                ),
              ),
      ),
    );
  }
}

double _unit(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.progress,
    required this.color,
    required this.background,
  });

  final double progress;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final circleT = Curves.easeOutCubic.transform(_unit(progress / .55));
    final checkT = Curves.easeOutCubic.transform(_unit((progress - .35) / .65));

    canvas.drawCircle(
      center,
      radius * (.86 + .14 * circleT),
      Paint()..color = background.withValues(alpha: circleT),
    );

    if (checkT <= 0) return;
    final path = Path()
      ..moveTo(size.width * .30, size.height * .52)
      ..lineTo(size.width * .44, size.height * .66)
      ..lineTo(size.width * .71, size.height * .38);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.5, size.width * .075)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * checkT), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.background != background;
}

// ---------------------------------------------------------------------------
// Shake — sacudida horizontal breve para intentos inválidos.
// Se dispara cuando cambia [trigger]. Con reducir movimiento no se mueve
// (el error sigue comunicándose con texto + color + háptico).
// ---------------------------------------------------------------------------
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) _controller.stop();
  }

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && !Motion.reduced(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx = math.sin(t * math.pi * 4) * 7 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// StatusDot — punto de estado con un único pulso al encenderse (no loop).
// ---------------------------------------------------------------------------
class StatusDot extends StatefulWidget {
  const StatusDot({
    super.key,
    required this.on,
    required this.onColor,
    required this.offColor,
    this.size = 12,
  });

  final bool on;
  final Color onColor;
  final Color offColor;
  final double size;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) _ring.stop();
  }

  @override
  void didUpdateWidget(StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Motion.reduced(context)) {
      _ring.stop();
      return;
    }
    if (widget.on && !oldWidget.on) {
      _ring.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.on ? widget.onColor : widget.offColor;
    final box = widget.size * 2.4;
    return SizedBox.square(
      dimension: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!Motion.reduced(context))
            AnimatedBuilder(
              animation: _ring,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_ring.value);
                if (_ring.value == 0 || _ring.value == 1) {
                  return const SizedBox.shrink();
                }
                return Container(
                  width: widget.size + (box - widget.size) * t,
                  height: widget.size + (box - widget.size) * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.onColor.withValues(alpha: .28 * (1 - t)),
                  ),
                );
              },
            ),
          Motion.reduced(context)
              ? Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                )
              : AnimatedContainer(
                  duration: Motion.short,
                  curve: Motion.standard,
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SkeletonBox — placeholder sobrio para esperas futuras (datos remotos).
// Pulso suave de opacidad; estático con reducir movimiento.
// ---------------------------------------------------------------------------
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: .55,
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEAE6),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    if (Motion.reduced(context)) return box;
    return FadeTransition(opacity: _controller, child: box);
  }
}

// ---------------------------------------------------------------------------
// SheetRoute — transición para flujos críticos a pantalla completa
// (p. ej. prueba de entrega): sube desde abajo, sale más rápido.
// ---------------------------------------------------------------------------
class SheetRoute<T> extends PageRouteBuilder<T> {
  SheetRoute({
    required WidgetBuilder builder,
    bool reduceMotion = false,
    super.settings,
  }) : super(
          fullscreenDialog: true,
          transitionDuration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 320),
          reverseTransitionDuration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (Motion.reduced(context)) return child;
            final curved = CurvedAnimation(
              parent: animation,
              curve: Motion.emphasized,
              reverseCurve: Motion.exit,
            );
            return FadeTransition(
              opacity: Tween<double>(begin: .2, end: 1).animate(curved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, .08),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

// ---------------------------------------------------------------------------
// CountUp — cifra que cuenta desde [from] al aparecer (éxito / resúmenes).
// A diferencia de AnimatedNumber, SÍ anima en el primer frame. Con reducir
// movimiento muestra el valor final directamente.
// ---------------------------------------------------------------------------
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.from = 0,
    this.style,
    this.duration = const Duration(milliseconds: 560),
  });

  final double value;
  final double from;
  final String Function(double value) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final text = Text(
      format(value),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return Semantics(
      label: format(value),
      excludeSemantics: true,
      child: reduced
          ? text
          : TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: from, end: value),
              duration: duration,
              curve: Motion.emphasized,
              builder: (context, v, _) => Text(
                format(v),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// AttentionFlash — borde de marca que aparece y se desvanece UNA vez para
// dirigir la mirada (p. ej. nueva asignación). No es un loop ni un glow:
// dura ~1.4 s y desaparece. Con reducir movimiento el borde se muestra
// estático durante el mismo tiempo y se retira sin transición.
// ---------------------------------------------------------------------------
class AttentionFlash extends StatefulWidget {
  const AttentionFlash({
    super.key,
    required this.active,
    required this.child,
    this.color = const Color(0xFFFF5A1F),
    this.radius = 20,
  });

  /// Si es `true` al montarse, ejecuta el destello una sola vez.
  final bool active;
  final Widget child;
  final Color color;
  final double radius;

  @override
  State<AttentionFlash> createState() => _AttentionFlashState();
}

class _AttentionFlashState extends State<AttentionFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _controller.stop();
      return;
    }
    if (widget.active && _controller.isDismissed && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AttentionFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Motion.reduced(context)) {
      _controller.stop();
      return;
    }
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                if (t == 0 || t == 1) return const SizedBox.shrink();
                // Entra rápido (15%), se sostiene y se desvanece.
                final opacity = t < .15
                    ? t / .15
                    : 1 - Curves.easeInCubic.transform((t - .15) / .85);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    border: Border.all(
                      color: widget.color.withValues(alpha: .9 * opacity),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
