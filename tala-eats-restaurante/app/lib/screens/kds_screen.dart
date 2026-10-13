import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../state/operations_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import '../widgets/surfaces.dart';
import '../widgets/ticket.dart';
import 'orders/order_widgets.dart';

enum _Lane { incoming, kitchen, ready }

extension on _Lane {
  String get title {
    switch (this) {
      case _Lane.incoming:
        return 'Nuevos';
      case _Lane.kitchen:
        return 'Preparando';
      case _Lane.ready:
        return 'Listos';
    }
  }

  Color get color {
    switch (this) {
      case _Lane.incoming:
        return AppColors.brand;
      case _Lane.kitchen:
        return const Color(0xFFE2A33B);
      case _Lane.ready:
        return const Color(0xFF3FB97A);
    }
  }

  IconData get icon {
    switch (this) {
      case _Lane.incoming:
        return Icons.notifications_active_outlined;
      case _Lane.kitchen:
        return Icons.soup_kitchen_outlined;
      case _Lane.ready:
        return Icons.check_circle_outline_rounded;
    }
  }
}

/// Modo cocina: riel oscuro con comandas claras, legibles a distancia.
/// Teléfono y tablet estrecha: un carril a la vez. Pantallas >=1024: tres carriles.
class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key, required this.ops});

  final OperationsController ops;

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> {
  _Lane _lane = _Lane.incoming;

  OperationsController get ops => widget.ops;

  List<RestaurantOrder> _ordersFor(_Lane lane) {
    switch (lane) {
      case _Lane.incoming:
        return ops.incomingOrders;
      case _Lane.kitchen:
        return ops.kitchenOrders;
      case _Lane.ready:
        return ops.readyOrders;
    }
  }

  Future<void> _refresh() async {
    final failure = await ops.refresh();
    if (failure != null && mounted) showFailureSnack(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    // Fondo oscuro: íconos claros en la barra de estado y de navegación
    // (sin esto la hora y la batería no se ven en cocina).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.kdsBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ClockProvider(
        child: Scaffold(
          backgroundColor: AppColors.kdsBackground,
          body: SafeArea(
            child: ListenableBuilder(
              listenable: ops,
              builder: (context, _) {
                return Column(
                  children: <Widget>[
                    _TopBar(
                      ops: ops,
                      onBack: () => Navigator.of(context).maybePop(),
                      onRefresh: _refresh,
                    ),
                    Expanded(child: _body(context)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (!ops.hasData) {
      final failure = ops.loadFailure;
      if (ops.status == LoadStatus.failure && failure != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  failure.title,
                  textAlign: TextAlign.center,
                  style: AppText.title.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  failure.message,
                  textAlign: TextAlign.center,
                  style: AppText.bodySoft.copyWith(color: AppColors.kdsMuted),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Reintentar',
                  expand: false,
                  onPressed: ops.retry,
                ),
              ],
            ),
          ),
        );
      }
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Colors.white,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1024;
        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final lane in _Lane.values) ...<Widget>[
                  if (lane != _Lane.incoming) const SizedBox(width: 12),
                  Expanded(
                    child: _LaneColumn(
                      lane: lane,
                      orders: _ordersFor(lane),
                      ops: ops,
                      showHeader: true,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(
          children: <Widget>[
            _LaneTabs(
              selected: _lane,
              countOf: (lane) => _ordersFor(lane).length,
              onSelect: (lane) => setState(() => _lane = lane),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _LaneColumn(
                  key: ValueKey<_Lane>(_lane),
                  lane: _lane,
                  orders: _ordersFor(_lane),
                  ops: ops,
                  showHeader: false,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.ops,
    required this.onBack,
    required this.onRefresh,
  });

  final OperationsController ops;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final now = ClockScope.now(context);
    final oldest = ops.oldestKitchenOrder;
    final sync = ops.hasData ? ops.syncFailure : null;
    final last = ops.lastSyncAt;
    // En cocina no se ve el aviso del panel: si la sincronización falla, el
    // subtítulo lo dice para no cocinar con datos viejos sin saberlo.
    final String status;
    if (sync == null) {
      status = oldest == null
          ? 'Sin pedidos en preparación'
          : 'Más antiguo en cocina: ${elapsedLabel(minutesSince(oldest.createdAt, now))}';
    } else if (sync.isConnectivity) {
      status = last == null
          ? 'Sin conexión'
          : 'Sin conexión · datos de las ${clockTime(last)}';
    } else {
      status = 'No se pudo actualizar · toca Actualizar';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: <Widget>[
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Salir de cocina',
            onPressed: onBack,
            dark: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    'Cocina',
                    style: AppText.headline.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                Semantics(
                  liveRegion: sync != null,
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: sync == null
                          ? AppColors.kdsMuted
                          : const Color(0xFFFFC874),
                      fontWeight:
                          sync == null ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Hora actual ${clockTime(now)}',
            excludeSemantics: true,
            child: Text(
              clockTime(now),
              style: AppText.figure.copyWith(color: Colors.white, fontSize: 24),
            ),
          ),
          const SizedBox(width: 12),
          AppIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            busy: ops.refreshing,
            dark: true,
          ),
        ],
      ),
    );
  }
}

class _LaneTabs extends StatelessWidget {
  const _LaneTabs({
    required this.selected,
    required this.countOf,
    required this.onSelect,
  });

  final _Lane selected;
  final int Function(_Lane) countOf;
  final ValueChanged<_Lane> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.kdsRail,
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
        ),
        child: Row(
          children: <Widget>[
            for (final lane in _Lane.values)
              Expanded(
                child: Semantics(
                  selected: lane == selected,
                  button: true,
                  label: '${lane.title}, ${countOf(lane)}',
                  excludeSemantics: true,
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.base),
                    decoration: BoxDecoration(
                      color: lane == selected
                          ? AppColors.kdsPaper
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md - 2),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md - 2),
                        onTap: () => onSelect(lane),
                        child: SizedBox(
                          height: 52,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: lane.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  lane.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.label.copyWith(
                                    fontSize: 15,
                                    color: lane == selected
                                        ? AppColors.ink
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${countOf(lane)}',
                                style: AppText.label.copyWith(
                                  fontSize: 15,
                                  fontFeatures: AppFonts.tabular,
                                  color: lane == selected
                                      ? AppColors.inkSoft
                                      : AppColors.kdsMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LaneColumn extends StatelessWidget {
  const _LaneColumn({
    super.key,
    required this.lane,
    required this.orders,
    required this.ops,
    required this.showHeader,
  });

  final _Lane lane;
  final List<RestaurantOrder> orders;
  final OperationsController ops;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.kdsRail,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: lane.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lane.title,
                      style: AppText.title.copyWith(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Text(
                    '${orders.length}',
                    style: AppText.figure.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: orders.isEmpty
                ? _EmptyLane(lane: lane)
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      showHeader ? 0 : 12,
                      12,
                      16,
                    ),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Padding(
                        key: ValueKey<int>(order.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _KdsTicket(order: order, ops: ops),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLane extends StatelessWidget {
  const _EmptyLane({required this.lane});

  final _Lane lane;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(lane.icon, color: AppColors.kdsMuted, size: 32),
            const SizedBox(height: 10),
            Text(
              'Sin pedidos ${lane.title.toLowerCase()}',
              textAlign: TextAlign.center,
              style: AppText.subtitle.copyWith(color: AppColors.kdsMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _KdsTicket extends StatelessWidget {
  const _KdsTicket({required this.order, required this.ops});

  final RestaurantOrder order;
  final OperationsController ops;

  String get _actionLabel {
    switch (order.nextAction) {
      case OrderAction.accept:
        return 'Aceptar';
      case OrderAction.startPreparation:
        return 'Empezar';
      case OrderAction.markReady:
        return 'Listo';
      case OrderAction.reject:
      case null:
        return '';
    }
  }

  /// Franja superior: color del carril si va a tiempo, ámbar si requiere
  /// atención y rojo si está demorado (se lee a distancia).
  Color _accent(Urgency urgency) {
    switch (urgency) {
      case Urgency.critical:
        return AppColors.red;
      case Urgency.attention:
        return const Color(0xFFF08C00);
      case Urgency.calm:
        return _stageColor();
    }
  }

  Color _stageColor() {
    switch (order.stage) {
      case OrderStage.incoming:
        return AppColors.brand;
      case OrderStage.kitchen:
        return const Color(0xFFE2A33B);
      case OrderStage.ready:
        return const Color(0xFF3FB97A);
      case OrderStage.outbound:
      case OrderStage.closed:
        return const Color(0xFFD9D7CF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = order.nextAction;
    final pending = ops.pendingActionFor(order.id);
    final urgency = UrgencyPolicy.of(order, ClockScope.now(context));
    final pickupName = order.isPickup && order.recipientName.trim().isNotEmpty
        ? order.recipientName.trim()
        : null;
    return Semantics(
      container: true,
      label: 'Comanda ${order.id}'
          '${urgency == Urgency.critical ? ', demorada' : ''}',
      child: TicketCard(
        paper: AppColors.kdsPaper,
        edge: const Color(0xFFD9D7CF),
        notchColor: AppColors.kdsRail,
        accent: _accent(urgency),
        dimmed: pending != null,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '#${order.id}',
                  style: AppText.folio.copyWith(fontSize: 30),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Tag(
                    label: order.isPickup ? 'Recoger' : 'Entrega',
                    icon: order.isPickup
                        ? Icons.shopping_bag_outlined
                        : Icons.delivery_dining_outlined,
                    background: const Color(0xFFE6E5DF),
                    foreground: AppColors.ink,
                  ),
                ),
                const Spacer(),
                ElapsedChip(order: order, large: true, onDark: true),
              ],
            ),
            if (pickupName != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Recoge: $pickupName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.subtitle.copyWith(fontSize: 17),
              ),
            ],
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 4),
            TicketLines(items: order.items, large: true),
            if (order.notes.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              OrderNote(text: order.notes, large: true),
            ],
          ],
        ),
        footer: next == null
            ? Row(
                children: <Widget>[
                  const Icon(
                    Icons.hourglass_bottom_rounded,
                    size: 20,
                    color: AppColors.inkSoft,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      orderWaitingLabel(order) ?? 'Sin acción pendiente',
                      style: AppText.subtitle.copyWith(color: AppColors.inkSoft),
                    ),
                  ),
                ],
              )
            : AppButton(
                key: ValueKey<String>('kdsAction-${order.id}'),
                label: _actionLabel,
                loadingLabel: orderActionProgress(next),
                loading: pending != null,
                size: AppButtonSize.large,
                variant: orderActionVariant(next),
                onPressed: pending != null
                    ? null
                    : () => performOrderAction(context, ops, order, next),
              ),
      ),
    );
  }
}
