import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'motion.dart';

// ===========================================================================
// Formato
// ===========================================================================

/// `1234.5` → `$1,234.50`
String money(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = fixed.substring(0, dot);
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
    buffer.write(whole[i]);
  }
  return '${negative ? '-' : ''}\$$buffer${fixed.substring(dot)}';
}

/// `342` → `5 h 42 min`
String formatMinutes(int minutes) {
  if (minutes <= 0) return '0 min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// `342` → `5h 42m` (para métricas compactas)
String formatMinutesCompact(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

/// `13:05`
String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String formatKm(double km) => '${km.toStringAsFixed(1)} km';

const List<String> kWeekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const List<String> kWeekdayInitials = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

const List<String> _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

/// `Sábado 10 de octubre`
String formatLongDate(DateTime date) => capitalize(
      '${kWeekdays[date.weekday - 1]} ${date.day} de ${_months[date.month - 1]}',
    );

// ===========================================================================
// Layout
// ===========================================================================

/// Contenedor de pantalla con scroll, safe area y márgenes consistentes.
class ScreenPad extends StatelessWidget {
  const ScreenPad({super.key, required this.child, this.onRefresh});

  final Widget child;

  /// Si se define, habilita "deslizar para actualizar".
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.l,
        Space.gutter,
        Space.xxxl,
      ),
      child: child,
    );
    return SafeArea(
      bottom: false,
      child: onRefresh == null
          ? scroll
          : RefreshIndicator(
              color: kInk,
              backgroundColor: kSurface,
              onRefresh: onRefresh!,
              child: scroll,
            ),
    );
  }
}

class ScreenHeading extends StatelessWidget {
  const ScreenHeading({
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
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: AppText.screenTitle),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: Space.xs),
          Text(subtitle!, style: AppText.bodyMuted),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = trailing != null &&
            (constraints.maxWidth < 320 || scale >= 1.25);
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              textBlock,
              const SizedBox(height: Space.m),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: textBlock),
            if (trailing != null) ...[
              const SizedBox(width: Space.m),
              trailing!,
            ],
          ],
        );
      },
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final title = Semantics(
      header: true,
      child: Text(text, style: AppText.section),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s + 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (trailing != null &&
              (constraints.maxWidth < 300 || scale >= 1.25)) {
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Space.s,
              runSpacing: Space.xs,
              children: [title, trailing!],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              if (trailing != null) trailing!,
            ],
          );
        },
      ),
    );
  }
}

/// Superficie base: blanca, borde fino, sin sombra. Opcionalmente tocable.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.l),
    this.onTap,
    this.color = kSurface,
    this.borderColor = kLine,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final content = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.lg,
        child: Padding(padding: padding, child: child),
      ),
    );
    final decoration = BoxDecoration(
      color: color,
      borderRadius: Radii.lg,
      border: Border.all(color: borderColor),
    );
    final cardChild = onTap == null
        ? Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          )
        : content;
    final card = reduced
        ? Container(
            decoration: decoration,
            clipBehavior: Clip.antiAlias,
            child: cardChild,
          )
        : AnimatedContainer(
            duration: Motion.short,
            curve: Motion.standard,
            decoration: decoration,
            clipBehavior: Clip.antiAlias,
            child: cardChild,
          );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: PressableScale(child: card),
    );
  }
}

// ===========================================================================
// Métricas
// ===========================================================================

class MetricItem {
  const MetricItem({required this.label, required this.value});

  final String label;

  /// Normalmente un [Text] o [AnimatedNumber] con [AppText.metric].
  final Widget value;
}

/// Fila compacta de métricas separadas por divisores verticales.
class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.items});

  final List<MetricItem> items;

  @override
  Widget build(BuildContext context) {
    Widget metric(MetricItem item) => Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle.merge(
                  style: AppText.metric,
                  maxLines: 1,
                  child: item.value,
                ),
              ),
              const SizedBox(height: Space.xxs),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
            ],
          ),
        );

    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 315 || scale >= 1.25;
        if (compact) {
          final columns = items.length <= 2 ? items.length : 2;
          final gap = Space.l;
          final width =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: Space.l,
            children: [
              for (final item in items) SizedBox(width: width, child: metric(item)),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Space.m),
                    child: VerticalDivider(width: 1),
                  ),
                Expanded(child: metric(items[i])),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Botones
// ===========================================================================

/// CTA principal de ancho completo con estados normal / pressed / loading /
/// disabled claramente diferenciados.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.loadingLabel,
    this.semanticHint,
    this.stackOnNarrow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final String? loadingLabel;
  final String? semanticHint;

  /// Apila icono/indicador sobre el texto en anchos estrechos o texto grande.
  /// Se activa solo en CTAs que lo requieren para preservar el layout existente.
  final bool stackOnNarrow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final reduced = Motion.reduced(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    final Widget indicator = SizedBox.square(
      dimension: 18,
      child: reduced
          ? const Icon(
              Icons.hourglass_top_rounded,
              size: 18,
              color: Colors.white,
            )
          : const CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
    );

    Widget buildContent({
      required Key key,
      required Widget? leading,
      required String text,
      required bool compactContent,
    }) {
      final textWidget = Text(
        text,
        textAlign: TextAlign.center,
        maxLines: compactContent ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      );
      if (leading == null) {
        return KeyedSubtree(key: key, child: textWidget);
      }
      if (compactContent) {
        return Column(
          key: key,
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(height: Space.xs),
            textWidget,
          ],
        );
      }
      return Row(
        key: key,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: Space.s + 2),
          Flexible(child: textWidget),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final compactContent = stackOnNarrow &&
            (availableWidth < 320 || textScale >= 1.25);
        final Widget content = loading
            ? buildContent(
                key: const ValueKey('loading'),
                leading: indicator,
                text: loadingLabel ?? 'Cargando…',
                compactContent: compactContent,
              )
            : buildContent(
                key: ValueKey('label:$label'),
                leading: icon == null ? null : Icon(icon, size: 20),
                text: label,
                compactContent: compactContent,
              );

        return Semantics(
          hint: semanticHint,
          child: PressableScale(
            enabled: enabled,
            scale: .98,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: enabled ? onPressed : null,
                style: loading
                    ? FilledButton.styleFrom(
                        disabledBackgroundColor: kInk.withValues(alpha: .86),
                        disabledForegroundColor: Colors.white,
                      )
                    : null,
                child: StateSwitcher(
                  duration: Motion.short,
                  rise: 4,
                  animateSize: false,
                  alignment: Alignment.center,
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );

  }
}

// ===========================================================================
// Avisos y estados
// ===========================================================================

enum Tone { neutral, success, warning, error, brand }

extension ToneColors on Tone {
  Color get foreground => switch (this) {
        Tone.neutral => kInk,
        Tone.success => kGreen,
        Tone.warning => kAmber,
        Tone.error => kRed,
        Tone.brand => kBrandInk,
      };

  Color get background => switch (this) {
        Tone.neutral => kSurfaceSunken,
        Tone.success => kSoftGreen,
        Tone.warning => kSoftAmber,
        Tone.error => kSoftRed,
        Tone.brand => kSoftOrange,
      };
}

/// Banner contextual (bloqueos, errores recuperables, confirmaciones).
/// Úsalo dentro de [Reveal] para entrada/salida suave.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.icon,
    required this.message,
    this.tone = Tone.neutral,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final IconData icon;
  final String message;
  final Tone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            Space.m + 2,
            Space.s + 2,
            Space.xs,
            Space.s + 2,
          ),
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: Radii.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: tone.foreground),
              const SizedBox(width: Space.s + 2),
              Expanded(
                child: Text(
                  message,
                  style: AppText.body.copyWith(
                    color: tone == Tone.neutral ? kInk : tone.foreground,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: tone.foreground,
                  ),
                  child: Text(actionLabel!),
                )
              else if (onDismiss != null)
                IconButton(
                  tooltip: 'Cerrar aviso',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 18, color: kMuted),
                )
              else
                const SizedBox(width: Space.s + 2),
            ],
          ),
        ),
      );
}

/// Aviso discreto en línea (sin fondo).
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.icon,
    required this.text,
    this.color = kMuted,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: AppText.caption)),
        ],
      );
}

/// Estado vacío / sin datos / error diseñado (no improvisado).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone = Tone.neutral,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Tone tone;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: EdgeInsets.symmetric(
          horizontal: Space.xl,
          vertical: compact ? Space.xl : Space.xxl + 4,
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tone.background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: tone == Tone.neutral ? kMuted : tone.foreground,
                size: 26,
              ),
            ),
            const SizedBox(height: Space.m + 2),
            Text(title, style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: Space.xs + 2),
            Text(
              message,
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Space.l + 2),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.refresh_rounded, size: 19),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
}

/// Chip de estado (texto + icono; nunca solo color).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = Tone.neutral,
  });

  final String label;
  final IconData? icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: tone.foreground),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
    final decoration = BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(Radii.pill),
    );
    if (Motion.reduced(context)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: decoration,
        child: child,
      );
    }
    return AnimatedContainer(
      duration: Motion.short,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: decoration,
      child: child,
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.initials, this.size = 44});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: kInk, shape: BoxShape.circle),
          child: Text(
            initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * .3,
              letterSpacing: .4,
            ),
          ),
        ),
      );
}

/// Contenedor cuadrado de icono con tono suave.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    this.tone = Tone.neutral,
    this.size = 40,
  });

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(size * .3),
    );
    final child = Icon(
      icon,
      size: size * .5,
      color: tone == Tone.neutral ? kInk : tone.foreground,
    );
    if (Motion.reduced(context)) {
      return Container(
        width: size,
        height: size,
        decoration: decoration,
        child: child,
      );
    }
    return AnimatedContainer(
      duration: Motion.short,
      curve: Motion.standard,
      width: size,
      height: size,
      decoration: decoration,
      child: child,
    );
  }
}

/// Fila tocable genérica para listas agrupadas.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tone = Tone.neutral,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.l,
              vertical: Space.m,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactTrailing = trailing != null &&
                    (constraints.maxWidth < 290 || scale >= 1.25);
                final textBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: compactTrailing ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: Space.xxs),
                      Text(
                        subtitle!,
                        maxLines: compactTrailing ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    ],
                    if (compactTrailing) ...[
                      const SizedBox(height: Space.s),
                      Align(alignment: Alignment.centerLeft, child: trailing!),
                    ],
                  ],
                );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconTile(icon: icon, tone: tone, size: 38),
                    const SizedBox(width: Space.m + 2),
                    Expanded(child: textBlock),
                    if (!compactTrailing && trailing != null) ...[
                      const SizedBox(width: Space.s),
                      Flexible(child: trailing!),
                    ] else if (trailing == null && onTap != null) ...[
                      const SizedBox(width: Space.s),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: kMuted,
                        size: 22,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Par etiqueta/valor para hojas de detalle.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasize
        ? AppText.money.copyWith(fontSize: 16)
        : AppText.body.copyWith(fontWeight: FontWeight.w700);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 300 || scale >= 1.25) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.bodyMuted),
                const SizedBox(height: Space.xs),
                Text(value, style: valueStyle),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: Text(label, style: AppText.bodyMuted)),
              const SizedBox(width: Space.m),
              Expanded(
                flex: 6,
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: valueStyle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Snackbar unificado (flotante, con icono, nunca tapa CTAs críticos).
void showAppSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.info_outline_rounded,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 2600),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: Space.m),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Hoja inferior estándar con título y contenido desplazable.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            0,
            Space.xl,
            Space.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: AppText.stageTitle),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: Space.xs),
                Text(subtitle, style: AppText.bodyMuted),
              ],
              const SizedBox(height: Space.l),
              builder(sheetContext),
            ],
          ),
        ),
      ),
    );

/// Acción secundaria compacta de orientación (Navegar, Llamar…).
/// Nivel 2 de jerarquía: visible y a 44 dp, sin competir con el CTA.
class CompactAction extends StatelessWidget {
  const CompactAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semanticLabel,
        child: PressableScale(
          enabled: onPressed != null,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: kSurface,
              side: const BorderSide(color: kLineStrong),
              textStyle: AppText.button.copyWith(fontSize: 14),
            ),
            icon: Icon(icon, size: 18),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      );
}
