import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/entities.dart';
import '../../state/operations_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/images.dart';
import '../../widgets/motion.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/states.dart';
import '../../widgets/surfaces.dart';
import 'product_editor_screen.dart';

const String _allCategories = 'Todos';
const String _attentionFilter = '__attention__';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.ops});

  final OperationsController ops;

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
              key: const ValueKey<String>('menu-failure'),
              child: SingleChildScrollView(
                child: StateView.failure(ops.loadFailure!, onRetry: ops.retry),
              ),
            );
          } else if (!ops.hasData) {
            content = const _MenuSkeleton(key: ValueKey<String>('menu-loading'));
          } else {
            content = _MenuContent(key: const ValueKey<String>('menu-ready'), ops: ops);
          }
          return StateSwitcher(expand: true, child: content);
        },
      ),
    );
  }
}

/// Abre el editor y muestra la confirmación al volver.
Future<void> openProductEditor(
  BuildContext context,
  OperationsController ops, [
  MenuProduct? product,
]) async {
  final message = await Navigator.of(context).push<String>(
    appRoute<String>(ProductEditorScreen(ops: ops, product: product)),
  );
  if (message != null && context.mounted) {
    showAppSnack(context, message, tone: AlertTone.success);
  }
}

class _MenuContent extends StatefulWidget {
  const _MenuContent({super.key, required this.ops});

  final OperationsController ops;

  @override
  State<_MenuContent> createState() => _MenuContentState();
}

class _MenuContentState extends State<_MenuContent> {
  final _search = TextEditingController();
  String _query = '';
  String _category = _allCategories;

  OperationsController get ops => widget.ops;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() {
      _query = '';
      _category = _allCategories;
    });
  }

  Future<void> _toggle(MenuProduct product, bool value) async {
    final failure = await ops.setProductAvailability(product, value);
    if (!mounted) return;
    if (failure != null) {
      showFailureSnack(
        context,
        failure,
        prefix: 'No se cambió "${product.name}".',
        onRetry: () => _toggle(product, value),
      );
    } else {
      showAppSnack(
        context,
        value
            ? '${product.name} ya está disponible.'
            : '${product.name} quedó pausado.',
        tone: value ? AlertTone.success : AlertTone.info,
      );
    }
  }

  Future<void> _refresh() async {
    final failure = await ops.refresh();
    if (failure != null && mounted) showFailureSnack(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final menu = ops.menu;
    final categories = <String>{for (final p in menu) p.category}.toList()
      ..sort();
    final attention = menu.where((p) => p.needsAttention).length;
    if (_category != _allCategories &&
        _category != _attentionFilter &&
        !categories.contains(_category)) {
      _category = _allCategories;
    }
    final q = _query.trim().toLowerCase();
    final filtered = menu.where((p) {
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      final matchesCategory = _category == _allCategories ||
          (_category == _attentionFilter
              ? p.needsAttention
              : p.category == _category);
      return matchesQuery && matchesCategory;
    }).toList(growable: false);
    final available = menu.where((p) => p.isAvailable && p.stock > 0).length;
    final rowExtent = MediaQuery.textScalerOf(context).scale(100) + 8;

    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: _refresh,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.lg,
                AppSpace.gutter,
                AppSpace.md,
              ),
              child: ScreenHeader(
                title: 'Menú',
                subtitle: menu.isEmpty
                    ? 'Agrega tu primer producto'
                    : '${plural(menu.length, 'producto', 'productos')}, '
                        '$available disponibles',
                trailing: AppButton(
                  key: const ValueKey<String>('addProductButton'),
                  label: 'Nuevo',
                  icon: Icons.add_rounded,
                  size: AppButtonSize.compact,
                  expand: false,
                  onPressed: () => openProductEditor(context, ops),
                ),
              ),
            ),
          ),
          if (menu.isNotEmpty) ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  0,
                  AppSpace.gutter,
                  AppSpace.sm,
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  style: AppText.body.copyWith(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Buscar en tu menú',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.gutter,
                    vertical: 6,
                  ),
                  children: <Widget>[
                    if (attention > 0)
                      _FilterChip(
                        label: 'Revisar',
                        count: attention,
                        icon: Icons.warning_amber_rounded,
                        selected: _category == _attentionFilter,
                        onTap: () => setState(() => _category = _attentionFilter),
                      ),
                    _FilterChip(
                      label: _allCategories,
                      selected: _category == _allCategories,
                      onTap: () => setState(() => _category = _allCategories),
                    ),
                    for (final c in categories)
                      _FilterChip(
                        label: c,
                        selected: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (menu.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: StateView(
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Tu menú está vacío',
                  message: 'Agrega productos con foto, precio y stock para '
                      'que los clientes puedan pedirlos.',
                  actionLabel: 'Agregar producto',
                  onAction: () => openProductEditor(context, ops),
                ),
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: StateView(
                  icon: Icons.search_off_rounded,
                  title: _query.isEmpty
                      ? 'Sin productos en esta vista'
                      : 'Sin resultados para "${_query.trim()}"',
                  message: 'Prueba con otro nombre o revisa otra categoría.',
                  actionLabel: 'Ver todo el menú',
                  onAction: _clearSearch,
                ),
              ),
            )
          else
            ..._productSlivers(filtered, rowExtent),
        ],
      ),
    );
  }

  Widget _grid(
    List<MenuProduct> products,
    double rowExtent,
    EdgeInsets padding,
  ) {
    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 560,
          mainAxisExtent: rowExtent,
          mainAxisSpacing: 10,
          crossAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            return _ProductRow(
              key: ValueKey<int>(product.id),
              product: product,
              pending: ops.isProductPending(product.id),
              onTap: () => openProductEditor(context, ops, product),
              onToggle: (value) => _toggle(product, value),
            );
          },
          childCount: products.length,
        ),
      ),
    );
  }

  /// En «Todos» y sin búsqueda, el catálogo se agrupa por categoría (como en
  /// los paneles de comercio de las grandes apps de reparto). Con filtro o
  /// búsqueda se mantiene la lista plana.
  List<Widget> _productSlivers(List<MenuProduct> products, double rowExtent) {
    final categories = <String>[];
    for (final p in products) {
      if (!categories.contains(p.category)) categories.add(p.category);
    }
    final grouped = _category == _allCategories &&
        _query.trim().isEmpty &&
        categories.length > 1;
    if (!grouped) {
      return <Widget>[
        _grid(
          products,
          rowExtent,
          const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.sm,
            AppSpace.gutter,
            AppSpace.xxxl,
          ),
        ),
      ];
    }
    categories.sort();
    final slivers = <Widget>[];
    for (var i = 0; i < categories.length; i++) {
      final name = categories[i];
      final items = products
          .where((p) => p.category == name)
          .toList(growable: false);
      final unavailable = items
          .where((p) =>
              p.stockLevel == StockLevel.soldOut ||
              p.stockLevel == StockLevel.paused)
          .length;
      slivers
        ..add(
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                i == 0 ? AppSpace.sm : AppSpace.xl,
                AppSpace.gutter,
                AppSpace.sm,
              ),
              child: _CategoryHeader(
                key: ValueKey<String>('menuCategory-$name'),
                name: name,
                count: items.length,
                unavailable: unavailable,
              ),
            ),
          ),
        )
        ..add(
          _grid(
            items,
            rowExtent,
            EdgeInsets.fromLTRB(
              AppSpace.gutter,
              0,
              AppSpace.gutter,
              i == categories.length - 1 ? AppSpace.xxxl : 0,
            ),
          ),
        );
    }
    return slivers;
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    super.key,
    required this.name,
    required this.count,
    required this.unavailable,
  });

  final String name;
  final int count;
  final int unavailable;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: '$name, ${plural(count, 'producto', 'productos')}'
          '${unavailable == 0 ? '' : ', $unavailable sin disponibilidad'}',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          Icon(categoryIcon(name), size: 19, color: AppColors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title.copyWith(fontSize: 17),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: AppText.label.copyWith(
              color: AppColors.inkFaint,
              fontFeatures: AppFonts.tabular,
            ),
          ),
          if (unavailable > 0) ...<Widget>[
            const SizedBox(width: 8),
            Tag(
              label: unavailable == 1
                  ? '1 no disponible'
                  : '$unavailable no disponibles',
              foreground: AppColors.red,
              background: AppColors.redTint,
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.ink : AppColors.surface,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? AppColors.ink : AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(
                      icon,
                      size: 17,
                      color: selected ? Colors.white : AppColors.amber,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    count == null ? label : '$label $count',
                    style: AppText.label.copyWith(fontSize: 14, color: fg),
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

class _StockLine extends StatelessWidget {
  const _StockLine({required this.product});

  final MenuProduct product;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String text;
    switch (product.stockLevel) {
      case StockLevel.ok:
        icon = Icons.inventory_2_outlined;
        color = AppColors.inkSoft;
        text = 'Stock ${product.stock}';
        break;
      case StockLevel.low:
        icon = Icons.warning_amber_rounded;
        color = AppColors.amber;
        text = 'Quedan ${product.stock}';
        break;
      case StockLevel.soldOut:
        icon = Icons.remove_shopping_cart_outlined;
        color = AppColors.red;
        text = 'Agotado';
        break;
      case StockLevel.paused:
        icon = Icons.pause_circle_outline_rounded;
        color = AppColors.inkSoft;
        text = 'Pausado';
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppText.label.copyWith(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    super.key,
    required this.product,
    required this.pending,
    required this.onTap,
    required this.onToggle,
  });

  final MenuProduct product;
  final bool pending;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final unavailable = !product.isAvailable || product.stock <= 0;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          _ProductPhoto(product: product, dimmed: unavailable),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle.copyWith(
                    fontSize: 15.5,
                    color: unavailable ? AppColors.inkSoft : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 3,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      money(product.price),
                      style: AppText.label.copyWith(
                        fontSize: 14.5,
                        fontFeatures: AppFonts.tabular,
                      ),
                    ),
                    _StockLine(product: product),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: pending
                    ? const SizedBox(
                        key: ValueKey<String>('pending'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Semantics(
                        key: const ValueKey<String>('switch'),
                        label: '${product.name}: disponible para clientes',
                        child: Switch(
                          value: product.isAvailable,
                          onChanged: onToggle,
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

/// Foto del producto con sello «Agotado» / «Pausado» (texto, no solo
/// opacidad) para leer el estado del catálogo de un vistazo.
class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({required this.product, required this.dimmed});

  final MenuProduct product;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final level = product.stockLevel;
    final seal = level == StockLevel.soldOut
        ? 'Agotado'
        : level == StockLevel.paused
            ? 'Pausado'
            : null;
    final thumb = AppThumbnail(
      source: product.imagePath,
      size: 76,
      icon: categoryIcon(product.category),
      dimmed: dimmed,
    );
    if (seal == null) return thumb;
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: <Widget>[
          thumb,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: level == StockLevel.soldOut
                      ? AppColors.red
                      : AppColors.ink,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  seal,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: AppText.label.copyWith(
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 0.2,
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

class _MenuSkeleton extends StatelessWidget {
  const _MenuSkeleton({super.key});

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
        const Text('Menú', style: AppText.headline),
        const SizedBox(height: 8),
        const Shimmer(child: Bone(width: 170)),
        const SizedBox(height: 22),
        const Shimmer(child: Bone(height: 52, radius: AppRadius.md)),
        const SizedBox(height: 18),
        for (var i = 0; i < 5; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: BoneCard(
              padding: EdgeInsets.all(10),
              child: Shimmer(
                child: Row(
                  children: <Widget>[
                    Bone(width: 76, height: 76, radius: AppRadius.md),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Bone(height: 15),
                          SizedBox(height: 8),
                          Bone(width: 130, height: 13),
                        ],
                      ),
                    ),
                    SizedBox(width: 14),
                    Bone(width: 48, height: 28, radius: 14),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
