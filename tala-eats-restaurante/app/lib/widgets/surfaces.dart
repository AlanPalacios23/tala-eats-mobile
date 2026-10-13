import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'motion.dart';

/// Superficie blanca con borde fino. Sin sombras pesadas (listas largas).
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor = AppColors.line,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    );
    final body = Padding(padding: padding, child: child);
    if (onTap == null) {
      return Material(color: color, shape: shape, child: body);
    }
    return Pressable(
      child: Material(
        color: color,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// Encabezado de pantalla del panel: título grande + línea de contexto.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(title, style: AppText.headline),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppText.caption.copyWith(fontSize: 14)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: AppSpace.md),
          trailing!,
        ],
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.only(top: AppSpace.xxl, bottom: AppSpace.md),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: AppText.title),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Enlace de texto compacto para encabezados de sección.
class SectionLink extends StatelessWidget {
  const SectionLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brandText,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: AppText.label.copyWith(fontSize: 14),
      ),
      child: Text(label),
    );
  }
}

/// Visual de estado de pedido: ícono + texto + tinte. Nunca solo color.
class OrderStatusVisual {
  const OrderStatusVisual(this.label, this.icon, this.foreground, this.tint);

  final String label;
  final IconData icon;
  final Color foreground;
  final Color tint;

  static OrderStatusVisual of(String status) {
    switch (status) {
      case 'received':
        return const OrderStatusVisual(
          'Nuevo',
          Icons.notifications_active_outlined,
          AppColors.brandText,
          AppColors.brandTint,
        );
      case 'confirmed':
        return const OrderStatusVisual(
          'Aceptado',
          Icons.task_alt_rounded,
          AppColors.amber,
          AppColors.amberTint,
        );
      case 'preparing':
        return const OrderStatusVisual(
          'Preparando',
          Icons.soup_kitchen_outlined,
          AppColors.amber,
          AppColors.amberTint,
        );
      case 'ready':
        return const OrderStatusVisual(
          'Listo',
          Icons.check_circle_outline_rounded,
          AppColors.green,
          AppColors.greenTint,
        );
      case 'assigned':
        return const OrderStatusVisual(
          'Repartidor asignado',
          Icons.two_wheeler_rounded,
          AppColors.green,
          AppColors.greenTint,
        );
      case 'picked_up':
      case 'on_the_way':
        return const OrderStatusVisual(
          'En camino',
          Icons.delivery_dining_outlined,
          AppColors.inkSoft,
          AppColors.sunken,
        );
      case 'delivered':
        return const OrderStatusVisual(
          'Entregado',
          Icons.done_all_rounded,
          AppColors.inkSoft,
          AppColors.sunken,
        );
      case 'cancelled':
        return const OrderStatusVisual(
          'Cancelado',
          Icons.block_rounded,
          AppColors.red,
          AppColors.redTint,
        );
      default:
        return OrderStatusVisual(
          status,
          Icons.receipt_long_outlined,
          AppColors.inkSoft,
          AppColors.sunken,
        );
    }
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.dense = false});

  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final visual = OrderStatusVisual.of(status);
    return AnimatedContainer(
      duration: Motion.of(context, Motion.base),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: visual.tint,
        borderRadius: const BorderRadius.all(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(visual.icon, size: dense ? 14 : 15, color: visual.foreground),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              visual.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(
                fontSize: dense ? 12 : 12.5,
                color: visual.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta neutra pequeña (tipo de pedido, categoría, alergenos).
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    this.icon,
    this.foreground = AppColors.inkSoft,
    this.background = AppColors.sunken,
  });

  final String label;
  final IconData? icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Métrica compacta: cifra protagonista + etiqueta.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value${caption == null ? '' : ', $caption'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: emphasis ? null : AppColors.surface,
          gradient: emphasis ? AppGradients.ink : null,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: emphasis ? AppColors.ink : AppColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: emphasis ? Colors.white70 : AppColors.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SwapText(
                value,
                style: AppText.figure.copyWith(
                  fontSize: 24,
                  color: emphasis ? Colors.white : AppColors.ink,
                ),
              ),
            ),
            if (caption != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(
                  fontSize: 12.5,
                  color: emphasis ? Colors.white60 : AppColors.inkFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila etiqueta / valor para detalles y resúmenes.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: AppText.bodySoft)),
          const SizedBox(width: AppSpace.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.body.copyWith(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                fontSize: strong ? 16.5 : 15,
                color: valueColor ?? AppColors.ink,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marca Tala Eats: cuadro naranja con monograma tipográfico.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brand,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Text(
          't',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.62,
            height: 1,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Logotipo horizontal: marca + "Tala Eats / Restaurante".
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 40});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tala Eats Restaurante',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BrandMark(size: markSize),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Tala Eats',
                style: AppText.subtitle.copyWith(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.05,
                ),
              ),
              Text(
                'Restaurante',
                style: AppText.caption.copyWith(height: 1.1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
