import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../models/delivery.dart';
import '../widgets/common.dart';
import '../widgets/delivery_widgets.dart';
import '../widgets/motion.dart';

class DeliveriesScreen extends StatelessWidget {
  const DeliveriesScreen({super.key, required this.controller});

  final DriverController controller;

  @override
  Widget build(BuildContext context) {
    final job = controller.active;
    final current =
        job != null && job.stage != DeliveryStage.delivered ? job : null;
    final history = controller.history;
    final count = controller.todayDeliveries;

    return ScreenPad(
      onRefresh: controller.refreshHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(
            child: ScreenHeading(
              title: 'Entregas',
              subtitle: count == 0
                  ? 'Sin entregas completadas hoy'
                  : 'Hoy · $count completada${count == 1 ? '' : 's'} · '
                      '${formatKm(controller.todayKm)}',
            ),
          ),
          const SizedBox(height: Space.xl),
          Reveal(
            visible: current != null,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeader('En curso'),
                  if (current != null)
                    _CurrentDeliveryTile(
                      job: current,
                      onOpen: () => controller.setTab(0),
                    ),
                ],
              ),
            ),
          ),
          SectionHeader(
            'Historial',
            trailing: history.isEmpty
                ? null
                : Text(
                    '${history.length} pedido${history.length == 1 ? '' : 's'}',
                    style: AppText.caption,
                  ),
          ),
          StateSwitcher(
            child: _HistoryBody(
              key: ValueKey(
                '${controller.historyStatus.name}-${history.isEmpty}',
              ),
              controller: controller,
              history: history,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({
    super.key,
    required this.controller,
    required this.history,
  });

  final DriverController controller;
  final List<DeliveryJob> history;

  @override
  Widget build(BuildContext context) {
    final status = controller.historyStatus;
    if (status == LoadStatus.error) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        tone: Tone.error,
        title: 'No pudimos cargar tus entregas',
        message: 'Revisa tu conexión e intenta de nuevo.',
        actionLabel: 'Reintentar',
        onAction: controller.refreshHistory,
      );
    }
    if (status == LoadStatus.loading && history.isEmpty) {
      return const _HistorySkeleton();
    }
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'Aún no hay entregas',
        message: 'Las entregas que completes hoy aparecerán aquí.',
      );
    }
    final groups = _groupByDay(history, controller.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var g = 0; g < groups.length; g++) ...[
          if (g > 0) const SizedBox(height: Space.l + 2),
          _DayHeader(label: groups[g].label, jobs: groups[g].jobs),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < groups[g].jobs.length; i++) ...[
                  if (i > 0) const Divider(indent: 72),
                  Entrance(
                    key: ValueKey('history-${groups[g].jobs[i].id}'),
                    child: _HistoryRow(job: groups[g].jobs[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Grupo de entregas de un mismo día (el historial puede traer varios días).
class _DayGroup {
  _DayGroup(this.label);

  final String label;
  final List<DeliveryJob> jobs = <DeliveryJob>[];
}

String _dayLabel(DateTime? date, DateTime now) {
  if (date == null) return 'Recientes';
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  return formatLongDate(date);
}

List<_DayGroup> _groupByDay(List<DeliveryJob> history, DateTime now) {
  final groups = <_DayGroup>[];
  for (final job in history) {
    final label = _dayLabel(job.completedAt, now);
    if (groups.isEmpty || groups.last.label != label) {
      groups.add(_DayGroup(label));
    }
    groups.last.jobs.add(job);
  }
  return groups;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.jobs});

  final String label;
  final List<DeliveryJob> jobs;

  @override
  Widget build(BuildContext context) {
    final total = jobs.fold<double>(0, (sum, job) => sum + job.earning);
    return Semantics(
      header: true,
      label: '$label: ${jobs.length} entregas, ${money(total)}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.s),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  color: kInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              money(total),
              style: AppText.caption.copyWith(
                color: kInk,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentDeliveryTile extends StatelessWidget {
  const _CurrentDeliveryTile({required this.job, required this.onOpen});

  final DeliveryJob job;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        onTap: onOpen,
        semanticLabel: 'Entrega en curso ${job.id}: ${job.stage.label}. '
            'Abrir en Inicio',
        borderColor: kBrand.withValues(alpha: .35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconTile(
                  icon: Icons.delivery_dining_rounded,
                  tone: Tone.brand,
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.stage.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title,
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(
                        '${job.id} · ${job.restaurant} → ${job.customer}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s),
                const Icon(Icons.chevron_right_rounded, color: kMuted),
              ],
            ),
            const SizedBox(height: Space.m + 2),
            StageProgress(stage: job.stage, compact: true),
          ],
        ),
      );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.job});

  final DeliveryJob job;

  @override
  Widget build(BuildContext context) {
    final time = job.completedAt == null ? '—' : formatClock(job.completedAt!);
    return Semantics(
      button: true,
      label: 'Pedido ${job.id}, ${job.restaurant} a ${job.customer}, '
          'entregado a las $time, ganaste ${money(job.earning)}',
      onTap: () => showDeliveryDetails(context, job),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showDeliveryDetails(context, job),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.l,
              vertical: Space.m,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 310 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.25;
                final timeText = Text(
                  time,
                  maxLines: 1,
                  style: AppText.caption.copyWith(
                    color: kInk,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                );
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.restaurant,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title,
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      '${job.id} · ${job.customerAddress} · '
                      '${formatKm(job.distanceKm)}',
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          timeText,
                          const Spacer(),
                          Text(money(job.earning), style: AppText.money),
                        ],
                      ),
                      const SizedBox(height: Space.s),
                      details,
                    ],
                  );
                }
                return Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 44),
                      child: timeText,
                    ),
                    const SizedBox(width: Space.s + 2),
                    Expanded(child: details),
                    const SizedBox(width: Space.s + 2),
                    Text(money(job.earning), style: AppText.money),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Cargando entregas',
        child: SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const Divider(indent: 76),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Space.l,
                    vertical: Space.l,
                  ),
                  child: Row(
                    children: [
                      SkeletonBox(width: 40, height: 12),
                      SizedBox(width: Space.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 140, height: 13),
                            SizedBox(height: Space.s),
                            SkeletonBox(width: 190, height: 10),
                          ],
                        ),
                      ),
                      SizedBox(width: Space.l),
                      SkeletonBox(width: 52, height: 13),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
