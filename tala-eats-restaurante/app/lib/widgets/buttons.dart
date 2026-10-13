import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'motion.dart';

enum AppButtonVariant {
  /// Naranja Tala con texto carbón: acción principal de la pantalla.
  primary,

  /// Carbón con texto blanco: acción fuerte secundaria (KDS, confirmaciones).
  dark,

  /// Superficie con borde: alternativa a la principal.
  secondary,

  /// Solo texto.
  ghost,

  /// Confirmación verde (marcar listo).
  success,

  /// Destructiva sólida (confirmar eliminación/rechazo).
  danger,

  /// Destructiva discreta (abrir confirmación de rechazo/eliminación).
  dangerQuiet,
}

enum AppButtonSize { compact, regular, large }

class _ButtonColors {
  const _ButtonColors(this.background, this.foreground, [this.border]);
  final Color background;
  final Color foreground;
  final Color? border;
}

/// Botón del sistema con estados normal / presionado / cargando / éxito /
/// deshabilitado. Mientras carga conserva su color para no "parpadear".
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.loading = false,
    this.success = false,
    this.loadingLabel,
    this.successLabel,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool loading;
  final bool success;
  final String? loadingLabel;
  final String? successLabel;
  final bool expand;

  _ButtonColors get _colors {
    switch (variant) {
      case AppButtonVariant.primary:
        return const _ButtonColors(AppColors.brand, AppColors.ink);
      case AppButtonVariant.dark:
        return const _ButtonColors(AppColors.ink, Colors.white);
      case AppButtonVariant.secondary:
        return const _ButtonColors(
          AppColors.surface,
          AppColors.ink,
          AppColors.lineStrong,
        );
      case AppButtonVariant.ghost:
        return const _ButtonColors(Colors.transparent, AppColors.ink);
      case AppButtonVariant.success:
        return const _ButtonColors(AppColors.green, Colors.white);
      case AppButtonVariant.danger:
        return const _ButtonColors(AppColors.red, Colors.white);
      case AppButtonVariant.dangerQuiet:
        return const _ButtonColors(
          AppColors.surface,
          AppColors.red,
          AppColors.line,
        );
    }
  }

  double get _height {
    switch (size) {
      case AppButtonSize.compact:
        // 48 px: área táctil mínima de Android (antes 44).
        return 48;
      case AppButtonSize.regular:
        return 52;
      case AppButtonSize.large:
        return 58;
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = loading || success;
    final enabled = onPressed != null && !busy;
    final disabledLook = onPressed == null && !busy;
    final base = _colors;
    final background = disabledLook && variant != AppButtonVariant.ghost
        ? AppColors.sunken
        : base.background;
    final foreground = disabledLook ? AppColors.inkFaint : base.foreground;
    final radius = BorderRadius.circular(
      size == AppButtonSize.compact ? AppRadius.sm + 2 : AppRadius.md,
    );
    final textStyle = AppText.button.copyWith(
      color: foreground,
      fontSize: size == AppButtonSize.compact ? 14.5 : 16,
    );

    final String text;
    final Widget? leading;
    if (success) {
      text = successLabel ?? label;
      leading = Icon(Icons.check_rounded, size: 20, color: foreground);
    } else if (loading) {
      text = loadingLabel ?? label;
      leading = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: foreground),
      );
    } else {
      text = label;
      leading = icon == null ? null : Icon(icon, size: 20, color: foreground);
    }

    final content = Row(
      key: ValueKey<String>('${success ? 's' : loading ? 'l' : 'i'}$text'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leading != null) ...<Widget>[leading, const SizedBox(width: 10)],
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
      ],
    );

    final button = Pressable(
      enabled: enabled,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: base.border == null || disabledLook
              ? BorderSide.none
              : BorderSide(color: base.border!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: _height),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: size == AppButtonSize.compact ? 14 : 20,
                vertical: 10,
              ),
              child: Center(
                widthFactor: expand ? null : 1,
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      liveRegion: busy,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Botón de ícono cuadrado de 48 px con tooltip obligatorio.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
    this.dark = false,
    this.badge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool busy;
  final bool dark;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: dark ? AppColors.kdsRail : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(
              color: dark ? AppColors.kdsRailLine : AppColors.line,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onPressed,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: Motion.of(context, Motion.fast),
                    child: busy
                        ? SizedBox(
                            key: const ValueKey<String>('busy'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: fg,
                            ),
                          )
                        : Icon(
                            icon,
                            key: const ValueKey<String>('icon'),
                            size: 22,
                            color: onPressed == null
                                ? fg.withValues(alpha: 0.4)
                                : fg,
                          ),
                  ),
                  if (badge)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: dark ? AppColors.kdsRail : AppColors.surface,
                            width: 1.5,
                          ),
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
}
