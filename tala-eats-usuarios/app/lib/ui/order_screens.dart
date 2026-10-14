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
    final List<OrderEntry> pending = model.orders.where((OrderEntry order) => !isComplete(order) && order.isAwaitingOnlinePayment).toList();
    final List<OrderEntry> active = model.orders.where((OrderEntry order) => !isComplete(order) && !order.isAwaitingOnlinePayment).toList();
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
                  icon: Icons.receipt_long_outlined,
                  title: 'Aún no tienes pedidos',
                  body: 'Cuando hagas tu primer pedido podrás consultar su estado aquí.',
                  actionLabel: 'Explorar restaurantes',
                  onAction: () => model.setTab(0),
                ),
              )
            else ...<Widget>[
              if (pending.isNotEmpty) ...<Widget>[
                TalaSectionHeader(
                  title: 'Pendientes de pago',
                  trailing: TalaCountChip(label: '${pending.length}'),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < pending.length; i++)
                  PendingPaymentOrderCard(order: pending[i], onTap: () => _open(pending[i])),
                const SizedBox(height: 18),
              ],
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
                  Reveal(index: pending.length + active.length + i, child: PastOrderTile(order: past[i], onTap: () => _open(past[i]))),
              ],
            ],
          ],
        ),
      ),
    );
  }
}


class PendingPaymentOrderCard extends StatelessWidget {
  const PendingPaymentOrderCard({super.key, required this.order, required this.onTap});

  final OrderEntry order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kSoftOrange,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.lock_clock_rounded, color: kBrandDeep, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      order.restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TalaText.title,
                    ),
                    const SizedBox(height: 3),
                    Text('Pedido #${order.id} · ${money(order.total)}', style: TalaText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const QuietNote(
            icon: Icons.info_outline_rounded,
            text: 'El restaurante comenzará a preparar tu pedido cuando se confirme el pago.',
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Pago sin confirmar',
                  style: TextStyle(color: kBrandDeep, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const Text(
                'Revisar pedido',
                style: TextStyle(color: kBrandDeep, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Icon(Icons.chevron_right_rounded, color: kBrandDeep, size: 19),
            ],
          ),
        ],
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
          Row(
            children: <Widget>[
              RestaurantMedia(assetPath: order.restaurant.image, imageUrl: order.restaurant.imageUrl, width: 48, height: 48, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(order.restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.title),
                    const SizedBox(height: 2),
                    Text(order.deliveryMode == 'delivery' ? 'Estimado ${order.eta}' : 'Para recoger · ${order.eta}', style: TalaText.caption),
                  ],
                ),
              ),
              StatusPill(label: order.status, color: kBrandDeep, background: kSoftOrange),
            ],
          ),
          const SizedBox(height: 14),
          _SegmentedProgress(total: steps.length, current: current),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(child: Text('Pedido #${order.id} · ${money(order.total)}', style: TalaText.caption)),
              const Text('Ver pedido', style: TextStyle(color: kBrandDeep, fontWeight: FontWeight.w700, fontSize: 13)),
              const Icon(Icons.chevron_right_rounded, color: kBrandDeep, size: 20),
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
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          RestaurantMedia(assetPath: order.restaurant.image, imageUrl: order.restaurant.imageUrl, width: 48, height: 48, radius: 14, desaturate: cancelled),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(order.restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.title.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('#${order.id} · ${money(order.total)} · $items ${items == 1 ? 'producto' : 'productos'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(
            label: order.status,
            color: cancelled ? kDanger : kGreen,
            background: cancelled ? kDangerSoft : kSoftGreen,
          ),
        ],
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
                      Row(
                        children: <Widget>[
                          RestaurantMedia(assetPath: order.restaurant.image, imageUrl: order.restaurant.imageUrl, width: 44, height: 44, radius: 12),
                          const SizedBox(width: 12),
                          Expanded(child: Text(order.restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.title)),
                          StatusPill(
                            label: paymentStatusLabel(order.paymentStatus),
                            color: order.paymentStatus == 'paid' ? kGreen : kInkSoft,
                            background: order.paymentStatus == 'paid' ? kSoftGreen : kSunken,
                          ),
                        ],
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
              if (order.isAwaitingOnlinePayment && !cancelled) ...<Widget>[
                const SizedBox(height: 14),
                const AuthNotice(
                  icon: Icons.lock_clock_rounded,
                  text: 'El pago aún no está confirmado. El restaurante no empezará a preparar este pedido hasta que se autorice.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    premiumRoute(PaymentStatusScreen(model: model, order: order)),
                  ),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Revisar estado del pago'),
                ),
              ] else if (delivery && !complete && !cancelled) ...<Widget>[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    premiumRoute(TrackingScreen(model: model, order: order)),
                  ),
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

  OrderEntry get order => widget.order;
  TalaModel get model => widget.model;

  bool get terminal => <String>{'Entregado', 'Recogido', 'Cancelado'}.contains(order.status);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(silent: true));
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_foreground && !terminal) _refresh(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool active = state == AppLifecycleState.resumed;
    final bool wasActive = _foreground;
    _foreground = active;
    if (active && !wasActive && !terminal) _refresh(silent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (refreshing || terminal || !_foreground || !mounted) return;
    if (mounted) setState(() => refreshing = true);
    try {
      await model.refreshOrder(order);
      if (!silent && mounted) showMessage(context, 'Seguimiento actualizado.');
    } on ApiException catch (e) {
      if (!silent && mounted) showMessage(context, e.message);
    } finally {
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
              Row(
                children: <Widget>[
                  Flexible(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: !terminal
                          ? const LiveBadge()
                          : const StatusPill(label: 'Finalizado', color: kGreen, background: kSoftGreen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedSwitcher(
                        duration: TalaMotion.of(context, TalaMotion.select),
                        child: refreshing
                            ? const SizedBox(
                                key: ValueKey<String>('r'),
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Estimado ${order.eta}',
                                key: ValueKey<String>(order.eta),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TalaText.caption,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: TalaMotion.of(context, TalaMotion.reveal),
                child: Text(order.status, key: ValueKey<String>(order.status), style: TalaText.h1.copyWith(fontSize: 28)),
              ),
              const SizedBox(height: 2),
              Text(order.restaurant.name, style: TalaText.muted),
              const SizedBox(height: 18),
              if (order.canShowTrackingMap)
                DriverTrackingMap(order: order)
              else if (!terminal)
                TalaCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.hourglass_top_rounded, color: kBrandDeep),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Esperando confirmación del restaurante. El mapa se mostrará cuando el pedido avance.',
                          style: TalaText.body,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              TalaCard(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: OrderStatusTimeline(order: order)),
              const SizedBox(height: 12),
              if (order.deliveryMode == 'delivery') ...<Widget>[
                DriverPremiumCard(order: order),
                if (order.pin.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _PinBlock(pin: order.pin),
                ],
                const SizedBox(height: 14),
                if (order.canContactDriver) ...<Widget>[
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(premiumRoute(ChatScreen(model: model, order: order))),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Ver chat con mi repartidor'),
                  ),
                  const SizedBox(height: 8),
                  const QuietNote(
                    icon: Icons.lock_outline_rounded,
                    text: 'Vista previa del chat privado. El envío se habilitará cuando el backend esté preparado.',
                  ),
                ] else if (!terminal) ...<Widget>[
                  TalaCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.mark_chat_unread_outlined, color: kBrandDeep),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Podrás contactar a tu repartidor cuando esté asignado.',
                            style: TalaText.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: refreshing ? null : () => _refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualizar ahora'),
              ),
              const SizedBox(height: 14),
              const QuietNote(icon: Icons.sync_rounded, text: 'Esta pantalla se actualiza sola mientras la tienes abierta.'),
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
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Flexible(
            child: Text(
              'Actualización periódica',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
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
    final bool assigned = order.driverId > 0;
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
                Text(
                  assigned ? (order.driverName.trim().isEmpty ? 'Tu repartidor' : order.driverName) : 'Buscando repartidor',
                  style: TalaText.title.copyWith(fontSize: 15),
                ),
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

/// Vista previa de chat EXCLUSIVO con repartidor.
/// No se llama al endpoint heredado /platform/orders/{id}/chat: actualmente
/// permite acceso al comercio y no garantiza privacidad cliente-repartidor.
/// El compositor se habilitará en una versión posterior cuando exista el
/// contrato privado con controles de rol en el backend y la app de Repartidor.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.model, required this.order});

  final TalaModel model;
  final OrderEntry order;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        final bool assigned = order.canContactDriver;
        final String name = order.driverName.trim().isEmpty ? 'Tu repartidor' : order.driverName;
        return Scaffold(
          backgroundColor: kBackground,
          appBar: AppBar(
            title: const Text('Chat con tu repartidor'),
          ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TalaCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: assigned ? kSoftOrange : kSunken,
                          child: Icon(assigned ? Icons.delivery_dining_rounded : Icons.lock_outline_rounded,
                              color: assigned ? kBrandDeep : kMuted, size: 27),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(assigned ? name : 'Conversación no disponible',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.title),
                              const SizedBox(height: 4),
                              Text('Pedido #${order.id} · ${order.restaurant.name}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.caption),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const StatusPill(
                          label: 'Vista previa',
                          color: kBrandDeep,
                          background: kSoftOrange,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              height: 88,
                              width: 88,
                              decoration: BoxDecoration(
                                color: kSoftOrange,
                                shape: BoxShape.circle,
                                border: Border.all(color: kLine),
                              ),
                              child: const Icon(Icons.chat_bubble_outline_rounded, color: kBrandDeep, size: 38),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              assigned ? 'Comunícate con quien lleva tu pedido' : 'Esperando un repartidor',
                              textAlign: TextAlign.center,
                              style: TalaText.h2,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              assigned
                                  ? 'Aquí podrás escribir a ${name} cuando activemos el canal privado entre cliente y repartidor.'
                                  : 'El chat estará disponible después de que el servidor confirme una asignación.',
                              textAlign: TextAlign.center,
                              style: TalaText.body,
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: kLine),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.shield_outlined, color: kBrandDeep, size: 18),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Sin mensajes de demostración ni envíos al restaurante.',
                                      style: TalaText.caption,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: kSurface,
                    border: Border(top: BorderSide(color: kLine)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                enabled: false,
                                maxLines: 1,
                                decoration: InputDecoration(
                                  hintText: 'Mensajes disponibles próximamente',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const IconButton.filled(
                              onPressed: null,
                              tooltip: 'Envío pendiente de activar',
                              icon: Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chat privado pendiente de activación en el backend.',
                          textAlign: TextAlign.center,
                          style: TalaText.caption,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
