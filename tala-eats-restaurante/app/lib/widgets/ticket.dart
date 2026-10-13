import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/entities.dart';

// ---------------------------------------------------------------------------
// Reloj compartido: un solo Timer por pantalla para todos los tiempos
// transcurridos, en lugar de un Timer por tarjeta.
// ---------------------------------------------------------------------------

class ClockScope extends InheritedNotifier<ValueNotifier<DateTime>> {
  const ClockScope({
    super.key,
    required ValueNotifier<DateTime> clock,
    required super.child,
  }) : super(notifier: clock);

  static DateTime now(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ClockScope>()
          ?.notifier
          ?.value ??
      DateTime.now();
}

/// Provee [ClockScope] y lo actualiza cada 20 s.
class ClockProvider extends StatefulWidget {
  const ClockProvider({super.key, required this.child});

  final Widget child;

  @override
  State<ClockProvider> createState() => _ClockProviderState();
}

class _ClockProviderState extends State<ClockProvider> {
  final ValueNotifier<DateTime> _clock = ValueNotifier<DateTime>(DateTime.now());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _clock.value = DateTime.now(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ClockScope(clock: _clock, child: widget.child);
}

// ---------------------------------------------------------------------------
// Urgencia: umbrales centralizados (pueden venir del backend después).
// ---------------------------------------------------------------------------

enum Urgency { calm, attention, critical }

abstract final class UrgencyPolicy {
  static Urgency of(RestaurantOrder order, DateTime now) {
    final minutes = minutesSince(order.createdAt, now);
    switch (order.stage) {
      case OrderStage.incoming:
        if (minutes >= 8) return Urgency.critical;
        if (minutes >= 4) return Urgency.attention;
        return Urgency.calm;
      case OrderStage.kitchen:
        if (minutes >= 35) return Urgency.critical;
        if (minutes >= 20) return Urgency.attention;
        return Urgency.calm;
      case OrderStage.ready:
        if (minutes >= 45) return Urgency.attention;
        return Urgency.calm;
      case OrderStage.outbound:
      case OrderStage.closed:
        return Urgency.calm;
    }
  }
}

/// "12 min" con color según urgencia. Se actualiza con [ClockScope].
class ElapsedChip extends StatelessWidget {
  const ElapsedChip({super.key, required this.order, this.large = false, this.onDark = false});

  final RestaurantOrder order;
  final bool large;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final now = ClockScope.now(context);
    final minutes = minutesSince(order.createdAt, now);
    final urgency = order.isActive ? UrgencyPolicy.of(order, now) : Urgency.calm;
    final Color fg;
    final Color bg;
    switch (urgency) {
      case Urgency.calm:
        fg = onDark ? AppColors.ink : AppColors.inkSoft;
        bg = onDark ? const Color(0xFFE6E5DF) : AppColors.sunken;
        break;
      case Urgency.attention:
        fg = AppColors.amber;
        bg = AppColors.amberTint;
        break;
      case Urgency.critical:
        fg = Colors.white;
        bg = AppColors.red;
        break;
    }
    final label = order.isActive ? elapsedLabel(minutes) : clockTime(order.createdAt);
    return Semantics(
      label: order.isActive
          ? 'Hace ${elapsedLabel(minutes)}${urgency == Urgency.critical ? ', demorado' : ''}'
          : 'Recibido a las ${clockTime(order.createdAt)}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 8,
          vertical: large ? 6 : 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              order.isActive ? Icons.schedule_rounded : Icons.access_time_rounded,
              size: large ? 17 : 14,
              color: fg,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppText.label.copyWith(
                fontSize: large ? 15 : 12.5,
                color: fg,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comanda: tarjeta de pedido con línea de corte y muescas laterales.
// ---------------------------------------------------------------------------

class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.accent,
    this.paper = AppColors.surface,
    this.edge = AppColors.line,
    this.notchColor = AppColors.canvas,
    this.onTap,
    this.dimmed = false,
  });

  final Widget header;
  final Widget body;
  final Widget? footer;

  /// Franja superior de estado (opcional). Acompaña, no reemplaza, al texto.
  final Color? accent;
  final Color paper;
  final Color edge;

  /// Debe coincidir con el fondo detrás de la tarjeta.
  final Color notchColor;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (accent != null)
          AnimatedContainer(
            duration: Motion.of(context, Motion.base),
            height: 4,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(4),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, accent == null ? 14 : 10, 16, 10),
          child: header,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: body,
        ),
        if (footer != null) ...<Widget>[
          TearLine(notchColor: notchColor, lineColor: edge),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: footer,
          ),
        ],
      ],
    );

    return AnimatedOpacity(
      opacity: dimmed ? 0.6 : 1,
      duration: Motion.of(context, Motion.base),
      child: Material(
        color: paper,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: edge),
        ),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: content,
              ),
      ),
    );
  }
}

/// Línea de corte punteada con muescas semicirculares en los bordes.
class TearLine extends StatelessWidget {
  const TearLine({
    super.key,
    required this.notchColor,
    required this.lineColor,
  });

  final Color notchColor;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 16,
        width: double.infinity,
        child: CustomPaint(
          painter: _TearPainter(notchColor: notchColor, lineColor: lineColor),
        ),
      ),
    );
  }
}

class _TearPainter extends CustomPainter {
  const _TearPainter({required this.notchColor, required this.lineColor});

  final Color notchColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 8.0;
    final cy = size.height / 2;
    final fill = Paint()..color = notchColor;
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final left = Offset(0, cy);
    final right = Offset(size.width, cy);
    canvas.drawCircle(left, r + 0.6, fill);
    canvas.drawCircle(right, r + 0.6, fill);
    canvas.drawArc(
      Rect.fromCircle(center: left, radius: r),
      -math.pi / 2,
      math.pi,
      false,
      stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: right, radius: r),
      math.pi / 2,
      math.pi,
      false,
      stroke,
    );

    final dash = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dashWidth = 5.0;
    const gap = 4.0;
    var x = r + 6;
    while (x < size.width - r - 6) {
      final end = math.min(x + dashWidth, size.width - r - 6);
      canvas.drawLine(Offset(x, cy), Offset(end, cy), dash);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_TearPainter oldDelegate) =>
      oldDelegate.notchColor != notchColor || oldDelegate.lineColor != lineColor;
}

/// Líneas de productos de una comanda: cantidad destacada + nombre + extras.
class TicketLines extends StatelessWidget {
  const TicketLines({
    super.key,
    required this.items,
    this.maxVisible,
    this.large = false,
    this.inkColor = AppColors.ink,
    this.softColor = AppColors.inkSoft,
  });

  final List<OrderLine> items;
  final int? maxVisible;
  final bool large;
  final Color inkColor;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    final limit = maxVisible;
    final visible = limit == null || items.length <= limit
        ? items
        : items.take(limit - 1).toList();
    final hidden = items.length - visible.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final line in visible)
          Padding(
            padding: EdgeInsets.only(bottom: large ? 8 : 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: large ? 40 : 30,
                  child: Text(
                    '${line.quantity}×',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: large ? 21 : 16,
                      height: 1.25,
                      color: inkColor,
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        line.name,
                        style: AppText.body.copyWith(
                          fontSize: large ? 19 : 15,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          color: inkColor,
                        ),
                      ),
                      if (line.options.trim().isNotEmpty)
                        Text(
                          line.options,
                          style: AppText.caption.copyWith(
                            fontSize: large ? 15 : 13,
                            color: softColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2),
            child: Text(
              '+ ${plural(hidden, 'producto más', 'productos más')}',
              style: AppText.caption.copyWith(
                color: softColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Nota del cliente: visible y diferenciada (ámbar + ícono), sin alarmismo.
class OrderNote extends StatelessWidget {
  const OrderNote({super.key, required this.text, this.large = false});

  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(large ? 12 : 10),
      decoration: BoxDecoration(
        color: AppColors.amberTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.sticky_note_2_outlined,
            size: large ? 20 : 17,
            color: AppColors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppText.body.copyWith(
                fontSize: large ? 17 : 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
