import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/entities.dart';
import '../../state/operations_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/motion.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/states.dart';
import '../../widgets/surfaces.dart';
import 'order_widgets.dart';

enum OrdersFilter { active, incoming, kitchen, ready, history }

extension on OrdersFilter {
  String get label {
    switch (this) {
      case OrdersFilter.active:
        return 'Activos';
      case OrdersFilter.incoming:
        return 'Nuevos';
      case OrdersFilter.kitchen:
        return 'En cocina';
      case OrdersFilter.ready:
        return 'Listos';
      case OrdersFilter.history:
        return 'Historial';
    }
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({
    super.key,
    required this.ops,
    required this.filter,
    required this.onOpenKds,
  });

  final OperationsController ops;
  final ValueNotifier<OrdersFilter> filter;
  final VoidCallback onOpenKds;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[ops, filter]),
        builder: (context, _) {
          final Widget content;
          if (!ops.hasData && ops.status == LoadStatus.failure) {
            content = Center(
              key: const ValueKey<String>('orders-failure'),
              child: SingleChildScrollView(
                child: StateView.failure(ops.loadFailure!, onRetry: ops.retry),
              ),
            );
          } else if (!ops.hasData) {
            content = const _OrdersSkeleton(key: ValueKey<String>('orders-loading'));
          } else {
            content = _OrdersList(
              key: const ValueKey<String>('orders-ready'),
              ops: ops,
              filter: filter,
              onOpenKds: onOpenKds,
            );
          }
          return StateSwitcher(expand: true, child: content);
        },
      ),
    );
  }
}

class _OrdersList extends StatefulWidget {
  const _OrdersList({
    super.key,
    required this.ops,
    required this.filter,
    required this.onOpenKds,
  });

  final OperationsController ops;
  final ValueNotifier<OrdersFilter> filter;
  final VoidCallback onOpenKds;

  @override
  State<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<_OrdersList> {
  final _search = TextEditingController();
  final _ordersScroll = ScrollController();
  String _query = '';

  OperationsController get ops => widget.ops;
  ValueNotifier<OrdersFilter> get filter => widget.filter;
  VoidCallback get onOpenKds => widget.onOpenKds;

  @override
  void dispose() {
    _search.dispose();
    _ordersScroll.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
    // Después de una búsqueda vacía la lista estaba desplazada hacia abajo:
    // volvemos al principio para mostrar los pedidos recuperados.
    if (_ordersScroll.hasClients) {
      _ordersScroll.jumpTo(0);
    }
  }

  /// Búsqueda local en el historial ya cargado: por folio (con o sin «#») o
  /// por nombre del cliente. No hace solicitudes nuevas.
  List<RestaurantOrder> _searchHistory(String raw) {
    final q = raw.trim().toLowerCase().replaceAll('#', '');
    if (q.isEmpty) return ops.historyOrders;
    return ops.historyOrders
        .where(
          (o) =>
              '${o.id}'.contains(q) ||
              o.recipientName.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  int _count(OrdersFilter f) {
    switch (f) {
      case OrdersFilter.active:
        return ops.activeOrders.length;
      case OrdersFilter.incoming:
        return ops.incomingOrders.length;
      case OrdersFilter.kitchen:
        return ops.kitchenOrders.length;
      case OrdersFilter.ready:
        return ops.readyOrders.length;
      case OrdersFilter.history:
        return ops.historyOrders.length;
    }
  }

  List<Object> _entries(OrdersFilter f) {
    switch (f) {
      case OrdersFilter.active:
        final entries = <Object>[];
        void group(String title, List<RestaurantOrder> list) {
          if (list.isEmpty) return;
          entries.add(_GroupTitle(title, list.length));
          entries.addAll(list);
        }
        group('Nuevos', ops.incomingOrders);
        group('En cocina', ops.kitchenOrders);
        group('Listos para entregar', ops.readyOrders);
        group(
          'En camino',
          ops.activeOrders
              .where((o) => o.stage == OrderStage.outbound)
              .toList(),
        );
        return entries;
      case OrdersFilter.incoming:
        return ops.incomingOrders;
      case OrdersFilter.kitchen:
        return ops.kitchenOrders;
      case OrdersFilter.ready:
        return ops.readyOrders;
      case OrdersFilter.history:
        return _searchHistory(_query);
    }
  }

  Future<void> _refresh(BuildContext context) async {
    final failure = await ops.refresh();
    if (failure != null && context.mounted) {
      showFailureSnack(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = filter.value;
    final entries = _entries(current);
    final activeCount = ops.activeOrders.length;
    final last = ops.lastSyncAt;
    final synced = last == null ? '' : ' · actualizado ${clockTime(last)}';
    final searching =
        current == OrdersFilter.history && _query.trim().isNotEmpty;

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () => _refresh(context),
      child: CustomScrollView(
        controller: _ordersScroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _Constrained(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.lg,
                  AppSpace.gutter,
                  AppSpace.md,
                ),
                child: ScreenHeader(
                  title: 'Pedidos',
                  subtitle: activeCount == 0
                      ? 'Sin pedidos activos$synced'
                      : '${plural(activeCount, 'pedido activo', 'pedidos activos')}$synced',
                  trailing: AppIconButton(
                    icon: Icons.soup_kitchen_outlined,
                    tooltip: 'Abrir modo cocina',
                    onPressed: onOpenKds,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Constrained(
              child: _FilterBar(
                selected: current,
                countOf: _count,
                onSelect: (f) => filter.value = f,
              ),
            ),
          ),
          if (current == OrdersFilter.history && ops.historyOrders.isNotEmpty)
            SliverToBoxAdapter(
              child: _Constrained(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.sm,
                    AppSpace.gutter,
                    0,
                  ),
                  child: TextField(
                    key: const ValueKey<String>('ordersHistorySearch'),
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    style: AppText.body.copyWith(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Buscar por folio o cliente',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          if (entries.isEmpty)
            SliverToBoxAdapter(
              // El estado vacío tiene altura natural y se desplaza en el
              // CustomScrollView. Evita overflow con teclado y pantalla baja.
              child: Center(
                  child: searching
                      ? StateView(
                          icon: Icons.search_off_rounded,
                          title: 'Sin resultados para "${_query.trim()}"',
                          message: 'Busca por número de pedido (por ejemplo '
                              '1842) o por nombre del cliente.',
                          actionLabel: 'Limpiar búsqueda',
                          onAction: _clearSearch,
                          compact: true,
                        )
                      : _EmptyFor(filter: current),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.sm,
                AppSpace.gutter,
                AppSpace.xxxl,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = entries[index];
                    if (entry is _GroupTitle) {
                      return _Constrained(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 8 : 22,
                            bottom: 10,
                          ),
                          child: Row(
                            children: <Widget>[
                              Semantics(
                                header: true,
                                child: Text(entry.title, style: AppText.title),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${entry.count}',
                                style: AppText.title.copyWith(
                                  color: AppColors.inkFaint,
                                  fontFeatures: AppFonts.tabular,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final order = entry as RestaurantOrder;
                    return _Constrained(
                      key: ValueKey<String>('order-${order.id}'),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Entrance(
                          key: ValueKey<String>('${order.id}-${order.status}'),
                          duration: const Duration(milliseconds: 220),
                          offset: const Offset(0, 8),
                          child: OrderTicket(order: order, ops: ops),
                        ),
                      ),
                    );
                  },
                  childCount: entries.length,
                  findChildIndexCallback: (key) {
                    if (key is ValueKey<String>) {
                      final index = entries.indexWhere(
                        (e) => e is RestaurantOrder && 'order-${e.id}' == key.value,
                      );
                      return index < 0 ? null : index;
                    }
                    return null;
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupTitle {
  const _GroupTitle(this.title, this.count);
  final String title;
  final int count;
}

/// Limita el ancho de lectura en tablet sin estirar tarjetas de teléfono.
class _Constrained extends StatelessWidget {
  const _Constrained({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.countOf,
    required this.onSelect,
  });

  final OrdersFilter selected;
  final int Function(OrdersFilter) countOf;
  final ValueChanged<OrdersFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    // 60 px = chips de 48 px: área táctil mínima de Android.
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.gutter,
          vertical: 6,
        ),
        itemCount: OrdersFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = OrdersFilter.values[index];
          final isSelected = f == selected;
          final count = countOf(f);
          final showCount = f != OrdersFilter.history && count > 0;
          final highlight = f == OrdersFilter.incoming && count > 0 && !isSelected;
          return Semantics(
            selected: isSelected,
            button: true,
            label: showCount ? '${f.label}, $count' : f.label,
            excludeSemantics: true,
            child: Material(
              color: isSelected ? AppColors.ink : AppColors.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: isSelected ? AppColors.ink : AppColors.line,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelect(f),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        f.label,
                        style: AppText.label.copyWith(
                          fontSize: 14,
                          color: isSelected ? Colors.white : AppColors.ink,
                        ),
                      ),
                      if (showCount) ...<Widget>[
                        const SizedBox(width: 7),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: highlight
                                ? AppColors.brand
                                : isSelected
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : AppColors.sunken,
                            borderRadius: const BorderRadius.all(AppRadius.pill),
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: AppText.label.copyWith(
                              fontSize: 12.5,
                              color: isSelected ? Colors.white : AppColors.ink,
                              fontFeatures: AppFonts.tabular,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyFor extends StatelessWidget {
  const _EmptyFor({required this.filter});

  final OrdersFilter filter;

  @override
  Widget build(BuildContext context) {
    switch (filter) {
      case OrdersFilter.active:
        return const StateView(
          icon: Icons.check_rounded,
          tone: StateTone.positive,
          title: 'Sin pedidos activos',
          message: 'Cuando entre un pedido aparecerá aquí y en la pestaña '
              'Pedidos con un aviso.',
        );
      case OrdersFilter.incoming:
        return const StateView(
          icon: Icons.notifications_none_rounded,
          title: 'No hay pedidos nuevos',
          message: 'Los pedidos que esperan tu respuesta se muestran aquí.',
        );
      case OrdersFilter.kitchen:
        return const StateView(
          icon: Icons.soup_kitchen_outlined,
          title: 'Nada en cocina',
          message: 'Los pedidos aceptados y en preparación se muestran aquí.',
        );
      case OrdersFilter.ready:
        return const StateView(
          icon: Icons.takeout_dining_outlined,
          title: 'Sin pedidos listos',
          message: 'Marca un pedido como listo para avisar al repartidor o '
              'al cliente que recoge.',
        );
      case OrdersFilter.history:
        return const StateView(
          icon: Icons.history_rounded,
          title: 'Aún no hay historial',
          message: 'Los pedidos entregados y cancelados aparecerán aquí.',
        );
    }
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget ticket() => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: BoneCard(
            child: Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Row(
                    children: <Widget>[
                      Bone(width: 70, height: 22),
                      SizedBox(width: 10),
                      Bone(width: 84, height: 22, radius: 11),
                      Spacer(),
                      Bone(width: 52, height: 22),
                    ],
                  ),
                  SizedBox(height: 14),
                  Bone(width: 140),
                  SizedBox(height: 16),
                  Bone(height: 16),
                  SizedBox(height: 8),
                  Bone(width: 220, height: 16),
                  SizedBox(height: 18),
                  Bone(height: 44, radius: 12),
                ],
              ),
            ),
          ),
        );

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
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text('Pedidos', style: AppText.headline),
                const SizedBox(height: 8),
                const Shimmer(child: Bone(width: 150)),
                const SizedBox(height: 24),
                const Shimmer(
                  child: Row(
                    children: <Widget>[
                      Bone(width: 96, height: 40, radius: 20),
                      SizedBox(width: 8),
                      Bone(width: 90, height: 40, radius: 20),
                      SizedBox(width: 8),
                      Bone(width: 104, height: 40, radius: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ticket(),
                ticket(),
                ticket(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
