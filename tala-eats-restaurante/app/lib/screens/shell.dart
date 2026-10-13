import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/entities.dart';
import '../state/operations_controller.dart';
import '../state/session_controller.dart';
import '../widgets/surfaces.dart';
import '../widgets/ticket.dart';
import 'finance_screen.dart';
import 'home_screen.dart';
import 'kds_screen.dart';
import 'menu/menu_screen.dart';
import 'more/more_screen.dart';
import 'orders/orders_screen.dart';

/// `true` si entre dos lecturas apareció al menos un pedido nuevo. La primera
/// lectura ([known] nulo) nunca cuenta como llegada.
bool newIncomingArrived(Set<int>? known, Set<int> current) =>
    known != null && current.difference(known).isNotEmpty;

/// Panel principal: Inicio · Pedidos · Menú · Finanzas · Más. El modo cocina
/// (KDS) se abre como pantalla dedicada desde Inicio, Pedidos o Más.
class RestaurantShell extends StatefulWidget {
  const RestaurantShell({super.key, required this.session});

  final SessionController session;

  @override
  State<RestaurantShell> createState() => _RestaurantShellState();
}

class _RestaurantShellState extends State<RestaurantShell>
    with WidgetsBindingObserver {
  late final OperationsController _ops =
      OperationsController(
        widget.session.services,
        onSessionExpired: widget.session.signOut,
      );
  final ValueNotifier<OrdersFilter> _ordersFilter =
      ValueNotifier<OrdersFilter>(OrdersFilter.active);
  int _index = 0;

  /// Pedidos nuevos ya conocidos; `null` hasta la primera carga.
  Set<int>? _knownIncoming;

  static const int _homeTab = 0;
  static const int _ordersTab = 1;
  static const int _menuTab = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ops.addListener(_watchIncoming);
    _ops.load();
  }

  /// Vibración corta cuando llega un pedido nuevo (también con la cocina
  /// abierta). La primera carga no vibra: solo lo que llega después.
  void _watchIncoming() {
    if (!_ops.hasData) return;
    final ids = _ops.incomingOrders.map((o) => o.id).toSet();
    final known = _knownIncoming;
    _knownIncoming = ids;
    if (newIncomingArrived(known, ids)) HapticFeedback.vibrate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ops.resumeLiveSync();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _ops.pauseLiveSync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ops.removeListener(_watchIncoming);
    _ops.dispose();
    _ordersFilter.dispose();
    super.dispose();
  }

  void _select(int next) {
    if (next == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = next);
    if (next == _ordersTab) _ops.markIncomingSeen();
  }

  void _openOrders(OrdersFilter filter) {
    _ordersFilter.value = filter;
    _select(_ordersTab);
  }

  void _openMenu() => _select(_menuTab);

  void _openKds() {
    Navigator.of(context).push<void>(
      appRoute<void>(KdsScreen(ops: _ops)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        ops: _ops,
        session: widget.session,
        onOpenOrders: _openOrders,
        onOpenMenu: _openMenu,
        onOpenKds: _openKds,
      ),
      OrdersScreen(ops: _ops, filter: _ordersFilter, onOpenKds: _openKds),
      MenuScreen(ops: _ops),
      FinanceScreen(ops: _ops),
      MoreScreen(ops: _ops, session: widget.session, onOpenKds: _openKds),
    ];

    // El shell aplica el área segura superior una sola vez; así el aviso de
    // sincronización y las pantallas no duplican el margen del status bar.
    final body = SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          _SyncBanner(ops: _ops),
          // Inicio y Pedidos ya muestran los pedidos nuevos; en el resto de
          // pestañas este aviso evita que un pedido se quede sin respuesta.
          _IncomingBanner(
            ops: _ops,
            enabled: _index != _homeTab && _index != _ordersTab,
            onOpen: () => _openOrders(OrdersFilter.incoming),
          ),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
    );

    return ClockProvider(
      child: PopScope<Object?>(
        canPop: _index == _homeTab,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _select(_homeTab);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 840;
            if (wide) {
              return Scaffold(
                backgroundColor: AppColors.canvas,
                body: Row(
                  children: <Widget>[
                    ListenableBuilder(
                      listenable: _ops,
                      builder: (context, _) => _Rail(
                        index: _index,
                        unseen: _ops.unseenIncoming,
                        onSelect: _select,
                        onOpenKds: _openKds,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                ),
              );
            }
            return Scaffold(
              backgroundColor: AppColors.canvas,
              body: body,
              bottomNavigationBar: ListenableBuilder(
                listenable: _ops,
                builder: (context, _) => _BottomNav(
                  index: _index,
                  unseen: _ops.unseenIncoming,
                  onSelect: _select,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Destination> _destinations = <_Destination>[
  _Destination('Inicio', Icons.home_outlined, Icons.home_rounded),
  _Destination('Pedidos', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  _Destination(
    'Menú',
    Icons.restaurant_menu_outlined,
    Icons.restaurant_menu_rounded,
  ),
  _Destination(
    'Finanzas',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet_rounded,
  ),
  _Destination('Más', Icons.more_horiz_rounded, Icons.more_horiz_rounded),
];

Widget _withBadge(Widget icon, int count) {
  if (count <= 0) return icon;
  return Badge(
    backgroundColor: AppColors.brand,
    textColor: AppColors.ink,
    label: Text(count > 99 ? '99+' : '$count'),
    child: icon,
  );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.unseen,
    required this.onSelect,
  });

  final int index;
  final int unseen;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelect,
        destinations: <Widget>[
          for (var i = 0; i < _destinations.length; i++)
            NavigationDestination(
              label: _destinations[i].label,
              icon: _withBadge(
                Icon(_destinations[i].icon),
                i == 1 ? unseen : 0,
              ),
              selectedIcon: _withBadge(
                Icon(_destinations[i].selectedIcon),
                i == 1 ? unseen : 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.index,
    required this.unseen,
    required this.onSelect,
    required this.onOpenKds,
  });

  final int index;
  final int unseen;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenKds;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        right: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: NavigationRail(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                labelType: NavigationRailLabelType.all,
                minWidth: 88,
                leading: const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 20),
                  child: BrandMark(size: 44),
                ),
        destinations: <NavigationRailDestination>[
          for (var i = 0; i < _destinations.length; i++)
            NavigationRailDestination(
              label: Text(_destinations[i].label),
              icon: _withBadge(
                Icon(_destinations[i].icon),
                i == 1 ? unseen : 0,
              ),
              selectedIcon: _withBadge(
                Icon(_destinations[i].selectedIcon),
                i == 1 ? unseen : 0,
              ),
            ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              child: Tooltip(
                message: 'Abrir modo cocina',
                child: Material(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: onOpenKds,
                    child: const SizedBox(
                      width: 64,
                      height: 64,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.soup_kitchen_outlined, color: Colors.white),
                          SizedBox(height: 4),
                          Text(
                            'Cocina',
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
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

/// Aviso fijo de pedidos que esperan respuesta (patrón de apps de reparto:
/// el pedido nuevo nunca queda escondido detrás de otra pestaña). Sin
/// animaciones permanentes: solo aparece/desaparece con un cambio de tamaño.
class _IncomingBanner extends StatelessWidget {
  const _IncomingBanner({
    required this.ops,
    required this.enabled,
    required this.onOpen,
  });

  final OperationsController ops;
  final bool enabled;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ops,
      builder: (context, _) {
        final incoming = enabled && ops.hasData
            ? ops.incomingOrders
            : const <RestaurantOrder>[];
        final Widget child;
        if (incoming.isEmpty) {
          child = const SizedBox(width: double.infinity);
        } else {
          final now = ClockScope.now(context);
          final waited = minutesSince(incoming.first.createdAt, now);
          final urgent =
              UrgencyPolicy.of(incoming.first, now) != Urgency.calm;
          final title = incoming.length == 1
              ? '1 pedido nuevo espera respuesta'
              : '${incoming.length} pedidos nuevos esperan respuesta';
          final detail = waited < 1
              ? 'Acaba de llegar'
              : 'El primero espera desde hace ${elapsedLabel(waited)}';
          child = Semantics(
            key: const ValueKey<String>('incomingOrdersBanner'),
            button: true,
            liveRegion: true,
            label: '$title. $detail. Ver pedidos nuevos',
            onTap: onOpen,
            excludeSemantics: true,
            child: Material(
              color: urgent ? AppColors.red : AppColors.brand,
              child: InkWell(
                onTap: onOpen,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 22,
                          color: urgent ? Colors.white : AppColors.ink,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.label.copyWith(
                                  fontSize: 14.5,
                                  color: urgent ? Colors.white : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: urgent ? Colors.white : AppColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: urgent ? Colors.white : AppColors.ink,
                            borderRadius:
                                const BorderRadius.all(AppRadius.pill),
                          ),
                          child: Text(
                            'Ver',
                            style: AppText.label.copyWith(
                              color: urgent ? AppColors.red : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return AnimatedSize(
          duration: Motion.of(context, Motion.base),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: child,
        );
      },
    );
  }
}

/// Aviso persistente cuando la última sincronización falló pero hay datos.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.ops});

  final OperationsController ops;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ops,
      builder: (context, _) {
        final failure = ops.syncFailure;
        final last = ops.lastSyncAt;
        return AnimatedSize(
          duration: Motion.of(context, Motion.base),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: failure == null || !ops.hasData
              ? const SizedBox(width: double.infinity)
              : Material(
                  color: failure.isConnectivity
                      ? AppColors.amberTint
                      : AppColors.redTint,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            failure.isConnectivity
                                ? Icons.wifi_off_rounded
                                : Icons.sync_problem_rounded,
                            size: 19,
                            color: failure.isConnectivity
                                ? AppColors.amber
                                : AppColors.red,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                failure.isConnectivity
                                    ? last == null
                                        ? 'Sin conexión.'
                                        : 'Sin conexión. Datos de las ${clockTime(last)}.'
                                    : 'No se pudo actualizar. Mostramos lo último.',
                                style: AppText.label.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: ops.refreshing ? null : ops.refresh,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              minimumSize: const Size(44, 44),
                            ),
                            child: Text(
                              ops.refreshing ? 'Actualizando…' : 'Reintentar',
                            ),
                          ),
                        ],
                      ),
                    ),
                ),
        );
      },
    );
  }
}
