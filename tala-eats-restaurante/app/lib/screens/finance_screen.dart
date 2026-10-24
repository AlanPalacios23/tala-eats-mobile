import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../state/operations_controller.dart';
import '../widgets/feedback.dart';
import '../widgets/motion.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import '../widgets/withdrawal_preview.dart';
import 'restaurant_settlement_balances.dart';

/// Finanzas: lectura rápida de ventas, pedidos, ticket y neto del periodo.
/// Los montos vienen de la fuente de datos; aquí no se calculan comisiones.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key, required this.ops});

  final OperationsController ops;

  Future<void> _refresh(BuildContext context) async {
    await ops.loadFinance();
    final failure = ops.financeFailure;
    if (failure != null && context.mounted) showFailureSnack(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: ops,
        builder: (context, _) {
          if (!ops.hasData && ops.status == LoadStatus.failure) {
            return Center(
              child: SingleChildScrollView(
                child: StateView.failure(ops.loadFailure!, onRetry: ops.retry),
              ),
            );
          }
          final summary = ops.finance;
          final Widget body;
          if (ops.financeStatus == LoadStatus.failure && ops.financeFailure != null) {
            body = StateView.failure(
              ops.financeFailure!,
              key: const ValueKey<String>('finance-failure'),
              onRetry: () => ops.loadFinance(),
              compact: true,
            );
          } else if (summary == null || ops.financeStatus == LoadStatus.loading) {
            body = const _FinanceSkeleton(key: ValueKey<String>('finance-loading'));
          } else if (summary.isEmpty) {
            body = StateView(
              key: ValueKey<String>('finance-empty-${summary.period.name}'),
              icon: Icons.receipt_long_outlined,
              title: 'Aún no hay ventas en este periodo',
              message: 'Cuando entregues pedidos verás aquí tus ventas, '
                  'el ticket promedio y tu ingreso neto.',
              compact: true,
            );
          } else {
            body = _FinanceBody(
              key: ValueKey<String>('finance-${summary.period.name}'),
              summary: summary,
            );
          }

          return RefreshIndicator(
            color: AppColors.ink,
            onRefresh: () => _refresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.lg,
                AppSpace.gutter,
                AppSpace.xxxl,
              ),
              children: <Widget>[
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _FinanceHeader(
                          action: WithdrawalPreviewAction(
                            gateway: ops.services.withdrawals,
                            restaurantId: ops.restaurant?.id,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xl),
                        _PeriodSelector(
                          selected: ops.financePeriod,
                          onSelect: (period) => ops.loadFinance(period),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        StateSwitcher(child: body),
                        if (ops.services.financeApi != null &&
                            ops.restaurant != null) ...<Widget>[
                          const SizedBox(height: AppSpace.lg),
                          RestaurantSettlementBalances(
                            api: ops.services.financeApi!,
                            restaurantId: ops.restaurant!.id,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Encabezado con acceso compacto a «Retirar ganancias»: en la misma línea
/// cuando hay espacio y debajo del subtítulo en teléfonos angostos.
class _FinanceHeader extends StatelessWidget {
  const _FinanceHeader({required this.action});

  final Widget action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inline = constraints.maxWidth >= 430;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScreenHeader(
              title: 'Finanzas',
              subtitle: 'Ventas e ingreso de tu restaurante',
              trailing: inline ? action : null,
            ),
            if (!inline) ...<Widget>[
              const SizedBox(height: AppSpace.md),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          ],
        );
      },
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelect});

  final FinancePeriod selected;
  final ValueChanged<FinancePeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          for (final period in FinancePeriod.values)
            Expanded(
              child: Semantics(
                selected: period == selected,
                button: true,
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.base),
                  decoration: BoxDecoration(
                    color: period == selected
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: period == selected
                          ? AppColors.line
                          : Colors.transparent,
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: period == selected ? null : () => onSelect(period),
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            period.label,
                            style: AppText.label.copyWith(
                              fontSize: 14,
                              color: period == selected
                                  ? AppColors.ink
                                  : AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FinanceBody extends StatelessWidget {
  const _FinanceBody({super.key, required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SalesHero(summary: summary),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final tiles = <Widget>[
              MetricTile(
                label: 'Pedidos',
                value: '${summary.orders}',
                caption: summary.cancelled == 0
                    ? 'Sin cancelaciones'
                    : plural(summary.cancelled, 'cancelado', 'cancelados'),
              ),
              MetricTile(
                label: 'Entregados',
                value: '${summary.delivered}',
              ),
              MetricTile(
                label: 'Ticket promedio',
                value: money(summary.avgTicket),
              ),
            ];
            if (constraints.maxWidth < 380) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: tiles[0]),
                      const SizedBox(width: 10),
                      Expanded(child: tiles[1]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  tiles[2],
                ],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: tiles[0]),
                const SizedBox(width: 10),
                Expanded(child: tiles[1]),
                const SizedBox(width: 10),
                Expanded(child: tiles[2]),
              ],
            );
          },
        ),
        if (summary.daily.length > 1) ...<Widget>[
          const SectionHeader('Ventas por día'),
          SurfaceCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _DailyBars(days: summary.daily),
          ),
        ],
        SectionHeader(
          summary.period == FinancePeriod.today
              ? 'Pedidos entregados hoy'
              : 'Pedidos entregados',
          trailing: summary.movements.isEmpty
              ? null
              : Text(
                  plural(summary.movements.length, 'pedido', 'pedidos'),
                  style: AppText.caption,
                ),
        ),
        if (summary.movements.isEmpty)
          SurfaceCard(
            child: StateView(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: summary.period == FinancePeriod.today
                  ? 'Sin entregas hoy'
                  : 'Sin entregas en este periodo',
              message: 'Cada pedido entregado aparecerá aquí con su ingreso.',
            ),
          )
        else
          _MovementsList(
            orders: summary.movements,
            showDate: summary.period != FinancePeriod.today,
          ),
        const SizedBox(height: 16),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                size: 17,
                color: AppColors.inkSoft,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'El ingreso neto es el monto reportado para tu restaurante en '
                'cada pedido entregado. No es saldo disponible para retirar.',
                style: AppText.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SalesHero extends StatelessWidget {
  const _SalesHero({required this.summary});

  final FinanceSummary summary;

  /// Fechas que cubre el periodo, tomadas de los días que envía la fuente.
  static String? _rangeLabel(FinanceSummary summary) {
    final days = summary.daily;
    if (days.isEmpty) return null;
    if (summary.period == FinancePeriod.today || days.length == 1) {
      return longDate(days.last.day);
    }
    return '${shortDate(days.first.day)} – ${shortDate(days.last.day)}';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Ventas ${summary.period.label}: ${money(summary.grossSales)}. '
          'Ingreso neto: ${money(summary.netToRestaurant)}. '
          'Comisión Tala Eats: 15% sobre productos.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          gradient: AppGradients.ink,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              summary.period == FinancePeriod.today
                  ? 'Ventas de hoy'
                  : 'Ventas de los últimos ${summary.period.label}',
              style: AppText.caption.copyWith(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_rangeLabel(summary) != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                _rangeLabel(summary)!,
                style: AppText.caption.copyWith(
                  color: Colors.white60,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: CountUpMoney(
                summary.grossSales,
                style: AppText.figure.copyWith(
                  color: Colors.white,
                  fontSize: 40,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: Color(0xFF8FD9B0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ingreso neto',
                      style: AppText.label.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CountUpMoney(
                    summary.netToRestaurant,
                    style: AppText.subtitle.copyWith(
                      color: const Color(0xFF8FD9B0),
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Comisión Tala Eats: 15% sobre productos vendidos',
              style: AppText.caption.copyWith(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barras diarias de una sola serie: magnitud en un tono, hoy resaltado.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.days});

  final List<DailySales> days;

  bool _showLabel(int i, int every) {
    final last = days.length - 1;
    if (i == last) return true;
    return i % every == 0 && last - i >= (every > 1 ? 3 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold<double>(0, (m, d) => math.max(m, d.gross));
    final best = days.reduce((a, b) => b.gross > a.gross ? b : a);
    final labelEvery = days.length > 10 ? 5 : 1;
    final duration = Motion.of(context, const Duration(milliseconds: 280));
    const chartHeight = 140.0;

    return Semantics(
      label: 'Ventas por día. Mejor día: ${shortWeekday(best.day)} '
          '${shortDate(best.day)}, ${money(best.gross)}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Mejor día: ${shortWeekday(best.day)} ${shortDate(best.day)}',
                  style: AppText.caption,
                ),
              ),
              Text(
                money(best.gross, cents: false),
                style: AppText.label.copyWith(fontFeatures: AppFonts.tabular),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: chartHeight,
            child: Stack(
              children: <Widget>[
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Divider(height: 1, color: AppColors.lineStrong),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: Tooltip(
                          message:
                              '${shortWeekday(days[i].day)} ${shortDate(days[i].day)}: '
                              '${money(days[i].gross)}',
                          triggerMode: TooltipTriggerMode.tap,
                          child: Container(
                            color: Colors.transparent,
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: AnimatedContainer(
                              duration: duration,
                              curve: Curves.easeOutCubic,
                              height: maxValue <= 0
                                  ? 2.0
                                  : math.max(
                                      2.0,
                                      days[i].gross / maxValue * (chartHeight - 4),
                                    ),
                              decoration: BoxDecoration(
                                color: i == days.length - 1
                                    ? AppColors.brand
                                    : const Color(0xFF4A4F4A),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 18,
            child: Row(
              children: <Widget>[
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: _showLabel(i, labelEvery)
                        ? OverflowBox(
                            maxWidth: 48,
                            child: Text(
                              i == days.length - 1
                                  ? 'Hoy'
                                  : labelEvery == 1
                                      ? shortWeekday(days[i].day)
                                      : '${days[i].day.day}',
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.center,
                              style: AppText.caption.copyWith(
                                fontSize: 11.5,
                                color: i == days.length - 1
                                    ? AppColors.ink
                                    : AppColors.inkSoft,
                                fontWeight: i == days.length - 1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pedidos entregados del periodo. Muestra bloques de 15 para no construir
/// listas enormes de una sola vez (30 días pueden ser cientos de pedidos).
class _MovementsList extends StatefulWidget {
  const _MovementsList({required this.orders, required this.showDate});

  final List<RestaurantOrder> orders;
  final bool showDate;

  @override
  State<_MovementsList> createState() => _MovementsListState();
}

class _MovementsListState extends State<_MovementsList> {
  static const int _page = 15;
  int _visible = _page;

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    final count = orders.length < _visible ? orders.length : _visible;
    final remaining = orders.length - count;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < count; i++) ...<Widget>[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            _MovementRow(order: orders[i], showDate: widget.showDate),
          ],
          if (remaining > 0) ...<Widget>[
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => setState(() => _visible += _page),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandText,
                  minimumSize: const Size(44, 48),
                ),
                child: Text(
                  'Mostrar ${remaining < _page ? remaining : _page} más',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.order, required this.showDate});

  final RestaurantOrder order;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Pedido #${order.id}',
                  style: AppText.subtitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${showDate ? '${shortWeekday(order.createdAt)} ${shortDate(order.createdAt)}, ' : ''}'
                  '${clockTime(order.createdAt)}, '
                  '${plural(order.itemCount, 'producto', 'productos')}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '+${money(order.restaurantPayout)}',
                style: AppText.subtitle.copyWith(
                  fontSize: 15,
                  color: AppColors.green,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'de ${money(order.total)}',
                style: AppText.caption.copyWith(
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceSkeleton extends StatelessWidget {
  const _FinanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Shimmer(child: Bone(height: 150, radius: AppRadius.lg)),
        SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(child: Shimmer(child: Bone(height: 92, radius: AppRadius.lg))),
            SizedBox(width: 10),
            Expanded(child: Shimmer(child: Bone(height: 92, radius: AppRadius.lg))),
            SizedBox(width: 10),
            Expanded(child: Shimmer(child: Bone(height: 92, radius: AppRadius.lg))),
          ],
        ),
        SizedBox(height: 24),
        Shimmer(child: Bone(width: 140, height: 18)),
        SizedBox(height: 12),
        Shimmer(child: Bone(height: 200, radius: AppRadius.lg)),
      ],
    );
  }
}
