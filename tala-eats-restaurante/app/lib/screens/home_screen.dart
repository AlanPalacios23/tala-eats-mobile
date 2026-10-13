import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../state/operations_controller.dart';
import '../state/session_controller.dart';
import '../widgets/feedback.dart';
import '../widgets/images.dart';
import '../widgets/motion.dart';
import '../widgets/skeleton.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import '../widgets/ticket.dart';
import 'orders/order_widgets.dart';
import 'orders/orders_screen.dart';

/// Inicio: en segundos, ¿estoy abierto?, ¿qué requiere atención?, ¿cómo va
/// el día? y acceso directo a cocina.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.ops,
    required this.session,
    required this.onOpenOrders,
    required this.onOpenMenu,
    required this.onOpenKds,
  });

  final OperationsController ops;
  final SessionController session;
  final ValueChanged<OrdersFilter> onOpenOrders;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenKds;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: ops,
        builder: (context, _) {
          final Widget content;
          if (!ops.hasData && ops.status == LoadStatus.failure) {
            content = Center(
              key: const ValueKey<String>('home-failure'),
              child: SingleChildScrollView(
                child: StateView.failure(ops.loadFailure!, onRetry: ops.retry),
              ),
            );
          } else if (!ops.hasData) {
            content = const _HomeSkeleton(key: ValueKey<String>('home-loading'));
          } else {
            content = _HomeContent(
              key: const ValueKey<String>('home-ready'),
              ops: ops,
              session: session,
              onOpenOrders: onOpenOrders,
              onOpenMenu: onOpenMenu,
              onOpenKds: onOpenKds,
            );
          }
          return StateSwitcher(expand: true, child: content);
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    super.key,
    required this.ops,
    required this.session,
    required this.onOpenOrders,
    required this.onOpenMenu,
    required this.onOpenKds,
  });

  final OperationsController ops;
  final SessionController session;
  final ValueChanged<OrdersFilter> onOpenOrders;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenKds;

  Future<void> _refresh(BuildContext context) async {
    final failure = await ops.refresh();
    if (failure != null && context.mounted) showFailureSnack(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = ops.restaurant!;
    final firstName = session.user?.firstName ?? '';
    final active = ops.activeOrders;

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () => _refresh(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          // Orden operativo: estado del local → pendientes → cocina →
          // pedidos en curso → cifras del día.
          // Entrada escalonada (una sola vez al cargar): cada bloque aparece
          // 55 ms después del anterior. Respeta «reducir movimiento».
          Widget stagger(int step, Widget child) => Entrance(
                delay: Duration(milliseconds: 55 * step),
                offset: const Offset(0, 10),
                child: child,
              );
          final left = <Widget>[
            stagger(0, _StoreStatusCard(ops: ops, restaurant: restaurant)),
            stagger(1, const SectionHeader('Requiere atención')),
            stagger(
              1,
              _AttentionList(
                ops: ops,
                onOpenOrders: onOpenOrders,
                onOpenMenu: onOpenMenu,
                onOpenKds: onOpenKds,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            stagger(2, _KitchenEntry(ops: ops, onOpenKds: onOpenKds)),
          ];
          final right = <Widget>[
            stagger(
              3,
              SectionHeader(
                'En curso',
                padding: EdgeInsets.only(
                  top: wide ? 0 : AppSpace.xxl,
                  bottom: AppSpace.md,
                ),
                trailing: active.isEmpty
                    ? null
                    : SectionLink(
                        label: 'Ver pedidos',
                        onTap: () => onOpenOrders(OrdersFilter.active),
                      ),
              ),
            ),
            stagger(
              3,
              _ActiveOrders(
                ops: ops,
                orders: active,
                onSeeAll: () => onOpenOrders(OrdersFilter.active),
              ),
            ),
            stagger(4, const SectionHeader('Hoy')),
            stagger(4, _TodayMetrics(ops: ops)),
          ];

          return ListView(
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
                  constraints: BoxConstraints(maxWidth: wide ? 1180 : 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Header(
                        greeting: firstName.isEmpty
                            ? greeting()
                            : '${greeting()}, $firstName',
                        date: '${shortWeekday(ClockScope.now(context))} '
                            '${shortDate(ClockScope.now(context))}',
                        restaurant: restaurant,
                      ),
                      const SizedBox(height: AppSpace.xl),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: left,
                              ),
                            ),
                            const SizedBox(width: AppSpace.xxl),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: right,
                              ),
                            ),
                          ],
                        )
                      else ...<Widget>[...left, ...right],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.date,
    required this.restaurant,
  });

  final String greeting;

  /// «Lun 12 oct»: útil en mostrador, donde el día importa.
  final String date;
  final RestaurantInfo restaurant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        AppThumbnail(
          source: restaurant.imagePath,
          size: 52,
          icon: Icons.storefront_outlined,
          radius: 16,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$greeting · $date',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Semantics(
                header: true,
                child: Text(
                  restaurant.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headline.copyWith(fontSize: 25),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreStatusCard extends StatelessWidget {
  const _StoreStatusCard({required this.ops, required this.restaurant});

  final OperationsController ops;
  final RestaurantInfo restaurant;

  Future<void> _toggle(BuildContext context, bool open) async {
    if (!open) {
      final ok = await confirmAction(
        context,
        title: '¿Pausar pedidos?',
        message: 'Tu restaurante dejará de aparecer disponible y no recibirás '
            'pedidos nuevos hasta que vuelvas a abrir. Los pedidos en curso '
            'no se afectan.',
        confirmLabel: 'Pausar pedidos',
        cancelLabel: 'Seguir abierto',
        icon: Icons.pause_circle_outline_rounded,
      );
      if (!ok) return;
    }
    final failure = await ops.setRestaurantOpen(open);
    if (!context.mounted) return;
    if (failure != null) {
      showFailureSnack(context, failure, onRetry: () => _toggle(context, open));
    } else {
      HapticFeedback.selectionClick();
      showAppSnack(
        context,
        open ? 'Restaurante abierto. Ya recibes pedidos.' : 'Pedidos pausados.',
        tone: open ? AlertTone.success : AlertTone.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = restaurant.isOpen;
    final saving = ops.savingOpenState;
    final duration = Motion.of(context, Motion.slow);
    return Semantics(
      container: true,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        decoration: BoxDecoration(
          color: open ? AppColors.greenTint : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: open ? AppColors.green.withValues(alpha: 0.25) : AppColors.line,
          ),
        ),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: duration,
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: open ? AppColors.green : AppColors.inkFaint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SwapText(
                    open ? 'Abierto' : 'Cerrado',
                    style: AppText.headline.copyWith(fontSize: 23),
                  ),
                  const SizedBox(height: 2),
                  SwapText(
                    saving
                        ? 'Guardando…'
                        : open
                            ? 'Recibiendo pedidos'
                            : 'Pedidos nuevos en pausa',
                    style: AppText.caption.copyWith(
                      fontSize: 14,
                      color: open ? AppColors.green : AppColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 64,
              height: 48,
              child: Center(
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: saving
                      ? const SizedBox(
                          key: ValueKey<String>('saving'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : Semantics(
                          key: const ValueKey<String>('storeOpenSwitchLabel'),
                          label: 'Recibir pedidos nuevos',
                          child: Switch(
                            key: const ValueKey<String>('storeOpenSwitch'),
                            value: open,
                            onChanged: (value) => _toggle(context, value),
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

class _AttentionItem {
  const _AttentionItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final AlertTone tone;
  final VoidCallback onTap;
}

class _AttentionList extends StatelessWidget {
  const _AttentionList({
    required this.ops,
    required this.onOpenOrders,
    required this.onOpenMenu,
    required this.onOpenKds,
  });

  final OperationsController ops;
  final ValueChanged<OrdersFilter> onOpenOrders;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenKds;

  List<_AttentionItem> _items(DateTime now) {
    final items = <_AttentionItem>[];
    final incoming = ops.incomingOrders;
    if (incoming.isNotEmpty) {
      final oldest = minutesSince(incoming.first.createdAt, now);
      items.add(_AttentionItem(
        icon: Icons.notifications_active_outlined,
        title: incoming.length == 1
            ? '1 pedido nuevo espera respuesta'
            : '${incoming.length} pedidos nuevos esperan respuesta',
        detail: oldest < 1
            ? 'Acaba de llegar'
            : 'El primero llegó hace ${elapsedLabel(oldest)}',
        tone: AlertTone.warning,
        onTap: () => onOpenOrders(OrdersFilter.incoming),
      ));
    }
    final delayed = ops.kitchenOrders
        .where((o) => UrgencyPolicy.of(o, now) != Urgency.calm)
        .toList();
    if (delayed.isNotEmpty) {
      final worst = delayed.first;
      items.add(_AttentionItem(
        icon: Icons.timer_outlined,
        title: delayed.length == 1
            ? 'Pedido #${worst.id} lleva ${elapsedLabel(minutesSince(worst.createdAt, now))}'
            : '${delayed.length} pedidos llevan más de 20 min',
        detail: 'Revisa la cocina para no retrasar la entrega',
        tone: AlertTone.danger,
        onTap: onOpenKds,
      ));
    }
    final soldOut = ops.unavailableProducts;
    if (soldOut.isNotEmpty) {
      items.add(_AttentionItem(
        icon: Icons.remove_shopping_cart_outlined,
        title: soldOut.length == 1
            ? '${soldOut.first.name} no está disponible'
            : '${soldOut.length} productos no disponibles',
        detail: 'Los clientes no pueden pedirlos',
        tone: AlertTone.danger,
        onTap: onOpenMenu,
      ));
    }
    final low = ops.lowStockProducts;
    if (low.isNotEmpty) {
      items.add(_AttentionItem(
        icon: Icons.inventory_2_outlined,
        title: low.length == 1
            ? '${low.first.name}: quedan ${low.first.stock}'
            : '${low.length} productos con poco stock',
        detail: 'Actualiza el stock antes de que se agoten',
        tone: AlertTone.warning,
        onTap: onOpenMenu,
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(ClockScope.now(context));
    if (items.isEmpty) {
      return const SurfaceCard(
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle_outline_rounded, color: AppColors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Todo en orden. No hay pendientes por ahora.',
                style: AppText.body,
              ),
            ),
          ],
        ),
      );
    }
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const Divider(indent: 68),
            _AttentionRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item});

  final _AttentionItem item;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    switch (item.tone) {
      case AlertTone.danger:
        fg = AppColors.red;
        bg = AppColors.redTint;
        break;
      case AlertTone.warning:
        fg = AppColors.amber;
        bg = AppColors.amberTint;
        break;
      case AlertTone.success:
        fg = AppColors.green;
        bg = AppColors.greenTint;
        break;
      case AlertTone.info:
        fg = AppColors.ink;
        bg = AppColors.sunken;
        break;
    }
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: fg, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.title, style: AppText.subtitle.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(item.detail, style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _TodayMetrics extends StatelessWidget {
  const _TodayMetrics({required this.ops});

  final OperationsController ops;

  @override
  Widget build(BuildContext context) {
    final today = ops.today;
    final gross = today?.grossSales ?? 0;
    final delivered = today?.delivered ?? 0;
    final orders = today?.orders ?? 0;
    final avg = today?.avgTicket ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: MetricTile(
            label: 'Ventas de hoy',
            value: money(gross),
            caption: delivered == 0
                ? 'Sin entregas aún'
                : 'Ticket promedio ${money(avg, cents: false)}',
            emphasis: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricTile(
            label: 'Pedidos de hoy',
            value: '$orders',
            caption: plural(delivered, 'entregado', 'entregados'),
          ),
        ),
      ],
    );
  }
}

class _ActiveOrders extends StatelessWidget {
  const _ActiveOrders({
    required this.ops,
    required this.orders,
    required this.onSeeAll,
  });

  final OperationsController ops;
  final List<RestaurantOrder> orders;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const SurfaceCard(
        child: StateView(
          compact: true,
          icon: Icons.receipt_long_outlined,
          title: 'Sin pedidos en curso',
          message: 'Los pedidos que aceptes aparecerán aquí hasta entregarse.',
        ),
      );
    }
    final ordered = <RestaurantOrder>[
      ...ops.incomingOrders,
      ...ops.kitchenOrders,
      ...ops.readyOrders,
    ];
    final visible = ordered.take(5).toList();
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < visible.length; i++) ...<Widget>[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            CompactOrderRow(
              key: ValueKey<int>(visible[i].id),
              order: visible[i],
              onTap: () => showOrderDetail(context, ops, visible[i].id),
            ),
          ],
          if (orders.length > visible.length) ...<Widget>[
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandText,
                  minimumSize: const Size(44, 48),
                ),
                child: Text(
                  'Ver ${plural(orders.length - visible.length, 'pedido más', 'pedidos más')}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KitchenEntry extends StatelessWidget {
  const _KitchenEntry({required this.ops, required this.onOpenKds});

  final OperationsController ops;
  final VoidCallback onOpenKds;

  @override
  Widget build(BuildContext context) {
    final kitchen = ops.kitchenOrders.length;
    final ready = ops.readyOrders.length;
    final incoming = ops.incomingOrders.length;
    final summary = '${plural(incoming, 'nuevo', 'nuevos')} · '
        '$kitchen en preparación · ${plural(ready, 'listo', 'listos')}';
    return Semantics(
      button: true,
      label: 'Abrir modo cocina',
      child: SurfaceCard(
        color: AppColors.ink,
        borderColor: AppColors.ink,
        onTap: onOpenKds,
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.soup_kitchen_outlined, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Modo cocina',
                    style: AppText.subtitle.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: AppText.caption.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (incoming > 0) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.all(AppRadius.pill),
                ),
                child: Text(
                  incoming == 1 ? '1 nuevo' : '$incoming nuevos',
                  style: AppText.label.copyWith(
                    fontSize: 12.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        AppSpace.lg,
      ),
      children: <Widget>[
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Shimmer(
                  child: Row(
                    children: <Widget>[
                      Bone(width: 52, height: 52, radius: 16),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Bone(width: 120),
                            SizedBox(height: 8),
                            Bone(width: 200, height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                const BoneCard(
                  child: Shimmer(
                    child: Row(
                      children: <Widget>[
                        Bone(width: 12, height: 12, radius: 6),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Bone(width: 110, height: 22),
                              SizedBox(height: 6),
                              Bone(width: 150),
                            ],
                          ),
                        ),
                        Bone(width: 52, height: 30, radius: 15),
                      ],
                    ),
                  ),
                ),
                const SectionHeader('Requiere atención'),
                BoneCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: List<Widget>.generate(
                      2,
                      (i) => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Shimmer(
                          child: Row(
                            children: <Widget>[
                              Bone(width: 40, height: 40, radius: 12),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Bone(height: 15),
                                    SizedBox(height: 6),
                                    Bone(width: 160, height: 12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SectionHeader('Hoy'),
                const Row(
                  children: <Widget>[
                    Expanded(
                      child: BoneCard(
                        child: Shimmer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Bone(width: 90, height: 12),
                              SizedBox(height: 10),
                              Bone(width: 110, height: 24),
                              SizedBox(height: 8),
                              Bone(width: 80, height: 11),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: BoneCard(
                        child: Shimmer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Bone(width: 90, height: 12),
                              SizedBox(height: 10),
                              Bone(width: 40, height: 24),
                              SizedBox(height: 8),
                              Bone(width: 80, height: 11),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
