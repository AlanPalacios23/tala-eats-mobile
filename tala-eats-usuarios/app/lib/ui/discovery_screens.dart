part of '../main.dart';

// ---------------------------------------------------------------------------
// Shell, Home, Buscar, Restaurante y Producto.
// ---------------------------------------------------------------------------

final ButtonStyle kCompactFilled = FilledButton.styleFrom(minimumSize: const Size(88, 44), padding: const EdgeInsets.symmetric(horizontal: 18));
final ButtonStyle kCompactOutlined = OutlinedButton.styleFrom(minimumSize: const Size(88, 44), padding: const EdgeInsets.symmetric(horizontal: 16));

Restaurant? restaurantFor(TalaModel model, int id) {
  for (final Restaurant restaurant in model.restaurants) {
    if (restaurant.id == id) return restaurant;
  }
  return null;
}

int cartQuantityFor(TalaModel model, FoodItem item) {
  int total = 0;
  for (final CartLine line in model.cart) {
    if (line.item.id == item.id && line.item.restaurantId == item.restaurantId) total += line.quantity;
  }
  return total;
}

int cartItemCount(TalaModel model) => model.cart.fold<int>(0, (int total, CartLine line) => total + line.quantity);

/// Adds to cart through the existing TalaModel.addToCart. Only adds UI
/// guards: closed restaurant message and an explicit confirmation before the
/// model replaces a cart that belongs to another restaurant.
Future<bool> addItemWithGuard(BuildContext context, TalaModel model, FoodItem item, int quantity, {String note = ''}) async {
  final Restaurant? target = restaurantFor(model, item.restaurantId);
  if (target != null && !target.isOpen) {
    showMessage(context, 'Este restaurante está cerrado por ahora.');
    return false;
  }
  if (model.cart.isNotEmpty && model.cartRestaurantId != null && model.cartRestaurantId != item.restaurantId) {
    final Restaurant? current = model.cartRestaurant;
    final bool replace = await showDialog<bool>(
          context: context,
          barrierColor: kScrim,
          builder: (BuildContext dialogContext) => AlertDialog(
            backgroundColor: kSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('¿Empezar un carrito nuevo?', style: TalaText.h2),
            content: Text(
              'Tu carrito tiene productos de ${current?.name ?? 'otro restaurante'}. Si continúas, se reemplazarán por este platillo.',
              style: TalaText.body,
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Conservar')),
              FilledButton(style: kCompactFilled, onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Empezar nuevo')),
            ],
          ),
        ) ??
        false;
    if (!replace) return false;
  }
  HapticFeedback.mediumImpact();
  model.addToCart(item, quantity, note: note);
  return true;
}

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.model});

  final TalaModel model;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  late final Animation<double> _opacity = CurvedAnimation(parent: _fade, curve: Curves.easeOut);
  int _shown = 0;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _shown = widget.model.tabIndex;
  }

  @override
  void didUpdateWidget(covariant CustomerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model.tabIndex != _shown) {
      _shown = widget.model.tabIndex;
      if (!_reduce) _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduce = TalaMotion.reduced(context);
    final TalaModel model = widget.model;
    final int index = model.tabIndex.clamp(0, 3).toInt();
    final double top = MediaQuery.paddingOf(context).top;
    final List<Widget> pages = <Widget>[
      HomeScreen(model: model),
      SearchScreen(model: model),
      OrdersScreen(model: model),
      AccountScreen(model: model),
    ];
    // Android Back returns from secondary tabs to Inicio before leaving the app.
    // Detail, checkout and payment routes keep their own Navigator/PopScope.
    return PopScope<Object?>(
      canPop: index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && model.tabIndex != 0) model.setTab(0);
      },
      child: Scaffold(
      extendBody: true,
      backgroundColor: kBackground,
      body: Stack(
        children: <Widget>[
          FadeTransition(
            opacity: _opacity,
            child: IndexedStack(
              index: index,
              children: List<Widget>.generate(pages.length, (int i) => TickerMode(enabled: i == index, child: pages[i])),
            ),
          ),
          // The basket stays reachable from Home, Buscar, Pedidos and Cuenta.
          // A restaurant detail route retains its larger bottom basket bar.
          Positioned(
            right: 16,
            bottom: 88,
            child: AnimatedBuilder(
              animation: model,
              builder: (BuildContext context, Widget? child) {
                if (model.cart.isEmpty) return const SizedBox.shrink();
                final int count = cartItemCount(model);
                return FloatingActionButton.extended(
                  key: const ValueKey<String>('global-cart-fab'),
                  heroTag: 'customer-global-cart',
                  backgroundColor: kBrandDeep,
                  foregroundColor: Colors.white,
                  tooltip: 'Ver carrito con $count productos',
                  onPressed: () => Navigator.of(context)
                      .push(premiumRoute(CartScreen(model: model))),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text('$count · ${money(model.subtotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                );
              },
            ),
          ),
          // Keeps scrolled content from colliding with the status bar icons.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: top,
            child: const IgnorePointer(child: ColoredBox(color: Color(0xF0FAFAF9))),
          ),
          if (!model.online && model.lastError.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: top + 8,
              child: Reveal(offset: -10, child: OfflineBanner(onRetry: model.refreshAll, busy: model.loading)),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: PremiumBottomDock(model: model),
      ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.onRetry,
    this.busy = false,
  });

  final Future<void> Function() onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final Widget retry = TextButton(
      onPressed: busy ? null : () { onRetry(); },
      child: Text(busy ? 'Reintentando…' : 'Reintentar'),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
        boxShadow: kShadowLifted,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints bounds) {
              final Widget message = Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: kSoftOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_off_rounded,
                        color: kBrandDeep, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text('Sin conexión',
                            style: TextStyle(color: kInk,
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        Text('Tu sesión sigue activa.',
                            style: TextStyle(color: kMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              );
              if (bounds.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    message,
                    Align(alignment: Alignment.centerRight, child: retry),
                  ],
                );
              }
              return Row(children: <Widget>[
                Expanded(child: message),
                const SizedBox(width: 4),
                retry,
              ]);
            },
          ),
        ),
      ),
    );
  }
}

class PremiumBottomDock extends StatelessWidget {
  const PremiumBottomDock({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    const List<(IconData, IconData, String)> items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
      (Icons.search_rounded, Icons.search_rounded, 'Buscar'),
      (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Pedidos'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Cuenta'),
    ];
    final int index = model.tabIndex.clamp(0, items.length - 1).toInt();
    final bool activeOrder = model.activeOrder != null;
    final Duration slide = TalaMotion.of(context, const Duration(milliseconds: 280));
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kLine),
        boxShadow: kShadowSoft,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double itemWidth = constraints.maxWidth / items.length;
          const double pillWidth = 56;
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: slide,
                curve: TalaMotion.ease,
                left: index * itemWidth + (itemWidth - pillWidth) / 2,
                top: 10,
                width: pillWidth,
                height: 30,
                child: Container(decoration: BoxDecoration(color: kSoftOrange, borderRadius: BorderRadius.circular(99))),
              ),
              Material(
                type: MaterialType.transparency,
                child: Row(
                children: List<Widget>.generate(items.length, (int i) {
                  final bool selected = i == index;
                  final (IconData, IconData, String) item = items[i];
                  return Expanded(
                    child: Semantics(
                      selected: selected,
                      button: true,
                      label: item.$3,
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          if (i == index) return;
                          HapticFeedback.selectionClick();
                          FocusManager.instance.primaryFocus?.unfocus();
                          model.setTab(i);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SizedBox(
                              height: 30,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: <Widget>[
                                  AnimatedSwitcher(
                                    duration: TalaMotion.of(context, TalaMotion.select),
                                    child: Icon(
                                      selected ? item.$2 : item.$1,
                                      key: ValueKey<bool>(selected),
                                      color: selected ? kBrandDeep : kMuted,
                                      size: 22,
                                    ),
                                  ),
                                  if (i == 2 && activeOrder)
                                    Positioned(
                                      right: -5,
                                      top: 3,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(color: kBrand, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: TalaMotion.of(context, TalaMotion.select),
                              style: TextStyle(color: selected ? kBrandDeep : kMuted, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 11),
                              child: Text(item.$3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.model});

  final TalaModel model;

  void _openRestaurant(BuildContext context, Restaurant restaurant, String heroTag) {
    Navigator.of(context).push(premiumRoute(RestaurantScreen(model: model, restaurant: restaurant, heroTag: heroTag)));
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    final bool firstLoad = model.loading && model.restaurants.isEmpty;
    final String address = model.addresses.isEmpty
        ? 'Agregar dirección'
        : model.addresses[model.selectedAddress.clamp(0, model.addresses.length - 1).toInt()].label;
    final String name = firstName(model.userName);
    return RefreshIndicator(
      color: kBrand,
      backgroundColor: Colors.white,
      edgeOffset: top,
      onRefresh: model.refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: 'Entregar en $address. Cambiar dirección',
                          excludeSemantics: true,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.of(context).push(premiumRoute(AddressesScreen(model: model))),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(color: kSoftOrange, borderRadius: BorderRadius.circular(14)),
                                      child: const Icon(Icons.location_on_rounded, color: kBrand, size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          const Text('Entregar en', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 1),
                                          Row(
                                            children: <Widget>[
                                              Flexible(
                                                child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2)),
                                              ),
                                              const Icon(Icons.keyboard_arrow_down_rounded, color: kInkSoft, size: 20),
                                            ],
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
                      ),
                      const SizedBox(width: 8),
                      TalaCircleButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: 'Notificaciones',
                        badge: model.unreadNotifications,
                        onPressed: () => Navigator.of(context).push(premiumRoute(NotificationsScreen(model: model))),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'Mi cuenta',
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            model.setTab(3);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kLine)),
                            child: ProfileAvatar(model: model, radius: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomerMarketSelector(model: model),
                  const SizedBox(height: 16),
                  Reveal(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(name.isEmpty ? 'Hola 👋' : 'Hola, $name 👋', style: const TextStyle(color: kBrandDeep, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('¿Qué se te antoja hoy?', style: TalaText.display),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Reveal(
                    index: 1,
                    child: HomeSearchPill(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        model.setTab(1);
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  const TalaSectionHeader(title: 'Restaurantes y comercios'),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          if (firstLoad)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 132),
              sliver: SliverToBoxAdapter(
                child: Column(children: <Widget>[RestaurantCardSkeleton(), RestaurantCardSkeleton(), RestaurantCardSkeleton()]),
              ),
            )
          else if (model.restaurants.isEmpty)
            // Keep empty/error state scrollable with large fonts and small
            // screens; SliverFillRemaining can force a child below min height.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 110),
                child: model.lastError.isNotEmpty
                    ? StatusView(
                        icon: Icons.wifi_off_rounded,
                        title: 'No pudimos cargar los comercios',
                        body: 'Revisa tu conexión e inténtalo de nuevo.',
                        actionLabel: 'Reintentar',
                        onAction: model.refreshAll,
                        tone: StatusTone.danger,
                      )
                    : StatusView(
                        icon: Icons.storefront_outlined,
                        title: 'Aún no hay comercios disponibles',
                        body: 'Cuando haya negocios activos en ' +
                            TalaMarket.labelFor(model.marketCode) +
                            ' podrás encontrarlos aquí.',
                      ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 132),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final Restaurant restaurant = model.restaurants[index];
                    final String tag = 'home-restaurant-${restaurant.id}';
                    return Reveal(
                      index: index,
                      child: RestaurantCard(
                        model: model,
                        restaurant: restaurant,
                        heroTag: tag,
                        onTap: () => _openRestaurant(context, restaurant, tag),
                      ),
                    );
                  },
                  childCount: model.restaurants.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HomeSearchPill extends StatelessWidget {
  const HomeSearchPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buscar restaurantes o comida',
      excludeSemantics: true,
      child: Pressable(
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
          child: Material(
            color: kSunken,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.search_rounded, color: kInkSoft, size: 23),
                    SizedBox(width: 12),
                    Expanded(child: Text('Buscar restaurantes o comida…', style: TextStyle(color: kSubtle, fontSize: 15, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.favorite, required this.onTap, this.size = 44});

  final bool favorite;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: favorite,
      label: favorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.9,
        child: Material(
          color: Colors.white.withValues(alpha: 0.96),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: PopIn(
                  key: ValueKey<bool>(favorite),
                  from: favorite ? 0.6 : 0.85,
                  child: Icon(
                    favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: favorite ? kBrand : kInk,
                    size: size * 0.48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.model,
    required this.restaurant,
    required this.onTap,
    this.heroTag,
  });

  final TalaModel model;
  final Restaurant restaurant;
  final VoidCallback onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final bool favorite = model.favorites.contains(restaurant.id);
    final bool closed = !restaurant.isOpen;
    // RestaurantPublic.delivery_fee is a merchant field, NOT a customer quote.
    // The 1.6.2 contract calculates delivery from customer GPS at checkout.
    final String fee = restaurant.delivery
        ? 'Envío según distancia'
        : 'Solo para recoger';
    Widget media = AspectRatio(
      aspectRatio: 16 / 9,
      child: RestaurantMedia(
        assetPath: restaurant.image,
        imageUrl: restaurant.imageUrl,
        desaturate: closed,
      ),
    );
    if (heroTag != null) {
      media = Hero(tag: heroTag!, child: media);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Semantics(
        button: true,
        label: restaurant.name + ', ' + restaurant.category +
            (closed ? ', cerrado' : ', abierto'),
        child: Pressable(
          scale: 0.992,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: <Widget>[
                        media,
                        if (closed)
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: ColoredBox(color: Color(0x44FFFFFF)),
                            ),
                          ),
                        if (closed)
                          const Positioned(
                            top: 12,
                            left: 12,
                            child: StatusPill(
                              label: 'Cerrado',
                              color: kInkSoft,
                              background: Color(0xF2FFFFFF),
                              dot: false,
                            ),
                          ),
                        if (restaurant.promo.isNotEmpty)
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: StatusPill(
                              label: restaurant.promo,
                              color: kInkSoft,
                              background: const Color(0xF2FFFFFF),
                              dot: false,
                            ),
                          ),
                        Positioned(
                          right: 10,
                          top: 10,
                          child: FavoriteButton(
                            favorite: favorite,
                            onTap: () => model.toggleFavorite(restaurant.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                restaurant.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TalaText.h2.copyWith(
                                  fontSize: 19,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (restaurant.rating > 0) ...<Widget>[
                              const SizedBox(width: 8),
                              RatingChip(rating: restaurant.rating),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          restaurant.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TalaText.muted.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 9),
                        MetaLine(
                          items: <(IconData, String)>[
                            (Icons.schedule_rounded, restaurant.eta),
                            (restaurant.delivery
                                ? Icons.two_wheeler_rounded
                                : Icons.storefront_rounded, fee),
                          ],
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
    );
  }
}

class RestaurantCardSkeleton extends StatelessWidget {
  const RestaurantCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SkeletonPulse(
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kLine)),
          clipBehavior: Clip.antiAlias,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(aspectRatio: 16 / 10, child: ColoredBox(color: Color(0xFFEDE7E2))),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonBox(width: 170, height: 18),
                    SizedBox(height: 9),
                    SkeletonBox(width: 110, height: 13),
                    SizedBox(height: 14),
                    Row(children: <Widget>[SkeletonBox(width: 84, height: 13), SizedBox(width: 14), SkeletonBox(width: 96, height: 13)]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buscar
// ---------------------------------------------------------------------------

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.model});

  final TalaModel model;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController controller = TextEditingController();
  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void clear() {
    controller.clear();
    setState(() => query = '');
  }

  @override
  Widget build(BuildContext context) {
    final TalaModel model = widget.model;
    final String normalized = _fold(query.trim());
    final List<Restaurant> restaurants = normalized.isEmpty
        ? <Restaurant>[]
        : model.restaurants.where((Restaurant restaurant) => _fold(restaurant.name).contains(normalized) || _fold(restaurant.category).contains(normalized)).toList();
    final List<FoodItem> items = normalized.isEmpty
        ? <FoodItem>[]
        : model.menu.where((FoodItem item) {
            // A cached product from another market must never surface when
            // its merchant is absent from the currently filtered catalog.
            if (restaurantFor(model, item.restaurantId) == null) return false;
            return _fold(item.name).contains(normalized) ||
                _fold(item.category).contains(normalized);
          }).toList();
    final List<Restaurant> nearby = model.restaurants
        .where((Restaurant r) => r.isOpen).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
        children: <Widget>[
          const Text('Buscar', style: TalaText.display),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: false,
            textInputAction: TextInputAction.search,
            onChanged: (String value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: 'Restaurante, comercio o platillo…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty ? null : IconButton(tooltip: 'Borrar búsqueda', onPressed: clear, icon: const Icon(Icons.close_rounded)),
              fillColor: kSunken,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: kBrand, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: TalaMotion.of(context, const Duration(milliseconds: 220)),
            switchInCurve: TalaMotion.ease,
            transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child),
            child: normalized.isEmpty
                ? KeyedSubtree(
                    key: const ValueKey<String>('idle'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (nearby.isNotEmpty) ...<Widget>[
                          const TalaSectionHeader(title: 'Comercios disponibles'),
                          const SizedBox(height: 14),
                          for (final Restaurant restaurant in nearby)
                            SearchRestaurantTile(model: model,
                                restaurant: restaurant),
                        ],
                        if (nearby.isEmpty)
                          if (model.loading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (model.lastError.isNotEmpty)
                            StatusView(
                              icon: Icons.cloud_off_rounded,
                              title: 'No pudimos cargar los comercios',
                              body: 'Comprueba tu conexión e inténtalo de nuevo.',
                              actionLabel: 'Reintentar',
                              onAction: model.refreshAll,
                              compact: true,
                            )
                          else
                            const StatusView(
                              icon: Icons.storefront_outlined,
                              title: 'Aún no hay comercios para explorar',
                              body: 'Cuando haya negocios disponibles en esta '
                                  'localidad los encontrarás aquí.',
                              compact: true,
                            ),
                      ],
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey<String>('results'),
                    child: (restaurants.isEmpty && items.isEmpty)
                        ? StatusView(
                            icon: Icons.search_off_rounded,
                            title: 'Sin resultados',
                            body: 'No encontramos “${query.trim()}”. Prueba con otro nombre, comida o categoría.',
                            compact: true,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (restaurants.isNotEmpty) ...<Widget>[
                                const TalaSectionHeader(title: 'Restaurantes'),
                                const SizedBox(height: 12),
                                for (int i = 0; i < restaurants.length; i++)
                                  Reveal(index: i, child: SearchRestaurantTile(model: model, restaurant: restaurants[i])),
                                const SizedBox(height: 16),
                              ],
                              if (items.isNotEmpty) ...<Widget>[
                                const TalaSectionHeader(title: 'Platillos'),
                                const SizedBox(height: 12),
                                for (int i = 0; i < items.length; i++) Reveal(index: i, child: SearchDishTile(model: model, item: items[i])),
                              ],
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class SearchRestaurantTile extends StatelessWidget {
  const SearchRestaurantTile({super.key, required this.model, required this.restaurant});

  final TalaModel model;
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final String tag = 'search-restaurant-${restaurant.id}';
    final bool closed = !restaurant.isOpen;
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.of(context).push(premiumRoute(RestaurantScreen(model: model, restaurant: restaurant, heroTag: tag))),
      child: Row(
        children: <Widget>[
          Hero(
            tag: tag,
            child: RestaurantMedia(assetPath: restaurant.image, imageUrl: restaurant.imageUrl, width: 72, height: 72, radius: 14, desaturate: closed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.title),
                const SizedBox(height: 2),
                Text(restaurant.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.muted),
                const SizedBox(height: 6),
                MetaLine(
                  items: <(IconData, String)>[
                    if (restaurant.rating > 0) (Icons.star_rounded, restaurant.rating.toStringAsFixed(1)),
                    (Icons.schedule_rounded, restaurant.eta),
                  ],
                ),
              ],
            ),
          ),
          if (closed) const StatusPill(label: 'Cerrado', color: kInkSoft, background: kSunken),
        ],
      ),
    );
  }
}

class SearchDishTile extends StatelessWidget {
  const SearchDishTile({super.key, required this.model, required this.item});

  final TalaModel model;
  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    final Restaurant? restaurant = restaurantFor(model, item.restaurantId);
    final bool open = restaurant?.isOpen == true;
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      onTap: open ? () => showProductSheet(context, model, item) : () => showMessage(context, restaurant == null ? 'Este platillo no está disponible por ahora.' : 'Este restaurante está cerrado por ahora.'),
      child: Row(
        children: <Widget>[
          DishThumb(item: item, size: 64, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TalaText.title),
                if (restaurant != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.caption),
                ],
                const SizedBox(height: 4),
                Text(money(item.price), style: TalaText.price.copyWith(fontSize: 15)),
              ],
            ),
          ),
          AddToCartButton(
            model: model,
            item: item,
            enabled: open,
          ),
        ],
      ),
    );
  }
}

/// Round "+" that turns into the in-cart quantity with a short pop.
class AddToCartButton extends StatelessWidget {
  const AddToCartButton({super.key, required this.model, required this.item, required this.enabled});

  final TalaModel model;
  final FoodItem item;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final int inCart = cartQuantityFor(model, item);
    final bool filled = inCart > 0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: filled ? 'Agregar otro ${item.name}. $inCart en carrito' : 'Agregar ${item.name}',
      excludeSemantics: true,
      child: Pressable(
        enabled: enabled,
        scale: 0.88,
        child: Material(
          color: !enabled ? kSunken : (filled ? kBrand : Colors.white),
          shape: CircleBorder(side: BorderSide(color: filled ? kBrand : kLineStrong)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => addItemWithGuard(context, model, item, 1) : null,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: filled
                    ? PopIn(
                        key: ValueKey<int>(inCart),
                        from: 0.6,
                        child: Text('$inCart', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      )
                    : Icon(Icons.add_rounded, color: enabled ? kBrandDeep : kSubtle, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Restaurante
// ---------------------------------------------------------------------------

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key, required this.model, required this.restaurant, this.heroTag});

  final TalaModel model;
  final Restaurant restaurant;
  final String? heroTag;

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> {
  static const double _expanded = 280;
  String _category = '';
  bool _settled = false;

  TalaModel get model => widget.model;
  Restaurant get restaurant => widget.restaurant;

  @override
  void initState() {
    super.initState();
    _loadMenuIfNeeded();
  }

  /// Same request the previous build triggered through `itemsFor`, but the
  /// screen now knows when it finished so it can show skeleton → menu/empty.
  void _loadMenuIfNeeded() {
    final bool hasItems = model.menu.any((FoodItem item) => item.restaurantId == restaurant.id);
    if (hasItems) {
      // Mostrar el menú existente mientras consultamos imágenes nuevas.
      // Volver a entrar al restaurante debe actualizar fotos recién subidas.
      _settled = true;
      model.refreshRestaurantMenu(restaurant.id);
      return;
    }
    if (model._menusLoading.contains(restaurant.id)) {
      // Already requested by another screen; the model notifies on success.
      _settled = true;
      return;
    }
    model._loadRestaurantMenu(restaurant.id).whenComplete(() {
      if (mounted) setState(() => _settled = true);
    });
  }

  void _retry() {
    setState(() => _settled = false);
    _loadMenuIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: kBackground,
      body: AnimatedBuilder(
        animation: model,
        builder: (BuildContext context, Widget? child) {
          final List<FoodItem> items = model.menu.where((FoodItem item) => item.restaurantId == restaurant.id).toList();
          final List<String> categories = <String>[];
          for (final FoodItem item in items) {
            final String c = item.category.trim();
            if (c.isNotEmpty && !categories.contains(c)) categories.add(c);
          }
          final String selected = categories.contains(_category) ? _category : '';
          final List<FoodItem> visible = selected.isEmpty ? items : items.where((FoodItem item) => item.category.trim() == selected).toList();
          final bool loading = items.isEmpty && (!_settled || model._menusLoading.contains(restaurant.id));
          final bool favorite = model.favorites.contains(restaurant.id);
          return CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                stretch: true,
                expandedHeight: _expanded,
                backgroundColor: kBackground,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                elevation: 0,
                automaticallyImplyLeading: false,
                leadingWidth: 64,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Center(
                    child: TalaCircleButton(icon: Icons.arrow_back_rounded, tooltip: 'Regresar', onPressed: () => Navigator.of(context).maybePop()),
                  ),
                ),
                actions: <Widget>[
                  Center(child: FavoriteButton(favorite: favorite, onTap: () => model.toggleFavorite(restaurant.id))),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: _RestaurantHeader(restaurant: restaurant, heroTag: widget.heroTag, topPadding: top, expandedHeight: _expanded),
              ),
              SliverToBoxAdapter(child: _RestaurantInfo(restaurant: restaurant)),
              if (categories.length > 1)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _CategoryBarDelegate(
                    categories: categories,
                    selected: selected,
                    onSelect: (String value) => setState(() => _category = value),
                  ),
                ),
              if (loading)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 140),
                  sliver: SliverToBoxAdapter(child: Column(children: <Widget>[DishSkeleton(), DishSkeleton(), DishSkeleton()])),
                )
              else if (items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: StatusView(
                      icon: model.menuLoadFailed(restaurant.id) ? Icons.cloud_off_rounded : Icons.menu_book_rounded,
                      title: model.menuLoadFailed(restaurant.id) ? 'No pudimos cargar el menú' : 'Menú no disponible por ahora',
                      body: model.menuLoadFailed(restaurant.id)
                          ? 'El restaurante puede tener productos activos, pero no pudimos sincronizarlos en este momento. Intenta nuevamente.'
                          : 'Este comercio todavía no tiene platillos disponibles.',
                      actionLabel: 'Reintentar',
                      onAction: _retry,
                      compact: true,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) => Reveal(
                        key: ValueKey<String>('$selected-${visible[index].id}'),
                        index: index,
                        child: FoodCard(model: model, item: visible[index], enabled: restaurant.isOpen),
                      ),
                      childCount: visible.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: model,
        builder: (BuildContext context, Widget? child) => RestaurantCartBar(model: model, restaurant: restaurant),
      ),
    );
  }
}

class _RestaurantHeader extends StatelessWidget {
  const _RestaurantHeader({required this.restaurant, required this.heroTag, required this.topPadding, required this.expandedHeight});

  final Restaurant restaurant;
  final String? heroTag;
  final double topPadding;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double minHeight = kToolbarHeight + topPadding;
        final double maxHeight = expandedHeight + topPadding;
        final double t = ((constraints.maxHeight - minHeight) / (maxHeight - minHeight)).clamp(0.0, 1.0).toDouble();
        final double cover = ((0.62 - t) / 0.5).clamp(0.0, 1.0).toDouble();
        final double titleOpacity = ((0.3 - t) / 0.3).clamp(0.0, 1.0).toDouble();
        Widget image = RestaurantMedia(assetPath: restaurant.image, imageUrl: restaurant.imageUrl, desaturate: !restaurant.isOpen);
        final String? tag = heroTag;
        if (tag != null) image = Hero(tag: tag, child: image);
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            image,
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: <Color>[Color(0x33000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            IgnorePointer(child: Opacity(opacity: cover, child: const ColoredBox(color: kBackground))),
            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              height: 24,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 1 - cover,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: kBackground, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 72,
              right: 72,
              top: topPadding,
              height: kToolbarHeight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: titleOpacity,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(restaurant.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kInk, fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RestaurantInfo extends StatelessWidget {
  const _RestaurantInfo({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final bool closed = !restaurant.isOpen;
    // Never advertise a restaurant-level delivery_fee as final shipping.
    final String fee = restaurant.delivery
        ? 'Envío según distancia'
        : 'Para recoger';
    final List<(IconData, String)> details = <(IconData, String)>[
      if (restaurant.rating > 0)
        (Icons.star_rounded, restaurant.rating.toStringAsFixed(1)),
      if (restaurant.delivery) (Icons.schedule_rounded, restaurant.eta),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(restaurant.name, style: TalaText.h1.copyWith(fontSize: 28)),
          const SizedBox(height: 4),
          Text(restaurant.category,
              style: TalaText.muted.copyWith(fontSize: 15)),
          if (restaurant.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(restaurant.description, style: TalaText.body),
          ],
          const SizedBox(height: 14),
          // Compact factual metadata instead of status chips and a boxed
          // three-column scorecard. Avoids repeated 'Abierto' labels.
          Wrap(
            spacing: 14,
            runSpacing: 9,
            children: <Widget>[
              for (final (IconData icon, String value) in details)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.max(100.0, MediaQuery.sizeOf(context).width - 40.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, color: kMuted, size: 16),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(value,
                          softWrap: true,
                          maxLines: 2,
                          style: const TextStyle(
                            color: kInkSoft, fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Delivery and pickup share one deliberate row at every viewport.
          // Text can wrap inside its column rather than pushing pickup below.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(restaurant.delivery
                        ? Icons.two_wheeler_rounded : Icons.storefront_rounded,
                        color: kMuted, size: 16),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(fee,
                        softWrap: true,
                        maxLines: 2,
                        style: const TextStyle(color: kInkSoft, fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              if (restaurant.pickup && restaurant.delivery) ...<Widget>[
                const SizedBox(width: 8),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.storefront_outlined, color: kMuted, size: 16),
                    SizedBox(width: 5),
                    Text('Para recoger', style: TextStyle(
                      color: kInkSoft, fontSize: 12, fontWeight: FontWeight.w600,
                    )),
                  ],
                ),
              ],
            ],
          ),
          if (restaurant.promo.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(restaurant.promo,
                softWrap: true,
                style: const TextStyle(color: kBrandDeep,
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          if (closed) ...<Widget>[
            const SizedBox(height: 12),
            const AuthNotice(
              icon: Icons.schedule_rounded,
              text: 'Este comercio está cerrado por ahora. Puedes ver su menú y pedir cuando vuelva a abrir.',
              danger: true,
            ),
          ],
          const SizedBox(height: 24),
          const Text('Menú', style: TalaText.h2),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _CategoryBarDelegate extends SliverPersistentHeaderDelegate {
  _CategoryBarDelegate({required this.categories, required this.selected, required this.onSelect});

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  double get minExtent => 62;

  @override
  double get maxExtent => 62;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final List<String> labels = <String>['', ...categories];
    return Container(
      decoration: BoxDecoration(
        color: kBackground,
        border: Border(bottom: BorderSide(color: overlapsContent || shrinkOffset > 0 ? kLine : Colors.transparent)),
      ),
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: labels.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String value = labels[index];
          return TalaChoicePill(label: value.isEmpty ? 'Todo' : value, selected: value == selected, onTap: () => onSelect(value));
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryBarDelegate oldDelegate) {
    return oldDelegate.selected != selected || oldDelegate.categories.length != categories.length;
  }
}

class DishSkeleton extends StatelessWidget {
  const DishSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SkeletonPulse(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kLine)),
          child: const Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkeletonBox(width: 150, height: 16),
                    SizedBox(height: 9),
                    SkeletonBox(height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 120, height: 12),
                    SizedBox(height: 14),
                    SkeletonBox(width: 56, height: 16),
                  ],
                ),
              ),
              SizedBox(width: 14),
              SkeletonBox(width: 96, height: 96, radius: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.model, required this.item, this.enabled = true});

  final TalaModel model;
  final FoodItem item;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: TalaCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        onTap: enabled ? () => showProductSheet(context, model, item) : () => showMessage(context, 'Este restaurante está cerrado por ahora.'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TalaText.title),
                  if (item.description.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TalaText.muted),
                  ],
                  const SizedBox(height: 10),
                  Text(money(item.price), style: TalaText.price),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  DishThumb(item: item, size: 96, radius: 16),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: kShadowSoft),
                      child: AddToCartButton(model: model, item: item, enabled: enabled),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating "Ver carrito" bar, only inside the purchase flow.
class RestaurantCartBar extends StatelessWidget {
  const RestaurantCartBar({super.key, required this.model, required this.restaurant});

  final TalaModel model;
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    if (model.cart.isEmpty || model.cartRestaurantId != restaurant.id) return const SizedBox.shrink();
    final int count = cartItemCount(model);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Reveal(
        offset: 26,
        child: PopIn(
          key: ValueKey<int>(count),
          from: 0.96,
          child: Semantics(
            button: true,
            label: 'Ver carrito, $count productos, ${money(model.subtotal)}',
            excludeSemantics: true,
            child: Pressable(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x40FF5A1F), blurRadius: 24, offset: Offset(0, 10))],
                ),
                child: Material(
                  color: kBrandDeep,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(premiumRoute(CartScreen(model: model))),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                            child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Ver carrito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          Text(money(model.subtotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Producto
// ---------------------------------------------------------------------------

void showProductSheet(BuildContext context, TalaModel model, FoodItem item) {
  final int originallyInCart = cartQuantityFor(model, item);
  int quantity = math.max(1, originallyInCart);
  String preference = '';
  const List<String> options = <String>['Sin cambios', 'Sin cebolla', 'Extra salsa', 'Bien cocido'];
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: kScrim,
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final Restaurant? restaurant = restaurantFor(model, item.restaurantId);
          final bool hasPhoto = item.imageUrl.startsWith('https://');
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
            decoration: const BoxDecoration(color: kSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: kLineStrong, borderRadius: BorderRadius.circular(99)))),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                    children: <Widget>[
                      if (hasPhoto)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 1.05, end: 1),
                              duration: TalaMotion.of(context, const Duration(milliseconds: 420)),
                              curve: TalaMotion.ease,
                              builder: (BuildContext context, double scale, Widget? child) => Transform.scale(scale: scale, child: child),
                              child: RestaurantMedia(assetPath: item.image, imageUrl: item.imageUrl),
                            ),
                          ),
                        )
                      else
                        Align(alignment: Alignment.centerLeft, child: DishThumb(item: item, size: 72, radius: 20)),
                      const SizedBox(height: 16),
                      Text(item.name, style: TalaText.h1.copyWith(fontSize: 24)),
                      if (restaurant != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(restaurant.name, style: TalaText.caption),
                      ],
                      if (item.description.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Text(item.description, style: TalaText.body),
                      ],
                      const SizedBox(height: 12),
                      Text(money(item.price), style: TalaText.price.copyWith(fontSize: 22, color: kBrandDeep)),
                      const SizedBox(height: 22),
                      const Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: <Widget>[
                          Text('Preferencias', style: TalaText.title),
                          Text('Opcional', style: TalaText.caption),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: options.map((String label) {
                          final bool selected = (label == 'Sin cambios' && preference.isEmpty) || preference == label;
                          return TalaChoicePill(
                            label: label,
                            selected: selected,
                            onTap: () => setModalState(() => preference = label == 'Sin cambios' ? '' : label),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: kLine))),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints bounds) {
                        final Widget quantityControl = QuantityStepper(
                          quantity: quantity,
                          onDecrement: quantity > (originallyInCart > 0 ? 0 : 1)
                              ? () => setModalState(() => quantity -= 1)
                              : null,
                          onIncrement: () => setModalState(() => quantity += 1),
                        );
                        final Widget addAction = FilledButton(
                          onPressed: () async {
                            if (originallyInCart > 0 &&
                                model.cartRestaurantId == item.restaurantId) {
                              model.setCartItemQuantity(item, quantity, note: preference);
                              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                            } else {
                              final bool added = await addItemWithGuard(
                                sheetContext, model, item, quantity,
                                note: preference,
                              );
                              if (added && sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            }
                          },
                          child: Text(quantity == 0 ? 'Quitar del carrito'
                              : '${originallyInCart > 0 ? 'Actualizar' : 'Agregar'} · ${money(item.price * quantity)}'),
                        );
                        if (bounds.maxWidth < 340) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: quantityControl,
                              ),
                              const SizedBox(height: 10),
                              addAction,
                            ],
                          );
                        }
                        return Row(
                          children: <Widget>[
                            quantityControl,
                            const SizedBox(width: 12),
                            Expanded(child: addAction),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
