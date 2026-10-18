part of '../main.dart';

// ---------------------------------------------------------------------------
// Pedidos, detalle, seguimiento y chat. Server remains the authority for
// status, ETA, driver and payment; these widgets only present it.
// ---------------------------------------------------------------------------

bool _orderComplete(OrderEntry order) => order.status == 'Entregado' || order.status == 'Recogido' || order.status == 'Cancelado';

/// Visual timeline steps mapped from the backend raw status (display only).
List<(String, Set<String>)> _timelineSteps(OrderEntry order) {
  if (order.deliveryMode == 'delivery') {
    return <(String, Set<String>)>[
      ('Recibido', <String>{'received'}),
      ('Confirmado', <String>{'confirmed'}),
      ('Preparando', <String>{'preparing'}),
      ('Listo', <String>{'ready', 'assigned'}),
      ('En camino', <String>{'picked_up', 'on_the_way'}),
      ('Entregado', <String>{'delivered'}),
    ];
  }
  return <(String, Set<String>)>[
    ('Recibido', <String>{'received'}),
    ('Confirmado', <String>{'confirmed'}),
    ('Preparando', <String>{'preparing'}),
    ('Listo para recoger', <String>{'ready', 'assigned', 'picked_up', 'on_the_way'}),
    ('Recogido', <String>{'delivered'}),
  ];
}

int _timelineIndex(OrderEntry order, List<(String, Set<String>)> steps) {
  for (int i = 0; i < steps.length; i++) {
    if (steps[i].$2.contains(order.rawStatus)) return i;
  }
  for (int i = 0; i < steps.length; i++) {
    if (steps[i].$1 == order.status) return i;
  }
  return 0;
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.model});

  final TalaModel model;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool isComplete(OrderEntry order) => _orderComplete(order);

  void _open(OrderEntry order) {
    Navigator.of(context).push(premiumRoute(OrderDetailScreen(model: widget.model, order: order)));
  }

  @override
  Widget build(BuildContext context) {
    final TalaModel model = widget.model;
    final List<OrderEntry> active = model.orders.where((OrderEntry order) => !isComplete(order)).toList();
    final List<OrderEntry> past = model.orders.where(isComplete).toList();
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: kBrand,
        backgroundColor: Colors.white,
        onRefresh: model.refreshOrders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
          children: <Widget>[
            const Text('Pedidos', style: TalaText.display),
            const SizedBox(height: 18),
            if (model.orders.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: StatusView(
                  icon: model.ordersLoadError.isNotEmpty
                      ? Icons.cloud_off_rounded
                      : Icons.receipt_long_outlined,
                  title: model.ordersRefreshing
                      ? 'Cargando tus pedidos'
                      : model.ordersLoadError.isNotEmpty
                          ? 'No pudimos cargar tus pedidos'
                          : 'Aún no tienes pedidos',
                  body: model.ordersLoadError.isNotEmpty
                      ? 'Revisa tu conexión. Puedes intentar actualizar el historial.'
                      : 'Cuando hagas tu primer pedido podrás seguirlo aquí en tiempo real.',
                  actionLabel: model.ordersRefreshing
                      ? null
                      : model.ordersLoadError.isNotEmpty
                          ? 'Reintentar'
                          : 'Explorar restaurantes',
                  onAction: model.ordersRefreshing
                      ? null
                      : model.ordersLoadError.isNotEmpty
                          ? () { model.refreshOrders(); }
                          : () => model.setTab(0),
                ),
              )
            else ...<Widget>[
              if (active.isNotEmpty) ...<Widget>[
                TalaSectionHeader(title: 'En curso', trailing: TalaCountChip(label: '${active.length}')),
                const SizedBox(height: 12),
                for (int i = 0; i < active.length; i++)
                  Reveal(index: i, child: ActiveOrderCard(order: active[i], onTap: () => _open(active[i]))),
                const SizedBox(height: 18),
              ],
              if (past.isNotEmpty) ...<Widget>[
                const TalaSectionHeader(title: 'Anteriores'),
                const SizedBox(height: 12),
                for (int i = 0; i < past.length; i++)
                  Reveal(index: active.length + i, child: PastOrderTile(order: past[i], onTap: () => _open(past[i]))),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class ActiveOrderCard extends StatelessWidget {
  const ActiveOrderCard({super.key, required this.order, required this.onTap});

  final OrderEntry order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<(String, Set<String>)> steps = _timelineSteps(order);
    final int current = _timelineIndex(order, steps);
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 12),
      shadow: true,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints bounds) {
              final bool compact = bounds.maxWidth < 345 ||
                  MediaQuery.textScalerOf(context).scale(14) > 17;
              final Widget merchant = Row(
                children: <Widget>[
                  RestaurantMedia(
                    assetPath: order.restaurant.image,
                    imageUrl: order.restaurant.imageUrl,
                    width: 48, height: 48, radius: 14,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(order.restaurant.name, maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TalaText.title),
                        const SizedBox(height: 2),
                        Text(order.deliveryMode == 'delivery'
                            ? 'Estimado ${order.eta}'
                            : 'Para recoger · ${order.eta}',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TalaText.caption),
                      ],
                    ),
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(width: 8),
                    StatusPill(label: order.status,
                        color: kBrandDeep, background: kSoftOrange),
                  ],
                ],
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  merchant,
                  if (compact) ...<Widget>[
                    const SizedBox(height: 10),
                    StatusPill(label: order.status,
                        color: kBrandDeep, background: kSoftOrange),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'Progreso del pedido: etapa ${current + 1} de ${steps.length}, ${steps[current].$1}',
            child: _SegmentedProgress(total: steps.length, current: current),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: <Widget>[
              Text('Pedido #${order.id} · ${money(order.total)}', style: TalaText.caption),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Ver pedido', style: TextStyle(color: kBrandDeep, fontWeight: FontWeight.w700, fontSize: 13)),
                  Icon(Icons.chevron_right_rounded, color: kBrandDeep, size: 20),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PastOrderTile extends StatelessWidget {
  const PastOrderTile({super.key, required this.order, required this.onTap});

  final OrderEntry order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool cancelled = order.status == 'Cancelado';
    final int items = order.lines.fold<int>(0, (int total, CartLine line) => total + line.quantity);
    final Widget status = StatusPill(
      label: order.status,
      color: cancelled ? kDanger : kGreen,
      background: cancelled ? kDangerSoft : kSoftGreen,
    );
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints bounds) {
          final bool compact = bounds.maxWidth < 345 ||
              MediaQuery.textScalerOf(context).scale(14) > 17;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  RestaurantMedia(
                    assetPath: order.restaurant.image,
                    imageUrl: order.restaurant.imageUrl,
                    width: 48, height: 48, radius: 14,
                    desaturate: cancelled,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(order.restaurant.name,
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TalaText.title.copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('#${order.id} · ${money(order.total)} · $items ${items == 1 ? 'producto' : 'productos'}',
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TalaText.caption),
                      ],
                    ),
                  ),
                  if (!compact) ...<Widget>[
                    const SizedBox(width: 8),
                    status,
                  ],
                ],
              ),
              if (compact) ...<Widget>[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: status),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final Duration d = TalaMotion.of(context, const Duration(milliseconds: 420));
    return Row(
      children: List<Widget>.generate(total, (int i) {
        return Expanded(
          child: AnimatedContainer(
            duration: d,
            curve: TalaMotion.ease,
            height: 5,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
            decoration: BoxDecoration(color: i <= current ? kBrand : kSunken, borderRadius: BorderRadius.circular(99)),
          ),
        );
      }),
    );
  }
}

/// Order timeline. `compact` = segmented bar + current label; otherwise a
/// vertical list of labelled steps.
class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({super.key, required this.order, this.compact = false});

  final OrderEntry order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (order.rawStatus == 'cancelled' || order.status == 'Cancelado') {
      return const Row(
        children: <Widget>[
          Icon(Icons.cancel_outlined, color: kDanger, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text('Este pedido fue cancelado.', style: TextStyle(color: kDanger, fontWeight: FontWeight.w700))),
        ],
      );
    }
    final List<(String, Set<String>)> steps = _timelineSteps(order);
    final int current = _timelineIndex(order, steps);
    final Duration d = TalaMotion.of(context, const Duration(milliseconds: 360));
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SegmentedProgress(total: steps.length, current: current),
          const SizedBox(height: 8),
          Text('Paso ${current + 1} de ${steps.length} · ${steps[current].$1}', style: TalaText.caption),
        ],
      );
    }
    return Column(
      children: List<Widget>.generate(steps.length, (int i) {
        final bool done = i < current;
        final bool now = i == current;
        final bool last = i == steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 26,
              child: Column(
                children: <Widget>[
                  AnimatedContainer(
                    duration: d,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done || (now && last) ? kBrand : (now ? Colors.white : kSunken),
                      border: Border.all(color: done || now ? kBrand : kLineStrong, width: now ? 2.5 : 1.2),
                    ),
                    child: done || (now && last)
                        ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                        : (now ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle))) : null),
                  ),
                  if (!last)
                    AnimatedContainer(
                      duration: d,
                      width: 2,
                      height: 22,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(color: i < current ? kBrand : kLine, borderRadius: BorderRadius.circular(99)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        steps[i].$1,
                        style: TextStyle(
                          color: now ? kInk : (done ? kInkSoft : kSubtle),
                          fontWeight: now ? FontWeight.w800 : FontWeight.w600,
                          fontSize: now ? 15 : 14,
                        ),
                      ),
                    ),
                    if (now && !last) ...<Widget>[
                      const SizedBox(width: 8),
                      const StatusPill(label: 'Ahora', color: kBrandDeep, background: kSoftOrange, dot: false),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.model, required this.order});

  final TalaModel model;
  final OrderEntry order;

  bool get complete => order.status == 'Entregado' || order.status == 'Recogido';

  Future<void> _refresh(BuildContext context) async {
    try {
      await model.refreshOrder(order);
      if (context.mounted) showMessage(context, 'Estado actualizado.');
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          barrierColor: kScrim,
          builder: (BuildContext dialogContext) => AlertDialog(
            backgroundColor: kSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('¿Cancelar este pedido?', style: TalaText.h2),
            content: const Text('El restaurante dejará de prepararlo. Esta acción no se puede deshacer.', style: TalaText.body),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Mantener')),
              FilledButton(
                style: kCompactFilled.copyWith(backgroundColor: const WidgetStatePropertyAll<Color>(kDanger)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Cancelar pedido'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    final bool ok = await model.cancelOrder(order);
    if (context.mounted) showMessage(context, ok ? 'Pedido cancelado.' : model.lastError);
  }

  Future<void> _reorder(BuildContext context) async {
    if (model.cart.isNotEmpty && model.cartRestaurantId != order.restaurant.id) {
      final bool replace = await showDialog<bool>(
            context: context,
            barrierColor: kScrim,
            builder: (BuildContext dialogContext) => AlertDialog(
              backgroundColor: kSurface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('¿Reemplazar tu carrito?', style: TalaText.h2),
              content: const Text('Tu carrito actual se reemplazará con los productos de este pedido.', style: TalaText.body),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
                FilledButton(style: kCompactFilled, onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Reemplazar')),
              ],
            ),
          ) ??
          false;
      if (!replace) return;
    }
    HapticFeedback.mediumImpact();
    model.reorder(order);
    if (context.mounted) Navigator.of(context).push(premiumRoute(CartScreen(model: model)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        final bool delivery = order.deliveryMode == 'delivery';
        final bool cancelled = order.status == 'Cancelado';
        final Restaurant? liveRestaurant = restaurantFor(model, order.restaurant.id);
        final bool canReorder = complete && liveRestaurant != null && liveRestaurant.isOpen && order.lines.isNotEmpty;
        return Scaffold(
          appBar: AppBar(title: Text('Pedido #${order.id}')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: <Widget>[
              Reveal(
                child: TalaCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints bounds) {
                          final bool compact = bounds.maxWidth < 345 ||
                              MediaQuery.textScalerOf(context).scale(14) > 17;
                          final Widget payment = StatusPill(
                            label: paymentStatusLabel(order.paymentStatus),
                            color: order.paymentStatus == 'paid' ? kGreen : kInkSoft,
                            background: order.paymentStatus == 'paid' ? kSoftGreen : kSunken,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  RestaurantMedia(
                                    assetPath: order.restaurant.image,
                                    imageUrl: order.restaurant.imageUrl,
                                    width: 44, height: 44, radius: 12,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(order.restaurant.name,
                                      maxLines: compact ? 2 : 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TalaText.title),
                                  ),
                                  if (!compact) ...<Widget>[
                                    const SizedBox(width: 8),
                                    payment,
                                  ],
                                ],
                              ),
                              if (compact) ...<Widget>[
                                const SizedBox(height: 10),
                                Align(alignment: Alignment.centerRight, child: payment),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(order.status, style: TalaText.h1.copyWith(color: cancelled ? kDanger : kInk)),
                      const SizedBox(height: 4),
                      Text(
                        cancelled
                            ? 'Si se realizó un cobro, el reembolso se gestiona según el estado del pago.'
                            : (delivery ? 'Tiempo estimado ${order.eta}' : 'Te avisaremos cuando esté listo para recoger.'),
                        style: TalaText.muted,
                      ),
                      if (delivery && order.pin.isNotEmpty && !complete && !cancelled) ...<Widget>[
                        const SizedBox(height: 14),
                        _PinBlock(pin: order.pin),
                      ],
                    ],
                  ),
                ),
              ),
              if (!cancelled) ...<Widget>[
                const SizedBox(height: 12),
                Reveal(index: 1, child: TalaCard(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: OrderStatusTimeline(order: order))),
              ],
              if (delivery && !complete && !cancelled) ...<Widget>[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(premiumRoute(TrackingScreen(model: model, order: order))),
                  icon: const Icon(Icons.near_me_rounded),
                  label: const Text('Seguir pedido'),
                ),
              ],
              const SizedBox(height: 22),
              const Text('Productos', style: TalaText.h2),
              const SizedBox(height: 10),
              TalaCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  children: <Widget>[
                    for (final CartLine line in order.lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 30,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: kSoftOrange, borderRadius: BorderRadius.circular(8)),
                              child: Text('${line.quantity}×', style: const TextStyle(color: kBrandDeep, fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(line.item.name, style: const TextStyle(color: kInk, fontWeight: FontWeight.w600)),
                                  if (line.note.trim().isNotEmpty) Text(line.note, style: TalaText.caption),
                                ],
                              ),
                            ),
                            Text(money(line.total), style: const TextStyle(color: kInk, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    const Padding(padding: EdgeInsets.only(bottom: 12), child: Divider()),
                    MoneyRow(label: 'Total', amount: order.total, bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TalaCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(premiumRoute(CustomerOrderAdjustmentsScreen(model: model, order: order))),
                child: const Row(children: <Widget>[
                  CircleAvatar(backgroundColor: kSoftOrange, child: Icon(Icons.rule_rounded, color: kBrand)),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text('Cambios y reembolsos', style: TextStyle(color: kInk, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Sustituciones y ajustes confirmados por el servidor', style: TalaText.caption),
                  ])),
                  Icon(Icons.chevron_right_rounded, color: kSubtle),
                ]),
              ),
              const SizedBox(height: 14),
              TalaCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(premiumRoute(SupportScreen(model: model, orderId: order.id))),
                child: const Row(
                  children: <Widget>[
                    CircleAvatar(backgroundColor: kSoftGreen, child: Icon(Icons.support_agent_rounded, color: kGreen)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('¿Necesitas ayuda?', style: TextStyle(color: kInk, fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text('Escríbenos sobre este pedido', style: TalaText.caption),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: kSubtle),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (!complete) ...<Widget>[
                if (<String>{'received', 'confirmed', 'preparing'}.contains(order.rawStatus)) ...<Widget>[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: kDanger),
                    onPressed: () => _cancel(context),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar pedido'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () => _refresh(context),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar estado'),
                ),
              ] else ...<Widget>[
                FilledButton.icon(
                  onPressed: () => showReviewDialog(context, model, order),
                  icon: const Icon(Icons.star_outline_rounded),
                  label: const Text('Calificar pedido'),
                ),
                if (canReorder) ...<Widget>[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _reorder(context),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Volver a pedir'),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PinBlock extends StatelessWidget {
  const _PinBlock({required this.pin});

  final String pin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: kSoftPeach, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFD9C7))),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('PIN de entrega', style: TextStyle(color: kInk, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Compártelo solo al recibir tu pedido.', style: TalaText.caption),
              ],
            ),
          ),
          Text(pin, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 5, color: kBrandDeep)),
        ],
      ),
    );
  }
}

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.model, required this.order});

  final TalaModel model;
  final OrderEntry order;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with WidgetsBindingObserver {
  Timer? _timer;
  bool refreshing = false;
  bool _foreground = true;
  bool _lastCheckFailed = false;

  OrderEntry get order => widget.order;
  TalaModel get model => widget.model;

  double get progress {
    final List<(String, Set<String>)> steps = _timelineSteps(order);
    final int index = _timelineIndex(order, steps);
    if (steps.length < 2) return 0;
    return (index / (steps.length - 1)).clamp(0.0, 1.0).toDouble();
  }

  bool get terminal => <String>{'Entregado', 'Recogido', 'Cancelado'}.contains(order.status);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _foreground) _refresh(silent: true);
    });
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    if (!_foreground || !mounted || terminal) return;
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_foreground && mounted && !terminal) _refresh(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool nextForeground = state == AppLifecycleState.resumed;
    if (_foreground == nextForeground) return;
    _foreground = nextForeground;
    if (_foreground) {
      _startPolling();
      if (!terminal) _refresh(silent: true);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!mounted || !_foreground || refreshing || terminal) return;
    if (mounted) setState(() => refreshing = true);
    try {
      await model.refreshOrder(order);
      if (mounted) setState(() => _lastCheckFailed = false);
      if (!silent && mounted) showMessage(context, 'Seguimiento actualizado.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _lastCheckFailed = true);
      if (!silent && mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) setState(() => _lastCheckFailed = true);
      if (!silent && mounted) {
        showMessage(context, 'No pudimos comprobar el pedido. Inténtalo de nuevo.');
      }
    } finally {
      if (terminal) {
        _timer?.cancel();
        _timer = null;
      }
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Seguimiento')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: <Widget>[
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: <Widget>[
                  if (!terminal) const LiveBadge() else const StatusPill(label: 'Finalizado', color: kGreen, background: kSoftGreen),
                  AnimatedSwitcher(
                    duration: TalaMotion.of(context, TalaMotion.select),
                    child: refreshing
                        ? const SizedBox(key: ValueKey<String>('r'), width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Estimado ${order.eta}', key: ValueKey<String>(order.eta), maxLines: 2, style: TalaText.caption),
                  ),
                ],
              ),
              if (_lastCheckFailed && !terminal) ...<Widget>[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: TalaCard(
                    color: kSoftPeach,
                    borderColor: const Color(0xFFFFD9C7),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(Icons.sync_problem_rounded, color: kBrandDeep, size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('No pudimos actualizar el seguimiento',
                                    style: TextStyle(color: kInk, fontWeight: FontWeight.w800)),
                                  SizedBox(height: 4),
                                  Text('Se muestra el último estado conocido. No podemos confirmar cambios recientes.',
                                    style: TalaText.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: refreshing ? null : () => _refresh(),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Reintentar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: TalaMotion.of(context, TalaMotion.reveal),
                child: Text(order.status, key: ValueKey<String>(order.status), style: TalaText.h1.copyWith(fontSize: 28)),
              ),
              const SizedBox(height: 2),
              Text(order.restaurant.name, style: TalaText.muted),
              const SizedBox(height: 18),
              RouteProgress(progress: progress, from: order.restaurant.name, to: 'Tu dirección'),
              const SizedBox(height: 12),
              TalaCard(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: OrderStatusTimeline(order: order)),
              const SizedBox(height: 12),
              DriverPremiumCard(order: order),
              if (!terminal && order.pin.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _PinBlock(pin: order.pin),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(premiumRoute(ChatScreen(model: model, order: order))),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Abrir chat del pedido'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: refreshing ? null : () => _refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualizar ahora'),
              ),
              const SizedBox(height: 14),
              const QuietNote(icon: Icons.sync_rounded, text: 'El estado se consulta cuando la app está activa. Esta línea representa etapas, no ubicación GPS en tiempo real.'),
            ],
          ),
        );
      },
    );
  }
}

/// Abstract route (restaurant → you) with the courier positioned by the real
/// order status. Not a map: no invented geography.
class RouteProgress extends StatelessWidget {
  const RouteProgress({super.key, required this.progress, required this.from, required this.to});

  final double progress;
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final Duration d = TalaMotion.of(context, const Duration(milliseconds: 700));
    return TalaCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 46,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double end = 40;
                final double track = constraints.maxWidth - end * 2;
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      left: end,
                      right: end,
                      top: 21,
                      height: 4,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: progress),
                        duration: d,
                        curve: TalaMotion.ease,
                        builder: (BuildContext context, double value, Widget? child) => CustomPaint(painter: _RoutePainter(progress: value)),
                      ),
                    ),
                    const Positioned(left: 0, top: 3, child: _RouteNode(icon: Icons.storefront_rounded, color: kBrand)),
                    const Positioned(right: 0, top: 3, child: _RouteNode(icon: Icons.home_rounded, color: kGreen)),
                    AnimatedPositioned(
                      duration: d,
                      curve: TalaMotion.ease,
                      left: end + track * progress - 21,
                      top: 2,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: kInk,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: kShadowLifted,
                        ),
                        child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 19),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.caption)),
              const SizedBox(width: 12),
              Text(to, style: TalaText.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteNode extends StatelessWidget {
  const _RouteNode({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double y = size.height / 2;
    final Paint pending = Paint()
      ..color = kLineStrong
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const double dash = 7;
    const double gap = 6;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), pending);
      x += dash + gap;
    }
    final Paint done = Paint()
      ..color = kBrand
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, y), Offset(size.width * progress.clamp(0.0, 1.0), y), done);
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => oldDelegate.progress != progress;
}

/// Small "EN VIVO" indicator with a gentle breathing dot (loader-like).
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: kSoftGreen, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SkeletonPulse(child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle))),
          const SizedBox(width: 6),
          const Text('Estado automático', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class DriverPremiumCard extends StatelessWidget {
  const DriverPremiumCard({super.key, required this.order});

  final OrderEntry order;

  @override
  Widget build(BuildContext context) {
    final bool assigned = order.driverName.isNotEmpty;
    final String detail = assigned
        ? <String>[
            order.driverVehicle.isEmpty ? 'Repartidor' : order.driverVehicle,
            if (order.driverRating > 0) '${order.driverRating.toStringAsFixed(1)} ★',
          ].join(' · ')
        : 'Aparecerá aquí en cuanto se asigne.';
    return TalaCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 23,
            backgroundColor: assigned ? kSoftOrange : kSunken,
            child: Icon(assigned ? Icons.person_rounded : Icons.person_outline_rounded, color: assigned ? kBrandDeep : kMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(assigned ? order.driverName : 'Asignando repartidor', style: TalaText.title.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(detail, style: TalaText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.model, required this.order});

  final TalaModel model;
  final OrderEntry order;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
  Timer? _timer;
  bool loading = true;
  bool sending = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) setState(() => loading = true);
    try {
      final dynamic data = await widget.model.api.get('/platform/orders/${widget.order.id}/chat');
      messages
        ..clear()
        ..addAll(List<dynamic>.from(data as List).map((dynamic x) => Map<String, dynamic>.from(x as Map)));
      error = '';
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final String text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final dynamic raw = await widget.model.api.post('/platform/orders/${widget.order.id}/chat', <String, dynamic>{'message': text, 'message_type': 'text', 'media_url': ''});
      messages.add(Map<String, dynamic>.from(raw as Map));
      controller.clear();
      error = '';
      HapticFeedback.lightImpact();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String _time(dynamic raw) {
    final DateTime? dt = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> ordered = messages.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Chat del pedido'),
            Text('#${widget.order.id} · ${widget.order.restaurant.name}', style: TalaText.caption),
          ],
        ),
        actions: <Widget>[IconButton(tooltip: 'Actualizar', onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(
        children: <Widget>[
          if (error.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: AuthNotice(icon: Icons.error_outline_rounded, text: error, danger: true)),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                : messages.isEmpty
                    ? const StatusView(icon: Icons.chat_bubble_outline_rounded, title: 'Aún no hay mensajes', body: 'Escribe aquí para hablar con el equipo de tu pedido.')
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: ordered.length,
                        itemBuilder: (BuildContext context, int index) {
                          final Map<String, dynamic> m = ordered[index];
                          final bool mine = int.tryParse(m['sender_id']?.toString() ?? '') == widget.model.userId;
                          final String time = _time(m['created_at']);
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                                decoration: BoxDecoration(
                                  color: mine ? kBrand : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(mine ? 18 : 6),
                                    bottomRight: Radius.circular(mine ? 6 : 18),
                                  ),
                                  border: mine ? null : Border.all(color: kLine),
                                ),
                                child: Column(
                                  crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text((m['message'] ?? '').toString(), style: TextStyle(color: mine ? Colors.white : kInk, fontSize: 15, height: 1.35)),
                                    if (time.isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 3),
                                      Text(time, style: TextStyle(color: mine ? Colors.white70 : kSubtle, fontSize: 10, fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(color: kSurface, border: Border(top: BorderSide(color: kLine))),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: kLine)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: kLine)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: kBrand, width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: kBrandDeep,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: sending ? null : send,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: sending
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showReviewDialog(BuildContext context, TalaModel model, OrderEntry order) {
  int rating = 5;
  bool sending = false;
  final TextEditingController comment = TextEditingController();
  showDialog<void>(
    context: context,
    barrierColor: kScrim,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext innerContext, void Function(void Function()) setState) {
          return AlertDialog(
            backgroundColor: kSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('¿Cómo estuvo tu pedido?', style: TalaText.h2),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(order.restaurant.name, style: TalaText.muted),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(5, (int i) {
                    final bool on = i < rating;
                    return IconButton(
                      tooltip: '${i + 1} de 5',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => rating = i + 1);
                      },
                      icon: PopIn(
                        key: ValueKey<String>('$i-$on'),
                        from: on ? 0.7 : 1.0,
                        child: Icon(on ? Icons.star_rounded : Icons.star_border_rounded, color: on ? kGold : kSubtle, size: 32),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextField(controller: comment, minLines: 2, maxLines: 4, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Comentario opcional')),
              ],
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Ahora no')),
              FilledButton(
                style: kCompactFilled,
                onPressed: sending
                    ? null
                    : () async {
                        setState(() => sending = true);
                        final bool ok = await model.submitReview(order, rating, comment: comment.text);
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        if (context.mounted) showMessage(context, ok ? 'Gracias por tu reseña.' : model.lastError);
                      },
                child: BusyLabel(busy: sending, label: 'Enviar'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(comment.dispose);
}
