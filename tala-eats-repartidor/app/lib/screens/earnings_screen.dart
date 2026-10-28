import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/withdrawal_preview.dart';
import '../widgets/driver_treasury_card.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key, required this.controller});

  final DriverController controller;

  @override
  Widget build(BuildContext context) {
    final hasData = controller.todayDeliveries > 0;
    return ScreenPad(
      onRefresh: controller.refreshHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(
            child: ScreenHeading(
              title: 'Ganancias',
              subtitle: formatLongDate(controller.now()),
            ),
          ),
          const SizedBox(height: Space.xl),
          Entrance(
            delay: const Duration(milliseconds: 40),
            child: _TodayCard(controller: controller, hasData: hasData),
          ),
          const SizedBox(height: Space.l),
          WithdrawalPreviewCard(controller: controller),
          const SizedBox(height: Space.l),
          DriverTreasuryCard(controller: controller),
          const SizedBox(height: Space.xxl),
          Entrance(
            delay: const Duration(milliseconds: 80),
            child: SectionHeader(
              'Esta semana',
              trailing: AnimatedNumber(
                value: controller.weekTotal,
                format: money,
                style: AppText.money,
              ),
            ),
          ),
          Entrance(
            delay: const Duration(milliseconds: 100),
            child: SurfaceCard(
              child: WeekChart(
                values: controller.weekEarnings,
                todayIndex: controller.todayIndex,
              ),
            ),
          ),
          const SizedBox(height: Space.xxl),
          if (controller.todayOrdersTotalComplete && controller.todayDeliveries > 0) ...[
            Entrance(
              delay: const Duration(milliseconds: 120),
              child: _OrdersTotalNote(total: controller.todayOrdersTotal),
            ),
            const SizedBox(height: Space.l),
          ],
          const InlineNotice(
            icon: Icons.account_balance_outlined,
            text: 'Tus cortes y depósitos aparecerán aquí cuando estén '
                'disponibles.',
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.controller, required this.hasData});

  final DriverController controller;
  final bool hasData;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.fromLTRB(
          Space.xl,
          Space.xl,
          Space.xl,
          Space.l + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('TU GANANCIA DE HOY', style: AppText.overline),
            const SizedBox(height: Space.s),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedNumber(
                value: controller.todayEarnings,
                format: money,
                style: AppText.display,
              ),
            ),
            const SizedBox(height: Space.l + 2),
            const Divider(),
            const SizedBox(height: Space.l),
            StateSwitcher(
              child: hasData
                  ? MetricStrip(
                      key: const ValueKey('metrics'),
                      items: [
                        MetricItem(
                          label: 'Entregas',
                          value: AnimatedNumber(
                            value: controller.todayDeliveries.toDouble(),
                            format: (v) => v.round().toString(),
                            style: AppText.metric,
                          ),
                        ),
                        MetricItem(
                          label: 'Promedio',
                          value: AnimatedNumber(
                            value: controller.averagePerDelivery,
                            format: money,
                            style: AppText.metric,
                          ),
                        ),
                        MetricItem(
                          label: 'Km hoy',
                          value: Text(formatKm(controller.todayKm)),
                        ),
                      ],
                    )
                  : const Row(
                      key: ValueKey('no-data'),
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          color: kMuted,
                          size: 20,
                        ),
                        SizedBox(width: Space.s + 2),
                        Expanded(
                          child: Text(
                            'Aún no tienes ganancias hoy. Se sumarán aquí al '
                            'completar tu primera entrega.',
                            style: AppText.bodyMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
}

/// Separa explícitamente el valor de los pedidos de la ganancia propia.
class _OrdersTotalNote extends StatelessWidget {
  const _OrdersTotalNote({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        color: kSurfaceSunken,
        borderColor: kSurfaceSunken,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.receipt_long_rounded, color: kMuted, size: 20),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 250 ||
                          MediaQuery.textScalerOf(context).scale(1) >= 1.25;
                      final amount = AnimatedNumber(
                        value: total,
                        format: money,
                        style: AppText.money.copyWith(color: kMuted),
                      );
                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Valor de pedidos entregados',
                              style: AppText.title,
                            ),
                            const SizedBox(height: Space.xs),
                            amount,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Text(
                              'Valor de pedidos entregados',
                              style: AppText.title,
                            ),
                          ),
                          const SizedBox(width: Space.s),
                          amount,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: Space.xs),
                  const Text(
                    'Lo pagan los clientes por sus pedidos. No forma parte '
                    'de tus ganancias.',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ===========================================================================
// WeekChart — barras sobrias, interactivas y accesibles.
// ===========================================================================
class WeekChart extends StatefulWidget {
  const WeekChart({super.key, required this.values, required this.todayIndex});

  /// Lunes … domingo. `null` = día futuro.
  final List<double?> values;
  final int todayIndex;

  @override
  State<WeekChart> createState() => _WeekChartState();
}

class _WeekChartState extends State<WeekChart> {
  late int _selected = widget.todayIndex;

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final maxValue = values.fold<double>(
      0,
      (max, v) => v != null && v > max ? v : max,
    );
    final selectedValue = values[_selected];
    final selectedLabel = _selected == widget.todayIndex
        ? 'Hoy'
        : capitalize(kWeekdays[_selected]);
    final duration = Motion.of(context, const Duration(milliseconds: 420));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StateSwitcher(
          duration: Motion.short,
          rise: 4,
          animateSize: false,
          alignment: Alignment.centerLeft,
          child: Wrap(
            key: ValueKey(_selected),
            spacing: Space.s,
            runSpacing: Space.xxs,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(selectedLabel, style: AppText.caption),
              Text(
                selectedValue == null ? '—' : money(selectedValue),
                style: AppText.metric,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.l),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: _Bar(
                    label: kWeekdayInitials[i],
                    semanticDay: capitalize(kWeekdays[i]),
                    value: values[i],
                    factor: values[i] == null || maxValue == 0
                        ? 0.0
                        : values[i]! / maxValue,
                    selected: i == _selected,
                    isToday: i == widget.todayIndex,
                    duration: duration == Duration.zero
                        ? Duration.zero
                        : duration + Duration(milliseconds: i * 30),
                    onTap: values[i] == null
                        ? null
                        : () {
                            Haptics.selection();
                            setState(() => _selected = i);
                          },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.semanticDay,
    required this.value,
    required this.factor,
    required this.selected,
    required this.isToday,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final String semanticDay;
  final double? value;
  final double factor;
  final bool selected;
  final bool isToday;
  final Duration duration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final future = value == null;
    final reduced = Motion.reduced(context);
    final Color barColor = selected
        ? kInk
        : isToday
            ? kBrandDeep.withValues(alpha: .55)
            : const Color(0xFFE2DDD8);

    return Semantics(
      button: !future,
      selected: selected,
      label: future
          ? '$semanticDay, sin datos'
          : '$semanticDay${isToday ? ' (hoy)' : ''}, ${money(value!)}',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: future
                      ? Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: kSurfaceSunken,
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                        )
                      : reduced
                          ? FractionallySizedBox(
                              heightFactor: factor < .04 ? .04 : factor,
                              widthFactor: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            )
                          : TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: factor),
                              duration: duration,
                              curve: Motion.emphasized,
                              builder: (context, f, _) =>
                                  FractionallySizedBox(
                                heightFactor: f < .04 ? .04 : f,
                                widthFactor: 1,
                                child: AnimatedContainer(
                                  duration: Motion.short,
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
              const SizedBox(height: Space.s),
              Text(
                label,
                style: AppText.caption.copyWith(
                  color: selected ? kInk : kMuted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              SizedBox(
                height: 8,
                child: Center(
                  child: reduced
                      ? Opacity(
                          opacity: isToday ? 1.0 : 0.0,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: kBrandDeep,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : AnimatedOpacity(
                          duration: Motion.short,
                          opacity: isToday ? 1.0 : 0.0,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: kBrandDeep,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
