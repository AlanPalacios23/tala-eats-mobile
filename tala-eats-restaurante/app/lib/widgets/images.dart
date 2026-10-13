import 'dart:io';

import 'package:flutter/material.dart';

import '../core/failures.dart';
import '../core/theme.dart';
import '../data/repositories.dart';

/// Ícono representativo por categoría para placeholders de producto.
IconData categoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('bebida') || c.contains('agua') || c.contains('café')) {
    return Icons.local_drink_outlined;
  }
  if (c.contains('postre') || c.contains('dulce') || c.contains('helado')) {
    return Icons.icecream_outlined;
  }
  if (c.contains('combo') || c.contains('paquete')) {
    return Icons.takeout_dining_outlined;
  }
  if (c.contains('pizza')) return Icons.local_pizza_outlined;
  if (c.contains('hamburg')) return Icons.lunch_dining_outlined;
  if (c.contains('sushi') || c.contains('marisc') || c.contains('pesc')) {
    return Icons.set_meal_outlined;
  }
  if (c.contains('ensalada')) return Icons.eco_outlined;
  return Icons.restaurant_outlined;
}

/// Imagen con placeholder neutro → fade-in, y fallback limpio si falla.
///
/// `source` es una referencia de imagen: ruta local hoy, URL `https://`
/// cuando exista storage remoto. Decodifica al tamaño mostrado para no
/// cargar fotos completas en listas.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.restaurant_outlined,
    this.semanticLabel,
    this.iconSize = 26,
  });

  final String source;
  final BoxFit fit;
  final IconData placeholderIcon;
  final String? semanticLabel;
  final double iconSize;

  bool get _isRemote =>
      source.startsWith('http://') || source.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (source.trim().isEmpty) {
      return _ImagePlaceholder(icon: placeholderIcon, size: iconSize);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2;
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 1
            ? (constraints.maxWidth * dpr).round()
            : null;
        final fadeDuration = Motion.of(context, Motion.base);

        Widget frame(
          BuildContext context,
          Widget child,
          int? frameIndex,
          bool syncLoaded,
        ) {
          if (syncLoaded) return child;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _ImagePlaceholder(icon: placeholderIcon, size: iconSize),
              AnimatedOpacity(
                opacity: frameIndex == null ? 0.0 : 1.0,
                duration: fadeDuration,
                curve: Curves.easeOut,
                child: child,
              ),
            ],
          );
        }

        Widget error(BuildContext context, Object e, StackTrace? s) =>
            _ImagePlaceholder(
              icon: Icons.image_not_supported_outlined,
              size: iconSize,
              label: constraints.maxWidth >= 140 ? 'Foto no disponible' : null,
            );

        final Widget image = _isRemote
            ? Image.network(
                source,
                fit: fit,
                cacheWidth: width,
                gaplessPlayback: true,
                frameBuilder: frame,
                errorBuilder: error,
              )
            : Image.file(
                File(source),
                fit: fit,
                cacheWidth: width,
                gaplessPlayback: true,
                frameBuilder: frame,
                errorBuilder: error,
              );
        return Semantics(
          image: true,
          label: semanticLabel,
          child: SizedBox.expand(child: image),
        );
      },
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon, required this.size, this.label});

  final IconData icon;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sunken,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: size, color: AppColors.inkFaint),
          if (label != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              label!,
              style: AppText.caption.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

/// Miniatura cuadrada redondeada para listas.
class AppThumbnail extends StatelessWidget {
  const AppThumbnail({
    super.key,
    required this.source,
    required this.size,
    this.icon = Icons.restaurant_outlined,
    this.radius = AppRadius.md,
    this.dimmed = false,
  });

  final String source;
  final double size;
  final IconData icon;
  final double radius;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: AppImage(source: source, placeholderIcon: icon, iconSize: size * 0.36),
      ),
    );
    if (!dimmed) return image;
    return Opacity(opacity: 0.45, child: image);
  }
}

/// Pide al usuario el origen de la foto.
Future<MediaSource?> chooseMediaSource(BuildContext context) {
  return showModalBottomSheet<MediaSource>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto', style: AppText.subtitle),
            onTap: () => Navigator.of(context).pop(MediaSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería', style: AppText.subtitle),
            onTap: () => Navigator.of(context).pop(MediaSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Campo de foto con estados: vacío, procesando, con foto, error.
class PhotoField extends StatefulWidget {
  const PhotoField({
    super.key,
    required this.media,
    required this.purpose,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.helper,
    this.aspectRatio = 4 / 3,
    this.isRequired = false,
    this.errorText,
    this.placeholderIcon = Icons.add_a_photo_outlined,
  });

  final MediaRepository media;
  final MediaPurpose purpose;
  final String value;
  final ValueChanged<String> onChanged;
  final String title;
  final String helper;
  final double aspectRatio;
  final bool isRequired;
  final String? errorText;
  final IconData placeholderIcon;

  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  bool _processing = false;
  AppFailure? _failure;

  Future<void> _pick() async {
    if (_processing) return;
    final source = await chooseMediaSource(context);
    if (source == null || !mounted) return;
    setState(() {
      _processing = true;
      _failure = null;
    });
    try {
      final picked = await widget.media.pickImage(
        source: source,
        purpose: widget.purpose,
      );
      if (!mounted) return;
      if (picked != null) widget.onChanged(picked);
    } catch (error) {
      if (mounted) setState(() => _failure = AppFailure.from(error));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _remove() {
    setState(() => _failure = null);
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.value.trim().isNotEmpty;
    final failureText = _failure?.message;
    final error = widget.errorText ?? failureText;
    final borderColor = error != null
        ? AppColors.red
        : hasPhoto
            ? Colors.transparent
            : AppColors.lineStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Row(
            children: <Widget>[
              Flexible(child: Text(widget.title, style: AppText.label)),
              const SizedBox(width: 6),
              Text(
                widget.isRequired ? 'Obligatoria' : 'Opcional',
                style: AppText.caption.copyWith(
                  fontSize: 12.5,
                  color: widget.isRequired ? AppColors.brandText : AppColors.inkSoft,
                  fontWeight: widget.isRequired ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: hasPhoto
              ? '${widget.title}. Toca para cambiarla'
              : '${widget.title}. Toca para agregarla',
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: CustomPaint(
              foregroundPainter: hasPhoto && error == null
                  ? null
                  : _DashedBorderPainter(
                      color: borderColor,
                      radius: AppRadius.lg,
                      dashed: error == null,
                    ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Material(
                  color: hasPhoto ? AppColors.sunken : AppColors.surface,
                  child: InkWell(
                    onTap: _pick,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (hasPhoto)
                          AppImage(source: widget.value)
                        else
                          _EmptyPhoto(
                            icon: widget.placeholderIcon,
                            helper: widget.helper,
                          ),
                        if (hasPhoto && !_processing && error == null)
                          const Positioned(
                            left: 10,
                            top: 10,
                            child: _ReadyBadge(),
                          ),
                        if (hasPhoto && !_processing)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Row(
                              children: <Widget>[
                                _PhotoAction(
                                  icon: Icons.sync_rounded,
                                  label: 'Cambiar',
                                  onTap: _pick,
                                ),
                                if (!widget.isRequired) ...<Widget>[
                                  const SizedBox(width: 8),
                                  _PhotoAction(
                                    icon: Icons.delete_outline_rounded,
                                    label: 'Quitar',
                                    onTap: _remove,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        AnimatedSwitcher(
                          duration: Motion.of(context, Motion.base),
                          child: _processing
                              ? Container(
                                  key: const ValueKey<String>('processing'),
                                  color: AppColors.surface.withValues(alpha: 0.86),
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      SizedBox(
                                        width: 26,
                                        height: 26,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Preparando foto…',
                                        style: AppText.label,
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey<String>('idle'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.base),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8, left: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 17,
                        color: AppColors.red,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          error,
                          style: AppText.caption.copyWith(
                            color: AppColors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _EmptyPhoto extends StatelessWidget {
  const _EmptyPhoto({required this.icon, required this.helper});

  final IconData icon;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _content(
        // Solo si cabe sin apretar (portadas 16:9 en teléfono angosto no).
        showFormats: constraints.maxHeight >= 220,
      ),
    );
  }

  Widget _content({required bool showFormats}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.brandText, size: 26),
          ),
          const SizedBox(height: 12),
          const Text('Agregar foto', style: AppText.subtitle),
          const SizedBox(height: 4),
          Text(
            helper,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption,
          ),
          if (showFormats) ...<Widget>[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: AppColors.sunken,
              borderRadius: BorderRadius.all(AppRadius.pill),
            ),
            child: Text(
              'JPG, PNG o WEBP · cámara o galería',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }
}

/// Confirma que la foto quedó lista para guardarse (aparece con un fundido).
class _ReadyBadge extends StatelessWidget {
  const _ReadyBadge();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.of(context, Motion.slow),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
        decoration: const BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.all(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.check_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              'Foto lista',
              style: AppText.label.copyWith(fontSize: 12.5, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink.withValues(alpha: 0.82),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 17, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppText.label.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashed,
  });

  final Color color;
  final double radius;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 1.4 : 1.6;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.7),
      Radius.circular(radius),
    );
    if (!dashed) {
      canvas.drawRRect(rrect, paint);
      return;
    }
    final path = Path()..addRRect(rrect);
    const dash = 7.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end.toDouble()), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashed != dashed;
}
