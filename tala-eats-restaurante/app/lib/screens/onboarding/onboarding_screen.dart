import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/failures.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../models/entities.dart';
import '../../state/session_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/fields.dart';
import '../../widgets/images.dart';
import '../../widgets/motion.dart';
import '../../widgets/states.dart';
import '../../widgets/surfaces.dart';

/// Política mínima de contraseña en el alta. Debe alinearse con el backend
/// (ver BACKEND-NEEDS.md).
const int kMinPasswordLength = 8;

const List<String> _cuisineOptions = <String>[
  'Tacos',
  'Mariscos',
  'Pizza',
  'Hamburguesas',
  'Sushi',
  'Cafetería',
  'Postres',
  'Comida casera',
];

const List<String> _categoryOptions = <String>[
  'Platillos',
  'Especialidades',
  'Bebidas',
  'Postres',
  'Combos',
];

/// Alta guiada: propietario → restaurante → primer producto → confirmación.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<String> _titles = <String>[
    'Crea tu cuenta',
    'Configura tu restaurante',
    'Agrega tu primer producto',
  ];
  static const List<String> _subtitles = <String>[
    'Con estos datos entrarás a tu panel y te contactaremos si hace falta.',
    'Así te verán los clientes dentro de Tala Eats.',
    'Tu menú empieza con un producto con foto, precio y stock.',
  ];

  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();

  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  final _restaurantName = TextEditingController();
  final _cuisine = TextEditingController();
  final _description = TextEditingController();
  String _restaurantImage = '';

  final _productName = TextEditingController();
  final _productCategory = TextEditingController(text: 'Platillos');
  final _productPrice = TextEditingController();
  final _productStock = TextEditingController(text: '20');
  final _productDescription = TextEditingController();
  String _productImage = '';
  bool _productPhotoMissing = false;

  int _step = 0;
  int _direction = 1;
  final List<bool> _attempted = <bool>[false, false, false];
  bool _saving = false;
  bool _done = false;
  AppFailure? _failure;

  MediaRepository get _media => widget.session.services.media;

  List<TextEditingController> get _controllers => <TextEditingController>[
        _ownerName,
        _email,
        _phone,
        _password,
        _restaurantName,
        _cuisine,
        _description,
        _productName,
        _productCategory,
        _productPrice,
        _productStock,
        _productDescription,
      ];

  bool get _hasData =>
      _ownerName.text.isNotEmpty ||
      _email.text.isNotEmpty ||
      _restaurantName.text.isNotEmpty ||
      _productImage.isNotEmpty;

  bool _hadData = false;

  @override
  void initState() {
    super.initState();
    for (final c in <TextEditingController>[
      _ownerName,
      _email,
      _restaurantName,
    ]) {
      c.addListener(_onDraftChanged);
    }
  }

  /// Recalcula `canPop` del PopScope cuando el borrador pasa de vacío a
  /// con datos (o viceversa).
  void _onDraftChanged() {
    final has = _hasData;
    if (has != _hadData && mounted) setState(() => _hadData = has);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _direction = step > _step ? 1 : -1;
      _step = step;
      _failure = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  bool _validateStep() {
    setState(() => _attempted[_step] = true);
    final formOk = _formKey.currentState?.validate() ?? false;
    if (_step == 2) {
      final missing = _productImage.isEmpty;
      setState(() => _productPhotoMissing = missing);
      if (missing) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: Motion.of(context, Motion.slow),
            curve: Curves.easeOutCubic,
          );
        }
        return false;
      }
    }
    return formOk;
  }

  void _next() {
    if (!_validateStep()) {
      HapticFeedback.lightImpact();
      return;
    }
    _goTo(_step + 1);
  }

  Future<void> _finish() async {
    if (_saving) return;
    if (!_validateStep()) {
      HapticFeedback.lightImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _failure = null;
    });
    final draft = OnboardingDraft(
      ownerName: _ownerName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      password: _password.text,
      restaurantName: _restaurantName.text.trim(),
      cuisine: _cuisine.text.trim(),
      description: _description.text.trim(),
      restaurantImage: _restaurantImage,
      product: ProductDraft(
        name: _productName.text.trim(),
        description: _productDescription.text.trim(),
        category: _productCategory.text.trim(),
        price: parseMoney(_productPrice.text) ?? 0,
        stock: int.tryParse(_productStock.text) ?? 0,
        isAvailable: true,
        allergens: '',
        isCombo: false,
        imagePath: _productImage,
      ),
    );
    final failure = await widget.session.createRestaurant(draft);
    if (!mounted) return;
    if (failure != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _saving = false;
        _failure = failure;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _saving = false;
      _done = true;
    });
  }

  void _enterPanel() {
    widget.session.enterPanel();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleBack() async {
    if (_saving) return;
    if (_done) {
      _enterPanel();
      return;
    }
    if (_step > 0) {
      _goTo(_step - 1);
      return;
    }
    if (!_hasData) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await confirmAction(
      context,
      title: '¿Salir del alta?',
      message: 'Los datos que capturaste no se guardarán.',
      confirmLabel: 'Salir',
      cancelLabel: 'Seguir con el alta',
      destructive: true,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _step == 0 && !_saving && !_done && !_hasData,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: StateSwitcher(
            expand: true,
            child: _done
                ? _SuccessView(
                    key: const ValueKey<String>('done'),
                    restaurantName: _restaurantName.text.trim(),
                    cuisine: _cuisine.text.trim(),
                    restaurantImage: _restaurantImage,
                    productName: _productName.text.trim(),
                    productPrice: parseMoney(_productPrice.text) ?? 0,
                    productImage: _productImage,
                    onEnter: _enterPanel,
                  )
                : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final failure = _failure;
    return Stack(
      key: const ValueKey<String>('form'),
      children: <Widget>[
        Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _StepHeader(
              step: _step,
              total: 3,
              onBack: _saving ? null : _handleBack,
            ),
            Expanded(
              child: Form(
                key: _formKey,
                autovalidateMode: _attempted[_step]
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: SingleChildScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.sm,
                    AppSpace.gutter,
                    AppSpace.xxl,
                  ),
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.slow),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previous,
                        if (current != null) current,
                      ],
                    ),
                    transitionBuilder: (child, animation) {
                      final incoming = child.key == ValueKey<int>(_step);
                      final dx = (incoming ? 0.06 : -0.06) * _direction;
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(dx, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_step),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: Text(_titles[_step], style: AppText.headline),
                          ),
                          const SizedBox(height: 8),
                          Text(_subtitles[_step], style: AppText.bodySoft),
                          const SizedBox(height: 26),
                          if (_step == 0) _accountStep(),
                          if (_step == 1) _restaurantStep(),
                          if (_step == 2) _productStep(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _BottomBar(
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
                              onRetry: _finish,
                            ),
                          ),
                  ),
                  if (_step < 2)
                    AppButton(
                      key: const ValueKey<String>('nextOnboardingButton'),
                      label: 'Continuar',
                      size: AppButtonSize.large,
                      onPressed: _next,
                    )
                  else
                    AppButton(
                      key: const ValueKey<String>('finishRestaurantButton'),
                      label: 'Crear restaurante',
                      loadingLabel: 'Creando tu restaurante…',
                      loading: _saving,
                      size: AppButtonSize.large,
                      onPressed: _finish,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
        if (_saving)
          const Positioned.fill(child: _CreatingOverlay()),
      ],
    );
  }


  Widget _accountStep() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppField(
              fieldKey: const ValueKey<String>('ownerNameField'),
              controller: _ownerName,
              label: 'Nombre del propietario',
              hint: 'Nombre y apellido',
              textCapitalization: TextCapitalization.words,
              autofillHints: const <String>[AutofillHints.name],
              validator: (v) => (v ?? '').trim().length < 3
                  ? 'Escribe tu nombre completo.'
                  : null,
            ),
          const SizedBox(height: 18),
          AppField(
              fieldKey: const ValueKey<String>('ownerEmailField'),
              controller: _email,
              label: 'Correo',
              hint: 'nombre@correo.com',
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const <String>[AutofillHints.email],
              validator: Validators.email,
            ),
          const SizedBox(height: 18),
          AppField(
              fieldKey: const ValueKey<String>('ownerPhoneField'),
              controller: _phone,
              label: 'Teléfono',
              hint: '10 dígitos',
              keyboardType: TextInputType.phone,
              autofillHints: const <String>[AutofillHints.telephoneNumber],
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: Validators.phoneMx,
            ),
          const SizedBox(height: 18),
          PasswordField(
              fieldKey: const ValueKey<String>('ownerPasswordField'),
              controller: _password,
              helper: 'Mínimo $kMinPasswordLength caracteres.',
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              onSubmitted: (_) => _next(),
              validator: (v) => (v ?? '').length < kMinPasswordLength
                  ? 'Usa al menos $kMinPasswordLength caracteres.'
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _restaurantStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PhotoField(
          key: const ValueKey<String>('restaurantPhotoPicker'),
          media: _media,
          purpose: MediaPurpose.restaurantCover,
          value: _restaurantImage,
          onChanged: (path) => setState(() => _restaurantImage = path),
          title: 'Foto de portada',
          helper: 'Tu fachada, tu cocina o tu platillo estrella.',
          aspectRatio: 16 / 9,
          placeholderIcon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 22),
        AppField(
            fieldKey: const ValueKey<String>('restaurantNameField'),
            controller: _restaurantName,
            label: 'Nombre del restaurante',
            hint: 'Como aparece en tu local',
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            validator: (v) => (v ?? '').trim().length < 2
                ? 'Escribe el nombre de tu restaurante.'
                : null,
          ),
        const SizedBox(height: 12),
        AppField(
            fieldKey: const ValueKey<String>('restaurantCuisineField'),
            controller: _cuisine,
            label: 'Tipo de comida',
            hint: 'Elige una opción o escríbela',
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Indica qué tipo de comida vendes.'
                : null,
          ),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _cuisine,
          builder: (context, value, _) => SuggestionChips(
            options: _cuisineOptions,
            selected: value.text,
            onSelected: (option) {
              _cuisine.text = option;
              _cuisine.selection =
                  TextSelection.collapsed(offset: option.length);
              if (_attempted[1]) _formKey.currentState?.validate();
            },
          ),
        ),
        const SizedBox(height: 22),
        AppField(
          controller: _description,
          label: 'Descripción',
          optional: true,
          hint: 'Qué te hace especial: receta, horario, especialidad…',
          maxLines: 3,
          minLines: 3,
          maxLength: 160,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _productStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PhotoField(
          key: const ValueKey<String>('firstProductPhotoPicker'),
          media: _media,
          purpose: MediaPurpose.product,
          value: _productImage,
          onChanged: (path) => setState(() {
            _productImage = path;
            if (path.isNotEmpty) _productPhotoMissing = false;
          }),
          title: 'Foto del producto',
          helper: 'Luz natural y el platillo al centro funcionan mejor.',
          isRequired: true,
          errorText: _productPhotoMissing
              ? 'Agrega una foto para publicar tu primer producto.'
              : null,
        ),
        const SizedBox(height: 22),
        AppField(
            fieldKey: const ValueKey<String>('productNameField'),
            controller: _productName,
            label: 'Nombre del producto',
            hint: 'Ej. Orden de tacos al pastor',
            textCapitalization: TextCapitalization.sentences,
            maxLength: 70,
            validator: (v) => (v ?? '').trim().length < 2
                ? 'Escribe el nombre del producto.'
                : null,
          ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final price = AppField(
                fieldKey: const ValueKey<String>('productPriceField'),
                controller: _productPrice,
                label: 'Precio',
                hint: '0.00',
                prefixText: '\$ ',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[MoneyInputFormatter()],
                validator: (v) {
                  final value = parseMoney(v ?? '');
                  if (value == null || value <= 0) {
                    return 'Escribe un precio mayor a \$0.';
                  }
                  return null;
                },
              );
            final stock = StockStepper(
                fieldKey: const ValueKey<String>('productStockField'),
                controller: _productStock,
                label: 'Stock inicial',
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Escribe una cantidad.' : null,
              );
            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[price, const SizedBox(height: 18), stock],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: price),
                const SizedBox(width: 12),
                Expanded(child: stock),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        AppField(
            controller: _productCategory,
            label: 'Categoría',
            textCapitalization: TextCapitalization.sentences,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Elige una categoría.' : null,
          ),
        const SizedBox(height: 12),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _productCategory,
          builder: (context, value, _) => SuggestionChips(
            options: _categoryOptions,
            selected: value.text,
            onSelected: (option) {
              _productCategory.text = option;
              _productCategory.selection =
                  TextSelection.collapsed(offset: option.length);
            },
          ),
        ),
        const SizedBox(height: 22),
        AppField(
          controller: _productDescription,
          label: 'Descripción',
          optional: true,
          hint: 'Ingredientes, porción o cómo se sirve.',
          maxLines: 3,
          minLines: 2,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 22),
        const Text('Así se verá en tu menú', style: AppText.label),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            _productName,
            _productPrice,
            _productCategory,
          ]),
          builder: (context, _) => _ProductPreview(
            name: _productName.text.trim(),
            category: _productCategory.text.trim(),
            price: parseMoney(_productPrice.text),
            image: _productImage,
          ),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.total,
    required this.onBack,
  });

  final int step;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, AppSpace.gutter, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                tooltip: step == 0 ? 'Salir del alta' : 'Paso anterior',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Paso ${step + 1} de $total',
                  style: AppText.label.copyWith(color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: List<Widget>.generate(total, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 5,
                        color: AppColors.line,
                        alignment: Alignment.centerLeft,
                        child: AnimatedFractionallySizedBox(
                          duration: Motion.of(context, Motion.slow),
                          curve: Curves.easeOutCubic,
                          widthFactor: i <= step ? 1.0 : 0.0,
                          heightFactor: 1,
                          child: Container(
                            color: i < step ? AppColors.ink : AppColors.brand,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.md,
          AppSpace.gutter,
          AppSpace.md,
        ),
        child: child,
      ),
    );
  }
}

class _ProductPreview extends StatelessWidget {
  const _ProductPreview({
    required this.name,
    required this.category,
    required this.price,
    required this.image,
  });

  final String name;
  final String category;
  final double? price;
  final String image;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          AppThumbnail(source: image, size: 64, icon: categoryIcon(category)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name.isEmpty ? 'Nombre del producto' : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.subtitle.copyWith(
                    color: name.isEmpty ? AppColors.inkFaint : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.isEmpty ? 'Categoría' : category,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            price == null || price! <= 0 ? '\$0.00' : money(price!),
            style: AppText.subtitle.copyWith(fontFeatures: AppFonts.tabular),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({
    super.key,
    required this.restaurantName,
    required this.cuisine,
    required this.restaurantImage,
    required this.productName,
    required this.productPrice,
    required this.productImage,
    required this.onEnter,
  });

  final String restaurantName;
  final String cuisine;
  final String restaurantImage;
  final String productName;
  final double productPrice;
  final String productImage;
  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  48,
                  AppSpace.gutter,
                  AppSpace.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SuccessMark(),
                    const SizedBox(height: 28),
                    Entrance(
                      delay: const Duration(milliseconds: 120),
                      child: Semantics(
                        header: true,
                        liveRegion: true,
                        child: const Text(
                          'Solicitud enviada',
                          style: AppText.display,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Entrance(
                      delay: Duration(milliseconds: 170),
                      child: Text(
                        'Recibimos tus datos. El equipo de Tala Eats revisará el alta '
                        'antes de habilitar la operación del restaurante.',
                        style: AppText.bodySoft,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Entrance(
                      delay: const Duration(milliseconds: 220),
                      child: SurfaceCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.lg - 1),
                              ),
                              child: AspectRatio(
                                aspectRatio: 16 / 7,
                                child: AppImage(
                                  source: restaurantImage,
                                  placeholderIcon: Icons.storefront_outlined,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                              child: Text(restaurantName, style: AppText.title),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: Text(cuisine, style: AppText.caption),
                            ),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: <Widget>[
                                  AppThumbnail(source: productImage, size: 52),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          productName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.subtitle,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Guardado como borrador',
                                          style: AppText.caption.copyWith(
                                            color: AppColors.green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    money(productPrice),
                                    style: AppText.subtitle.copyWith(
                                      fontFeatures: AppFonts.tabular,
                                    ),
                                  ),
                                ],
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
            _BottomBar(
              child: AppButton(
                key: const ValueKey<String>('openPanelButton'),
                label: 'Ver estado de mi solicitud',
                size: AppButtonSize.large,
                onPressed: onEnter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mientras se crea el restaurante (cuenta, fotos y primer producto): bloquea
/// la pantalla y explica qué se está enviando. No simula avances por pasos
/// porque el servidor no los informa por separado.
class _CreatingOverlay extends StatelessWidget {
  const _CreatingOverlay();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Creando tu restaurante. No cierres la app.',
      child: AbsorbPointer(
        child: ColoredBox(
          color: AppColors.canvas.withValues(alpha: 0.94),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.gutter),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420),
                child: Entrance(
                  child: SurfaceCard(
                    padding: EdgeInsets.fromLTRB(22, 26, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.brand,
                            backgroundColor: AppColors.brandTint,
                          ),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Creando tu restaurante',
                          textAlign: TextAlign.center,
                          style: AppText.title,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Estamos enviando tu información y subiendo tus fotos.',
                          textAlign: TextAlign.center,
                          style: AppText.bodySoft,
                        ),
                        SizedBox(height: 18),
                        _SendingItem(
                          icon: Icons.person_outline_rounded,
                          text: 'Tu cuenta de propietario',
                        ),
                        _SendingItem(
                          icon: Icons.storefront_outlined,
                          text: 'Datos y foto del restaurante',
                        ),
                        _SendingItem(
                          icon: Icons.restaurant_menu_rounded,
                          text: 'Primer producto con foto',
                        ),
                        SizedBox(height: 14),
                        Text(
                          'No cierres la app; tarda solo unos segundos.',
                          textAlign: TextAlign.center,
                          style: AppText.caption,
                        ),
                      ],
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

class _SendingItem extends StatelessWidget {
  const _SendingItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.sunken,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.label)),
          const Icon(
            Icons.cloud_upload_outlined,
            size: 18,
            color: AppColors.inkFaint,
          ),
        ],
      ),
    );
  }
}
