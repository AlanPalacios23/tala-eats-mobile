import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/failures.dart';
import '../../core/theme.dart';
import '../../data/device_location.dart';
import '../../data/location_store.dart';
import '../../models/restaurant_location.dart';
import '../../state/operations_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/fields.dart';

/// Abre la pantalla de ubicación del restaurante actual. Devuelve el mensaje
/// de confirmación si se guardó.
Future<String?> openRestaurantLocation(
  BuildContext context,
  OperationsController ops,
) {
  final restaurant = ops.restaurant;
  if (restaurant == null) return Future<String?>.value();
  return Navigator.of(context).push<String>(
    appRoute<String>(
      RestaurantLocationScreen(
        restaurantId: restaurant.id,
        store: ops.services.locationStore,
        device: ops.services.deviceLocation,
      ),
    ),
  );
}

/// Precisión a partir de la cual pedimos repetir la lectura GPS.
const double kImpreciseGpsMeters = 100;

/// Ubicación del establecimiento: dirección escrita + punto GPS del teléfono.
/// El backend usa estos datos para calcular distancias y envíos; la app no
/// calcula nada con ellos.
class RestaurantLocationScreen extends StatefulWidget {
  const RestaurantLocationScreen({
    super.key,
    required this.restaurantId,
    required this.store,
    required this.device,
  });

  final int restaurantId;
  final RestaurantLocationStore store;
  final DeviceLocationProvider device;

  @override
  State<RestaurantLocationScreen> createState() =>
      _RestaurantLocationScreenState();
}

class _RestaurantLocationScreenState extends State<RestaurantLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _street = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  final _references = TextEditingController();

  GpsFix? _fix;
  LocationIssue? _issue;
  AppFailure? _failure;
  bool _loading = true;
  bool _locating = false;
  bool _saving = false;
  bool _saved = false;
  bool _attempted = false;
  bool _dirty = false;

  List<TextEditingController> get _fields => <TextEditingController>[
        _street,
        _neighborhood,
        _city,
        _postal,
        _references,
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final existing = await widget.store.load(widget.restaurantId);
    if (!mounted) return;
    setState(() {
      if (existing != null) {
        _street.text = existing.street;
        _neighborhood.text = existing.neighborhood;
        _city.text = existing.city;
        _postal.text = existing.postalCode;
        _references.text = existing.references;
        final lat = existing.latitude;
        final lng = existing.longitude;
        if (lat != null && lng != null) {
          _fix = GpsFix(
            latitude: lat,
            longitude: lng,
            accuracyMeters: existing.accuracyMeters ?? 0,
          );
        }
      }
      _loading = false;
    });
    for (final c in _fields) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    if (_locating) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _locating = true;
      _issue = null;
    });
    try {
      final fix = await widget.device.currentFix();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _fix = fix;
        _dirty = true;
      });
    } on LocationIssue catch (issue) {
      if (mounted) setState(() => _issue = issue);
    } catch (_) {
      if (mounted) {
        setState(
          () => _issue = const LocationIssue(LocationIssueKind.unavailable),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openSettings(LocationIssue issue) async {
    await widget.device.openSettings(issue.kind);
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() {
      _attempted = true;
      _failure = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.lightImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    final fix = _fix;
    final location = RestaurantLocation(
      street: _street.text.trim(),
      neighborhood: _neighborhood.text.trim(),
      city: _city.text.trim(),
      postalCode: _postal.text.trim(),
      references: _references.text.trim(),
      latitude: fix?.latitude,
      longitude: fix?.longitude,
      accuracyMeters: fix?.accuracyMeters,
    );
    setState(() => _saving = true);
    try {
      final saved = await widget.store.save(widget.restaurantId, location);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _saving = false;
        _saved = true;
        _dirty = false;
      });
      await Future<void>.delayed(
        Motion.reduced(context)
            ? const Duration(milliseconds: 150)
            : const Duration(milliseconds: 520),
      );
      if (!mounted) return;
      Navigator.of(context).pop<String>(
        saved.syncedToServer
            ? 'Ubicación guardada en Tala Eats.'
            : 'Ubicación guardada en este teléfono.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failure = AppFailure.from(error);
      });
    }
  }

  Future<void> _handlePop() async {
    if (_saving) return;
    final leave = await confirmAction(
      context,
      title: '¿Descartar la ubicación?',
      message: 'Los cambios a la dirección no se guardarán.',
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
      destructive: true,
      icon: Icons.edit_off_outlined,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final issue = _issue;
    final fix = _fix;
    return PopScope<Object?>(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: const Text('Ubicación del establecimiento'),
          leading: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: Form(
                key: _formKey,
                autovalidateMode: _attempted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.sm,
                    AppSpace.gutter,
                    AppSpace.xxl,
                  ),
                  children: <Widget>[
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            LocationPinCard(fix: fix, locating: _locating),
                            const SizedBox(height: 12),
                            AppButton(
                              key: const ValueKey<String>('useMyLocationButton'),
                              label: fix == null
                                  ? 'Usar mi ubicación actual'
                                  : 'Actualizar con mi ubicación',
                              icon: Icons.my_location_rounded,
                              variant: fix == null
                                  ? AppButtonVariant.dark
                                  : AppButtonVariant.secondary,
                              loading: _locating,
                              loadingLabel: 'Buscando señal GPS…',
                              onPressed: _loading ? null : _locate,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Hazlo desde tu local para que el repartidor '
                              'llegue al punto exacto.',
                              textAlign: TextAlign.center,
                              style: AppText.caption,
                            ),
                            if (issue != null) ...<Widget>[
                              const SizedBox(height: 12),
                              InlineAlert(
                                key: const ValueKey<String>('locationIssue'),
                                title: issue.title,
                                message: issue.message,
                                tone: AlertTone.warning,
                                icon: Icons.location_off_outlined,
                                actionLabel: issue.canOpenSettings
                                    ? 'Abrir ajustes'
                                    : 'Reintentar',
                                onAction: issue.canOpenSettings
                                    ? () => _openSettings(issue)
                                    : _locate,
                              ),
                            ],
                            if (fix != null &&
                                fix.accuracyMeters > kImpreciseGpsMeters) ...<Widget>[
                              const SizedBox(height: 12),
                              InlineAlert(
                                key: const ValueKey<String>('locationImprecise'),
                                title: 'Señal imprecisa '
                                    '(±${fix.accuracyMeters.round()} m)',
                                message: 'Intenta junto a la entrada o una '
                                    'ventana de tu local para marcar el punto '
                                    'exacto.',
                                tone: AlertTone.warning,
                                icon: Icons.gps_not_fixed_rounded,
                                actionLabel: 'Repetir',
                                onAction: _locate,
                              ),
                            ],
                            const SizedBox(height: 26),
                            const _Section('Dirección del local'),
                            AppField(
                              fieldKey:
                                  const ValueKey<String>('locationStreetField'),
                              controller: _street,
                              label: 'Calle y número',
                              hint: 'Av. Juárez 184, local 2',
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const <String>[
                                AutofillHints.streetAddressLine1,
                              ],
                              validator: (v) => (v ?? '').trim().length < 4
                                  ? 'Escribe la calle y el número.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            AppField(
                              fieldKey: const ValueKey<String>(
                                'locationNeighborhoodField',
                              ),
                              controller: _neighborhood,
                              label: 'Colonia',
                              hint: 'Centro',
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Escribe la colonia.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  flex: 3,
                                  child: AppField(
                                    fieldKey: const ValueKey<String>(
                                      'locationCityField',
                                    ),
                                    controller: _city,
                                    label: 'Ciudad o municipio',
                                    hint: 'Tala',
                                    textCapitalization:
                                        TextCapitalization.words,
                                    autofillHints: const <String>[
                                      AutofillHints.addressCity,
                                    ],
                                    validator: (v) => (v ?? '').trim().isEmpty
                                        ? 'Escribe la ciudad.'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: AppField(
                                    fieldKey: const ValueKey<String>(
                                      'locationPostalField',
                                    ),
                                    controller: _postal,
                                    label: 'C. P.',
                                    hint: '45300',
                                    keyboardType: TextInputType.number,
                                    autofillHints: const <String>[
                                      AutofillHints.postalCode,
                                    ],
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(5),
                                    ],
                                    validator: (v) =>
                                        (v ?? '').trim().length == 5
                                            ? null
                                            : '5 dígitos.',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            AppField(
                              fieldKey: const ValueKey<String>(
                                'locationReferencesField',
                              ),
                              controller: _references,
                              label: 'Referencias para el repartidor',
                              hint: 'Entre calles, color de fachada, '
                                  'dónde estacionarse…',
                              optional: true,
                              maxLines: 2,
                              minLines: 2,
                              maxLength: 140,
                              textCapitalization:
                                  TextCapitalization.sentences,
                            ),
                            if (!widget.store.sendsToServer) ...<Widget>[
                              const SizedBox(height: 18),
                              const InlineAlert(
                                key: ValueKey<String>('locationLocalNotice'),
                                title: 'Por ahora se guarda en este teléfono',
                                message: 'Cuando se active el envío a Tala '
                                    'Eats la verás marcada como «Guardada en '
                                    'Tala Eats».',
                                tone: AlertTone.info,
                                icon: Icons.phone_android_rounded,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.md,
                    AppSpace.gutter,
                    AppSpace.md,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (failure != null) ...<Widget>[
                            InlineAlert.failure(failure, onRetry: _save),
                            const SizedBox(height: 12),
                          ],
                          AppButton(
                            key: const ValueKey<String>('saveLocationButton'),
                            label: 'Guardar ubicación',
                            loadingLabel: 'Guardando…',
                            successLabel: 'Guardada',
                            loading: _saving,
                            success: _saved,
                            variant: _saved
                                ? AppButtonVariant.success
                                : AppButtonVariant.primary,
                            size: AppButtonSize.large,
                            onPressed: _loading ? null : _save,
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

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: AppText.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta del punto GPS. El fondo es una retícula abstracta (no un mapa):
/// solo el punto y sus coordenadas son datos reales.
class LocationPinCard extends StatelessWidget {
  const LocationPinCard({super.key, required this.fix, this.locating = false});

  final GpsFix? fix;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    final point = fix;
    final label = point == null
        ? (locating ? 'Buscando tu ubicación…' : 'Sin punto GPS')
        : '${point.latitude.toStringAsFixed(5)}, '
            '${point.longitude.toStringAsFixed(5)}';
    return Semantics(
      label: point == null
          ? 'Punto GPS: aún no marcado'
          : 'Punto GPS marcado: $label, precisión '
              '${point.accuracyMeters.round()} metros',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SizedBox(
          height: 172,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const CustomPaint(painter: _GridPainter()),
              Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<String>(label),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Motion.of(
                    context,
                    const Duration(milliseconds: 520),
                  ),
                  curve: Curves.easeOutBack,
                  builder: (context, t, child) => Transform.translate(
                    offset: Offset(0, -18 * (1 - t)),
                    child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                  ),
                  child: _Pin(active: point != null),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                right: 12,
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: _Chip(
                        icon: point == null
                            ? Icons.location_searching_rounded
                            : Icons.gps_fixed_rounded,
                        text: label,
                      ),
                    ),
                    if (point != null && point.accuracyMeters > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      _Chip(
                        icon: Icons.adjust_rounded,
                        text: '±${point.accuracyMeters.round()} m',
                      ),
                    ],
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

class _Pin extends StatelessWidget {
  const _Pin({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.brand : AppColors.inkFaint;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 3),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.storefront_rounded,
            size: 22,
            color: active ? AppColors.ink : AppColors.surface,
          ),
        ),
        Container(
          width: 3,
          height: 12,
          color: color,
        ),
        Container(
          width: 14,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.all(AppRadius.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(
                fontSize: 12.5,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Retícula de puntos con anillos concéntricos alrededor del centro.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.sunken);
    final dot = Paint()..color = AppColors.lineStrong;
    const step = 18.0;
    for (var x = step / 2; x < size.width; x += step) {
      for (var y = step / 2; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }
    final center = Offset(size.width / 2, size.height / 2 - 6);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.brand.withValues(alpha: 0.22);
    for (final r in <double>[34, 62, 92]) {
      canvas.drawCircle(center, r, ring);
    }
    canvas.drawCircle(
      center,
      34,
      Paint()..color = AppColors.brand.withValues(alpha: 0.07),
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
