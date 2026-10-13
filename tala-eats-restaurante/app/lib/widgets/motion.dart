import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Entrada orquestada (fade + desplazamiento corto) para momentos únicos:
/// bienvenida, cambio de paso del alta y confirmaciones. No usa timers: el
/// retraso es parte de la curva, así que no deja trabajo pendiente.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 280),
    this.offset = const Offset(0, 12),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Desplazamiento inicial en píxeles lógicos.
  final Offset offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = widget.delay + widget.duration;
    _controller = AnimationController(vsync: this, duration: total);
    final start = total.inMicroseconds == 0
        ? 0.0
        : widget.delay.inMicroseconds / total.inMicroseconds;
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _controller.value = 1;
    } else {
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
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) {
        final t = _progress.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(
              widget.offset.dx * (1 - t),
              widget.offset.dy * (1 - t),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Escala sutil al presionar. Usa [Listener] para no competir con los
/// gestos del hijo (InkWell, botones).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = 0.98,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (!widget.enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.of(context, const Duration(milliseconds: 110)),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Texto que cambia con un fundido corto (cifras, etiquetas de estado).
class SwapText extends StatelessWidget {
  const SwapText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.base),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[...previous, if (current != null) current],
      ),
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
      ),
    );
  }
}

/// Cambio suave entre estados de una sección (skeleton → contenido,
/// contenido → error) conservando la alineación superior.
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({super.key, required this.child, this.expand = false});

  final Widget child;

  /// `true` cuando ocupa toda la pantalla (hijos con scroll propio).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.slow),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        fit: expand ? StackFit.expand : StackFit.loose,
        alignment: Alignment.topCenter,
        children: <Widget>[...previous, if (current != null) current],
      ),
      child: child,
    );
  }
}

/// Importe que «cuenta» hasta su valor (y entre valores al cambiar de
/// periodo). Solo es presentación: el número final es el que llega de la
/// fuente de datos. Con «reducir movimiento» se muestra directo.
class CountUpMoney extends StatelessWidget {
  const CountUpMoney(
    this.value, {
    super.key,
    required this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  final double value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: money(value),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: Motion.of(context, duration),
        curve: Curves.easeOutCubic,
        builder: (context, current, _) => Text(
          money(current),
          maxLines: 1,
          style: style,
        ),
      ),
    );
  }
}
