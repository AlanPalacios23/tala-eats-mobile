import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/failures.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../models/entities.dart';
import '../../models/restaurant_location.dart';
import '../../state/operations_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/fields.dart';
import '../../widgets/images.dart';
import '../../widgets/surfaces.dart';
import 'location_screen.dart';

/// Perfil del restaurante: portada, datos visibles y entrega.
class RestaurantEditorScreen extends StatefulWidget {
  const RestaurantEditorScreen({super.key, required this.ops});

  final OperationsController ops;

  @override
  State<RestaurantEditorScreen> createState() => _RestaurantEditorScreenState();
}

class _RestaurantEditorScreenState extends State<RestaurantEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cuisine;
  late final TextEditingController _description;
  late final TextEditingController _eta;
  late bool _pickup;
  late String _image;

  RestaurantLocation? _location;
  bool _locationLoaded = false;
  bool _attempted = false;
  bool _saving = false;
  bool _saved = false;
  bool _dirty = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final r = widget.ops.restaurant!;
    _name = TextEditingController(text: r.name);
    _cuisine = TextEditingController(text: r.cuisine);
    _description = TextEditingController(text: r.description);
    _eta = TextEditingController(text: '${r.etaMin}');
    _pickup = r.pickupEnabled;
    _image = r.imagePath;
    for (final c in <TextEditingController>[
      _name,
      _cuisine,
      _description,
      _eta,
    ]) {
      c.addListener(_markDirty);
    }
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final restaurant = widget.ops.restaurant;
    if (restaurant == null) return;
    final location =
        await widget.ops.services.locationStore.load(restaurant.id);
    if (!mounted) return;
    setState(() {
      _location = location;
      _locationLoaded = true;
    });
  }

  Future<void> _openLocation() async {
    final message = await openRestaurantLocation(context, widget.ops);
    if (!mounted) return;
    await _loadLocation();
    if (message != null && mounted) {
      showAppSnack(context, message, tone: AlertTone.success);
    }
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _cuisine.dispose();
    _description.dispose();
    _eta.dispose();
    super.dispose();
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
    setState(() => _saving = true);
    final failure = await widget.ops.updateProfile(
      RestaurantProfileInput(
        name: _name.text.trim(),
        cuisine: _cuisine.text.trim(),
        description: _description.text.trim(),
        etaMin: int.tryParse(_eta.text) ?? 30,
        // El envío lo calcula el backend según la distancia; la app ya no lo
        // edita y reenvía sin cambios el valor que entregó el servidor.
        deliveryFee: widget.ops.restaurant?.deliveryFee ?? 0,
        pickupEnabled: _pickup,
        imagePath: _image,
      ),
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _failure = failure;
      });
      return;
    }
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
    if (mounted) Navigator.of(context).pop<String>('Perfil actualizado.');
  }

  Future<void> _handlePop() async {
    if (_saving) return;
    final leave = await confirmAction(
      context,
      title: '¿Descartar cambios?',
      message: 'Los cambios a tu perfil no se guardarán.',
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
    return PopScope<Object?>(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: const Text('Perfil del restaurante'),
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
                            PhotoField(
                              media: widget.ops.services.media,
                              purpose: MediaPurpose.restaurantCover,
                              value: _image,
                              aspectRatio: 16 / 9,
                              title: 'Foto de portada',
                              helper: 'Tu fachada, tu cocina o tu platillo estrella.',
                              placeholderIcon: Icons.storefront_outlined,
                              onChanged: (path) => setState(() {
                                _image = path;
                                _dirty = true;
                              }),
                            ),
                            const SizedBox(height: 26),
                            const _FormSection('Lo que ven tus clientes'),
                            AppField(
                              controller: _name,
                              label: 'Nombre del restaurante',
                              maxLength: 60,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => (v ?? '').trim().length < 2
                                  ? 'Escribe el nombre de tu restaurante.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            AppField(
                              controller: _cuisine,
                              label: 'Tipo de comida',
                              textCapitalization: TextCapitalization.sentences,
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Indica qué tipo de comida vendes.'
                                  : null,
                            ),
                            const SizedBox(height: 18),
                            AppField(
                              controller: _description,
                              label: 'Descripción',
                              optional: true,
                              maxLines: 3,
                              minLines: 3,
                              maxLength: 160,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 26),
                            const _FormSection('Ubicación del establecimiento'),
                            _LocationSummary(
                              location: _location,
                              loaded: _locationLoaded,
                              onEdit: _openLocation,
                            ),
                            const SizedBox(height: 26),
                            const _FormSection('Preparación y entrega'),
                            AppField(
                              controller: _eta,
                              label: 'Tiempo de preparación',
                              hint: '30',
                              helper: 'Lo que tardas en tener listo un pedido '
                                  'promedio. Los clientes lo ven al pedir.',
                              suffix: const Padding(
                                padding: EdgeInsets.only(right: 14),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text('min', style: AppText.bodySoft),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              validator: (v) {
                                final value = int.tryParse(v ?? '');
                                if (value == null || value < 5 || value > 180) {
                                  return 'Entre 5 y 180 min.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            const _DeliveryFeeNote(),
                            const SizedBox(height: 18),
                            Material(
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                side: const BorderSide(color: AppColors.line),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: SwitchListTile(
                                value: _pickup,
                                onChanged: (v) => setState(() {
                                  _pickup = v;
                                  _dirty = true;
                                }),
                                title: Text(
                                  'Recoger en el local',
                                  style: AppText.subtitle.copyWith(fontSize: 15),
                                ),
                                subtitle: const Text(
                                  'Permite que el cliente pase por su pedido.',
                                  style: AppText.caption,
                                ),
                              ),
                            ),
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
                          AnimatedSize(
                            duration: Motion.of(context, Motion.base),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.bottomCenter,
                            child: failure == null
                                ? const SizedBox(width: double.infinity)
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: InlineAlert.failure(
                                      failure,
                                      onRetry: _save,
                                    ),
                                  ),
                          ),
                          AppButton(
                            key: const ValueKey<String>('saveRestaurantButton'),
                            label: 'Guardar cambios',
                            loadingLabel: 'Guardando…',
                            successLabel: 'Guardado',
                            loading: _saving,
                            success: _saved,
                            variant: _saved
                                ? AppButtonVariant.success
                                : AppButtonVariant.primary,
                            size: AppButtonSize.large,
                            onPressed: _save,
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

/// Título de grupo dentro del formulario (jerarquía sin tarjetas extra).
class _FormSection extends StatelessWidget {
  const _FormSection(this.title);

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

/// El costo de envío ya no se edita aquí: lo calcula Tala Eats con la
/// distancia de cada cliente. Sin cifras fijas en la app.
class _DeliveryFeeNote extends StatelessWidget {
  const _DeliveryFeeNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('deliveryFeeNote'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.delivery_dining_outlined,
              size: 20,
              color: AppColors.inkSoft,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'El costo de envío lo calcula Tala Eats según la distancia de '
              'cada cliente. No necesitas configurarlo.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de la ubicación dentro del perfil, con acceso a editarla.
class _LocationSummary extends StatelessWidget {
  const _LocationSummary({
    required this.location,
    required this.loaded,
    required this.onEdit,
  });

  final RestaurantLocation? location;
  final bool loaded;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final value = location;
    final missing = loaded && (value == null || !value.isComplete);
    final title = !loaded
        ? 'Cargando ubicación…'
        : value == null || value.singleLine.isEmpty
            ? 'Agrega la dirección de tu local'
            : value.singleLine;
    return Material(
      key: const ValueKey<String>('locationSummary'),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: missing ? AppColors.brand.withValues(alpha: 0.5) : AppColors.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loaded ? onEdit : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: missing ? AppColors.brandTint : AppColors.sunken,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: missing ? AppColors.brandText : AppColors.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppText.subtitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    if (missing)
                      const Text(
                        'Es importante: con ella se calculan distancias y '
                        'envíos de tus pedidos.',
                        style: AppText.caption,
                      )
                    else if (value != null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          Tag(
                            label: value.hasCoordinates
                                ? 'Punto GPS marcado'
                                : 'Sin punto GPS',
                            icon: value.hasCoordinates
                                ? Icons.gps_fixed_rounded
                                : Icons.gps_off_rounded,
                            foreground: value.hasCoordinates
                                ? AppColors.green
                                : AppColors.amber,
                            background: value.hasCoordinates
                                ? AppColors.greenTint
                                : AppColors.amberTint,
                          ),
                          Tag(
                            label: value.syncedToServer
                                ? 'Guardada en Tala Eats'
                                : 'Pendiente de enviar',
                            icon: value.syncedToServer
                                ? Icons.cloud_done_outlined
                                : Icons.phone_android_rounded,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Text(
                  missing ? 'Agregar' : 'Editar',
                  key: const ValueKey<String>('editLocationButton'),
                  style: AppText.label.copyWith(
                    fontSize: 14,
                    color: AppColors.brandText,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
