import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/entities.dart';
import '../../state/operations_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/images.dart';
import '../../widgets/states.dart';
import '../../widgets/surfaces.dart';
import '../../widgets/ticket.dart';

// ---------------------------------------------------------------------------
// Textos y acciones de pedido
// ---------------------------------------------------------------------------

String orderActionLabel(OrderAction action) {
  switch (action) {
    case OrderAction.accept:
      return 'Aceptar pedido';
    case OrderAction.startPreparation:
      return 'Empezar preparación';
    case OrderAction.markReady:
      return 'Marcar como listo';
    case OrderAction.reject:
      return 'Rechazar';
  }
}

String orderActionProgress(OrderAction action) {
  switch (action) {
    case OrderAction.accept:
      return 'Aceptando…';
    case OrderAction.startPreparation:
      return 'Enviando a cocina…';
    case OrderAction.markReady:
      return 'Marcando listo…';
    case OrderAction.reject:
      return 'Rechazando…';
  }
}

String orderActionDone(OrderAction action, int id) {
  switch (action) {
    case OrderAction.accept:
      return 'Pedido #$id aceptado.';
    case OrderAction.startPreparation:
      return 'Pedido #$id en preparación.';
    case OrderAction.markReady:
      return 'Pedido #$id listo para entregar.';
    case OrderAction.reject:
      return 'Pedido #$id rechazado.';
  }
}

AppButtonVariant orderActionVariant(OrderAction action) {
  switch (action) {
    case OrderAction.accept:
      return AppButtonVariant.primary;
    case OrderAction.startPreparation:
      return AppButtonVariant.dark;
    case OrderAction.markReady:
      return AppButtonVariant.success;
    case OrderAction.reject:
      return AppButtonVariant.dangerQuiet;
  }
}

String paymentLabel(RestaurantOrder order) {
  final method = order.paymentMethod == 'cash'
      ? 'Efectivo'
      : order.paymentMethod == 'card'
          ? 'Tarjeta'
          : order.paymentMethod.isEmpty
              ? 'Pago'
              : order.paymentMethod;
  final status = order.isPaid
      ? 'pagado'
      : order.paymentMethod == 'cash'
          ? 'cobrar al entregar'
          : 'pendiente';
  return '$method, $status';
}

String fulfilmentLabel(RestaurantOrder order) =>
    order.isPickup ? 'Recoger en local' : 'Entrega a domicilio';

/// Qué está pasando con un pedido que ya no requiere acción del restaurante.
/// Solo traduce `status`, tipo de pedido y repartidor asignado.
String? orderWaitingLabel(RestaurantOrder order) {
  switch (order.stage) {
    case OrderStage.ready:
      if (order.isPickup) return 'Esperando al cliente';
      return order.driverId == null
          ? 'Esperando repartidor'
          : 'Repartidor asignado, por recoger';
    case OrderStage.outbound:
      return order.isPickup ? 'Entregado al cliente' : 'En camino con el repartidor';
    case OrderStage.incoming:
    case OrderStage.kitchen:
    case OrderStage.closed:
      return null;
  }
}

/// El restaurante cobra en caja: el cliente recoge y paga en efectivo.
/// Solo lee los datos del pedido; no calcula importes.
bool collectsCashAtCounter(RestaurantOrder order) =>
    order.isPickup && order.paymentMethod == 'cash' && !order.isPaid;

/// Ejecuta una acción de pedido con confirmación (si es rechazo), háptica y
/// mensajes de producto. El estado pendiente vive en el controller, por
/// pedido, así que la pantalla no se bloquea.
Future<void> performOrderAction(
  BuildContext context,
  OperationsController ops,
  RestaurantOrder order,
  OrderAction action,
) async {
  if (action == OrderAction.reject) {
    final ok = await confirmAction(
      context,
      title: '¿Rechazar el pedido #${order.id}?',
      message: 'El cliente recibirá un aviso y no podrás recuperarlo. '
          'Hazlo solo si no puedes prepararlo.',
      confirmLabel: 'Rechazar pedido',
      cancelLabel: 'Conservar pedido',
      destructive: true,
      icon: Icons.block_rounded,
    );
    if (!ok) return;
  }
  final failure = await ops.runOrderAction(order, action);
  if (!context.mounted) return;
  if (failure == null) {
    if (action == OrderAction.markReady || action == OrderAction.accept) {
      HapticFeedback.mediumImpact();
    }
    showAppSnack(
      context,
      orderActionDone(action, order.id),
      tone: action == OrderAction.reject ? AlertTone.info : AlertTone.success,
    );
  } else {
    showFailureSnack(
      context,
      failure,
      onRetry: () => performOrderAction(context, ops, order, action),
    );
  }
}

// ---------------------------------------------------------------------------
// Comanda completa (lista de pedidos)
// ---------------------------------------------------------------------------

class OrderTicket extends StatelessWidget {
  const OrderTicket({
    super.key,
    required this.order,
    required this.ops,
    this.notchColor = AppColors.canvas,
  });

  final RestaurantOrder order;
  final OperationsController ops;
  final Color notchColor;

  @override
  Widget build(BuildContext context) {
    final pending = ops.pendingActionFor(order.id);
    final next = order.nextAction;
    final visual = OrderStatusVisual.of(order.status);
    final accent = order.stage == OrderStage.incoming
        ? AppColors.brand
        : order.stage == OrderStage.kitchen
            ? const Color(0xFFE2A33B)
            : order.stage == OrderStage.ready
                ? AppColors.green
                : null;

    return Semantics(
      container: true,
      label: 'Pedido ${order.id}, ${visual.label}',
      child: TicketCard(
        notchColor: notchColor,
        accent: accent,
        dimmed: pending != null,
        onTap: () => showOrderDetail(context, ops, order.id),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('#${order.id}', style: AppText.folio),
                const SizedBox(width: 10),
                Flexible(child: StatusBadge(status: order.status)),
                const Spacer(),
                ElapsedChip(order: order),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  order.recipientName.isEmpty
                      ? 'Cliente'
                      : order.recipientName,
                  style: AppText.label.copyWith(fontSize: 14.5),
                ),
                Tag(
                  label: order.isPickup ? 'Recoger' : 'Entrega',
                  icon: order.isPickup
                      ? Icons.shopping_bag_outlined
                      : Icons.delivery_dining_outlined,
                ),
              ],
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TicketLines(items: order.items, maxVisible: 4),
            if (order.notes.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              OrderNote(text: order.notes),
            ],
          ],
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: collectsCashAtCounter(order)
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Tag(
                            key: ValueKey<String>('collectCash-${order.id}'),
                            label: 'Cobrar en caja',
                            icon: Icons.payments_outlined,
                            foreground: AppColors.amber,
                            background: AppColors.amberTint,
                          ),
                        )
                      : Text(
                          paymentLabel(order),
                          style: AppText.caption,
                        ),
                ),
                Text(
                  money(order.total),
                  style: AppText.subtitle.copyWith(
                    fontSize: 17,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
              ],
            ),
            if (next != null) ...<Widget>[
              const SizedBox(height: 12),
              _ActionRow(
                order: order,
                ops: ops,
                next: next,
                pending: pending,
              ),
            ] else if (orderWaitingLabel(order) != null) ...<Widget>[
              const SizedBox(height: 10),
              _WaitingLine(text: orderWaitingLabel(order)!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.order,
    required this.ops,
    required this.next,
    required this.pending,
  });

  final RestaurantOrder order;
  final OperationsController ops;
  final OrderAction next;
  final OrderAction? pending;

  @override
  Widget build(BuildContext context) {
    final busy = pending != null;
    final primary = AppButton(
      key: ValueKey<String>('orderAction-${order.id}'),
      label: orderActionLabel(next),
      loadingLabel: orderActionProgress(pending ?? next),
      loading: busy && pending != OrderAction.reject,
      variant: orderActionVariant(next),
      size: AppButtonSize.compact,
      onPressed: busy ? null : () => performOrderAction(context, ops, order, next),
    );
    if (!order.canReject) return primary;
    return Row(
      children: <Widget>[
        AppButton(
          label: 'Rechazar',
          loadingLabel: 'Rechazando…',
          loading: pending == OrderAction.reject,
          variant: AppButtonVariant.dangerQuiet,
          size: AppButtonSize.compact,
          expand: false,
          onPressed: busy
              ? null
              : () => performOrderAction(context, ops, order, OrderAction.reject),
        ),
        const SizedBox(width: 10),
        Expanded(child: primary),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fila compacta (Inicio)
// ---------------------------------------------------------------------------

class CompactOrderRow extends StatelessWidget {
  const CompactOrderRow({super.key, required this.order, required this.onTap});

  final RestaurantOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final summary = order.items.isEmpty
        ? fulfilmentLabel(order)
        : '${plural(order.itemCount, 'producto', 'productos')}, '
            '${order.isPickup ? 'recoger' : 'entrega'}';
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 64,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '#${order.id}',
                    maxLines: 1,
                    style: AppText.folio.copyWith(fontSize: 18),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    StatusBadge(status: order.status, dense: true),
                    const SizedBox(height: 5),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElapsedChip(order: order),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detalle de pedido (hoja inferior)
// ---------------------------------------------------------------------------

Future<void> showOrderDetail(
  BuildContext context,
  OperationsController ops,
  int orderId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      // Messenger propio: los avisos de acciones aparecen dentro de la hoja.
      builder: (context, scroll) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: ListenableBuilder(
            listenable: ops,
            builder: (context, _) {
              RestaurantOrder? order;
              for (final o in ops.orders) {
                if (o.id == orderId) order = o;
              }
              if (order == null) {
                return const Center(
                  child: SingleChildScrollView(
                    child: StateView(
                      key: ValueKey<String>('orderDetailGone'),
                      icon: Icons.receipt_long_outlined,
                      title: 'Este pedido ya no está disponible',
                      message: 'Puede que se haya cancelado o cerrado. '
                          'Vuelve a la lista para ver los pedidos activos.',
                    ),
                  ),
                );
              }
              return _OrderDetail(order: order, ops: ops, scroll: scroll);
            },
          ),
        ),
      ),
    ),
  );
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({
    required this.order,
    required this.ops,
    required this.scroll,
  });

  final RestaurantOrder order;
  final OperationsController ops;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final next = order.nextAction;
    final pending = ops.pendingActionFor(order.id);
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Pedido #${order.id}',
                        style: AppText.headline.copyWith(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElapsedChip(order: order, large: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${order.recipientName.isEmpty ? 'Cliente' : order.recipientName}'
                ' · ${plural(order.itemCount, 'producto', 'productos')}'
                ' · ${money(order.total)}',
                style: AppText.bodySoft.copyWith(fontSize: 14.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  StatusBadge(status: order.status),
                  Tag(
                    label: fulfilmentLabel(order),
                    icon: order.isPickup
                        ? Icons.shopping_bag_outlined
                        : Icons.delivery_dining_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OrderTimeline(order: order),
              SectionHeader(
                'Productos',
                trailing: Text(
                  plural(order.itemCount, 'producto', 'productos'),
                  style: AppText.caption,
                ),
              ),
              SurfaceCard(
                padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
                child: _DetailLines(items: order.items, menu: ops.menu),
              ),
              if (order.notes.trim().isNotEmpty) ...<Widget>[
                const SectionHeader('Nota del cliente'),
                OrderNote(text: order.notes),
              ],
              const SectionHeader('Cliente'),
              SurfaceCard(
                child: Column(
                  children: <Widget>[
                    InfoRow(
                      label: 'Nombre',
                      value: order.recipientName.isEmpty
                          ? 'Sin nombre'
                          : order.recipientName,
                    ),
                    if (order.recipientPhone.isNotEmpty)
                      _CopyableRow(
                        label: 'Teléfono',
                        value: order.recipientPhone,
                        copiedMessage: 'Teléfono copiado.',
                      ),
                    InfoRow(
                      label: order.isPickup ? 'Entrega' : 'Dirección',
                      value: order.isPickup ? 'Recoge en el local' : order.address,
                    ),
                    InfoRow(
                      label: 'Recibido',
                      value: order.isActive
                          ? '${clockTime(order.createdAt)} · '
                              '${agoLabel(order.createdAt).toLowerCase()}'
                          : clockTime(order.createdAt),
                    ),
                  ],
                ),
              ),
              const SectionHeader('Pago'),
              if (collectsCashAtCounter(order)) ...<Widget>[
                _CashNotice(total: money(order.total)),
                const SizedBox(height: 10),
              ],
              SurfaceCard(
                child: Column(
                  children: <Widget>[
                    InfoRow(label: 'Método', value: paymentLabel(order)),
                    InfoRow(label: 'Total del pedido', value: money(order.total)),
                    if (order.restaurantPayout > 0)
                      InfoRow(
                        label: 'Ingreso para tu restaurante',
                        value: money(order.restaurantPayout),
                        strong: true,
                        valueColor: AppColors.green,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (next != null)
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.canvas,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: _ActionRow(
                  order: order,
                  ops: ops,
                  next: next,
                  pending: pending,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Aviso de cobro en caja (recoger + efectivo sin pagar).
class _CashNotice extends StatelessWidget {
  const _CashNotice({required this.total});

  final String total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.amberTint,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.payments_outlined, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cobra $total en caja cuando el cliente recoja.',
              style: AppText.label.copyWith(
                fontSize: 14.5,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Línea de tiempo del pedido
// ---------------------------------------------------------------------------

/// Pasos visibles según el tipo de pedido. Solo refleja `status`; no infiere
/// horas ni estados que el backend no haya informado.
List<String> orderTimelineSteps(RestaurantOrder order) => order.isPickup
    ? const <String>[
        'Recibido',
        'Aceptado',
        'En preparación',
        'Listo para recoger',
        'Entregado',
      ]
    : const <String>[
        'Recibido',
        'Aceptado',
        'En preparación',
        'Listo',
        'En camino',
        'Entregado',
      ];

/// Índice del paso actual, o `-1` si el pedido está cancelado.
int orderTimelineIndex(RestaurantOrder order) {
  final last = orderTimelineSteps(order).length - 1;
  switch (order.status) {
    case 'received':
      return 0;
    case 'confirmed':
      return 1;
    case 'preparing':
      return 2;
    case 'ready':
    case 'assigned':
      return 3;
    case 'picked_up':
    case 'on_the_way':
      return order.isPickup ? last : 4;
    case 'delivered':
      return last;
    case 'cancelled':
      return -1;
    default:
      return 0;
  }
}

/// Barra de progreso segmentada + paso actual y siguiente.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.order});

  final RestaurantOrder order;

  @override
  Widget build(BuildContext context) {
    final steps = orderTimelineSteps(order);
    final index = orderTimelineIndex(order);
    if (index < 0) {
      return Semantics(
        label: 'Pedido cancelado',
        excludeSemantics: true,
        child: Container(
          key: const ValueKey<String>('orderTimeline'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.redTint,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.block_rounded, color: AppColors.red, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pedido cancelado',
                  style: AppText.label.copyWith(
                    fontSize: 14.5,
                    color: AppColors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final done = index == steps.length - 1;
    final assigned = order.status == 'assigned';
    final current = assigned ? 'Listo · repartidor asignado' : steps[index];
    final next = done ? null : steps[index + 1];
    final duration = Motion.of(context, Motion.slow);
    return Semantics(
      label: 'Progreso del pedido: paso ${index + 1} de ${steps.length}, '
          '$current${next == null ? '' : '. Siguiente: $next'}',
      excludeSemantics: true,
      child: Column(
        key: const ValueKey<String>('orderTimeline'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (var i = 0; i < steps.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < index || done
                          ? AppColors.green
                          : i == index
                              ? AppColors.brand
                              : AppColors.sunken,
                      borderRadius: const BorderRadius.all(AppRadius.pill),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Paso ${index + 1} de ${steps.length}',
                      style: AppText.caption.copyWith(fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current,
                      style: AppText.subtitle.copyWith(fontSize: 15.5),
                    ),
                  ],
                ),
              ),
              if (next != null) ...<Widget>[
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'Siguiente',
                        style: AppText.caption.copyWith(fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next,
                        textAlign: TextAlign.right,
                        style: AppText.label.copyWith(
                          fontSize: 14,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Estado de espera de un pedido sin acción pendiente (listo, en camino).
class _WaitingLine extends StatelessWidget {
  const _WaitingLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.hourglass_bottom_rounded,
            size: 18,
            color: AppColors.inkSoft,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppText.label.copyWith(
                fontSize: 14,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de detalle con botón para copiar (p. ej. el teléfono del cliente).
class _CopyableRow extends StatelessWidget {
  const _CopyableRow({
    required this.label,
    required this.value,
    required this.copiedMessage,
  });

  final String label;
  final String value;
  final String copiedMessage;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    HapticFeedback.selectionClick();
    showAppSnack(context, copiedMessage, tone: AlertTone.success);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: AppText.bodySoft)),
        const SizedBox(width: AppSpace.md),
        Flexible(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copiar ${label.toLowerCase()}',
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_rounded, size: 19),
        ),
      ],
    );
  }
}

/// Productos del pedido con la foto del catálogo (si el producto sigue en el
/// menú). Cantidad destacada, extras debajo; sin precios por línea.
class _DetailLines extends StatelessWidget {
  const _DetailLines({required this.items, required this.menu});

  final List<OrderLine> items;
  final List<MenuProduct> menu;

  MenuProduct? _productFor(OrderLine line) {
    final id = line.menuItemId;
    if (id == null) return null;
    for (final product in menu) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Sin productos en este pedido.', style: AppText.bodySoft),
      );
    }
    return Column(
      children: <Widget>[
        for (var i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) const Divider(indent: 56),
          _DetailLine(line: items[i], product: _productFor(items[i])),
        ],
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.line, required this.product});

  final OrderLine line;
  final MenuProduct? product;

  @override
  Widget build(BuildContext context) {
    final options = line.options.trim();
    return Semantics(
      label: '${line.quantity} ${line.name}'
          '${options.isEmpty ? '' : ', $options'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppThumbnail(
              source: product?.imagePath ?? '',
              size: 44,
              radius: 12,
              icon: categoryIcon(product?.category ?? ''),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${line.quantity}×',
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.25,
                  color: AppColors.ink,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      line.name,
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    if (options.isNotEmpty)
                      Text(options, style: AppText.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
