import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/failures.dart';
import '../core/theme.dart';
import 'buttons.dart';

enum AlertTone { info, warning, danger, success }

/// Aviso inline (no modal) para errores de formulario, sincronización o
/// alertas accionables.
class InlineAlert extends StatelessWidget {
  const InlineAlert({
    super.key,
    required this.title,
    this.message,
    this.tone = AlertTone.danger,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  factory InlineAlert.failure(
    AppFailure failure, {
    Key? key,
    VoidCallback? onRetry,
  }) =>
      InlineAlert(
        key: key,
        title: failure.title,
        message: failure.message,
        tone: failure.isConnectivity ? AlertTone.warning : AlertTone.danger,
        actionLabel: onRetry != null && failure.isRetryable ? 'Reintentar' : null,
        onAction: onRetry,
      );

  final String title;
  final String? message;
  final AlertTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    final IconData defaultIcon;
    switch (tone) {
      case AlertTone.info:
        fg = AppColors.ink;
        bg = AppColors.sunken;
        defaultIcon = Icons.info_outline_rounded;
        break;
      case AlertTone.warning:
        fg = AppColors.amber;
        bg = AppColors.amberTint;
        defaultIcon = Icons.wifi_off_rounded;
        break;
      case AlertTone.danger:
        fg = AppColors.red;
        bg = AppColors.redTint;
        defaultIcon = Icons.error_outline_rounded;
        break;
      case AlertTone.success:
        fg = AppColors.green;
        bg = AppColors.greenTint;
        defaultIcon = Icons.check_circle_outline_rounded;
        break;
    }
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon ?? defaultIcon, size: 20, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppText.label.copyWith(fontSize: 14.5, color: fg),
                    ),
                    if (message != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        message!,
                        style: AppText.caption.copyWith(color: AppColors.ink),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size(44, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: AppText.label.copyWith(fontSize: 14),
                ),
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Snackbar de producto. Reemplaza al anterior para no acumular mensajes.
void showAppSnack(
  BuildContext context,
  String message, {
  AlertTone tone = AlertTone.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final IconData? icon;
  final Color iconColor;
  switch (tone) {
    case AlertTone.success:
      icon = Icons.check_circle_rounded;
      iconColor = const Color(0xFF7FD3A4);
      break;
    case AlertTone.danger:
      icon = Icons.error_outline_rounded;
      iconColor = const Color(0xFFFF9B8F);
      break;
    case AlertTone.warning:
      icon = Icons.wifi_off_rounded;
      iconColor = const Color(0xFFFFC874);
      break;
    case AlertTone.info:
      icon = null;
      iconColor = Colors.white;
      break;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: Duration(seconds: actionLabel == null ? 3 : 5),
        content: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
}

void showFailureSnack(
  BuildContext context,
  AppFailure failure, {
  String? prefix,
  VoidCallback? onRetry,
}) {
  showAppSnack(
    context,
    prefix == null ? failure.message : '$prefix ${failure.message}',
    tone: failure.isConnectivity ? AlertTone.warning : AlertTone.danger,
    actionLabel: onRetry != null && failure.isRetryable ? 'Reintentar' : null,
    onAction: onRetry,
  );
}

/// Confirmación para acciones con consecuencias (rechazar, eliminar, cerrar).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  String cancelLabel = 'Cancelar',
  IconData? icon,
}) async {
  final badgeIcon = icon ??
      (destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded);
  final result = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: ExcludeSemantics(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: destructive ? AppColors.redTint : AppColors.sunken,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  badgeIcon,
                  size: 24,
                  color: destructive ? AppColors.red : AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppText.title.copyWith(fontSize: 21)),
          const SizedBox(height: 8),
          Text(message, style: AppText.bodySoft),
          const SizedBox(height: 24),
          AppButton(
            label: confirmLabel,
            variant:
                destructive ? AppButtonVariant.danger : AppButtonVariant.dark,
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(true);
            },
          ),
          const SizedBox(height: 10),
          AppButton(
            label: cancelLabel,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
