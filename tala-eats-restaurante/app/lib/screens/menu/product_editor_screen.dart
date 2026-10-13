import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/failures.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/repositories.dart';
import '../../models/entities.dart';
import '../../state/operations_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/fields.dart';
import '../../widgets/images.dart';

/// Alta y edición de producto con foto obligatoria, validación inline,
/// estados guardando / guardado y aviso de cambios sin guardar.
class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({super.key, required this.ops, this.product});

  final OperationsController ops;
  final MenuProduct? product;

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _category;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _allergens;
  late bool _available;
  late bool _combo;
  late String _image;

  bool _attempted = false;
  bool _photoMissing = false;
  bool _saving = false;
  bool _saved = false;
  bool _dirty = false;
  AppFailure? _failure;

  bool get _isNew => widget.product == null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _price = TextEditingController(
      text: p == null ? '' : p.price.toStringAsFixed(2),
    );
    _stock = TextEditingController(text: '${p?.stock ?? 20}');
    _allergens = TextEditingController(text: p?.allergens ?? '');
    _available = p?.isAvailable ?? true;
    _combo = p?.isCombo ?? false;
    _image = p?.imagePath ?? '';
    for (final c in <TextEditingController>[
      _name,
      _description,
      _category,
      _price,
      _stock,
      _allergens,
    ]) {
      c.addListener(_markDirty);
    }
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _category.dispose();
    _price.dispose();
    _stock.dispose();
    _allergens.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _saved) return;
    setState(() {
      _attempted = true;
      _photoMissing = _image.isEmpty;
      _failure = null;
    });
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _photoMissing) {
      HapticFeedback.lightImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final failure = await widget.ops.saveProduct(
      ProductDraft(
        id: widget.product?.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        category: _category.text.trim(),
        price: parseMoney(_price.text) ?? 0,
        stock: int.tryParse(_stock.text) ?? 0,
        isAvailable: _available,
        allergens: _allergens.text.trim(),
        isCombo: _combo,
        imagePath: _image,
      ),
    );
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
      _isNew ? 'Producto publicado en tu menú.' : 'Cambios guardados.',
    );
  }

  Future<void> _delete() async {
    final product = widget.product;
    if (product == null) return;
    final ok = await confirmAction(
      context,
      title: '¿Eliminar "${product.name}"?',
      message: 'Dejará de aparecer en tu menú. Si solo se terminó, mejor '
          'páusalo desde la lista.',
      confirmLabel: 'Eliminar producto',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final failure = await widget.ops.deleteProduct(product);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _failure = failure;
      });
      return;
    }
    Navigator.of(context).pop<String>('Producto eliminado.');
  }

  Future<void> _handlePop() async {
    if (_saving) return;
    final leave = await confirmAction(
      context,
      title: '¿Descartar cambios?',
      message: 'Lo que modificaste en este producto no se guardará.',
      confirmLabel: 'Descartar',
      cancelLabel: 'Seguir editando',
      destructive: true,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final categories = <String>{
      for (final p in widget.ops.menu) p.category,
      'Bebidas',
      'Postres',
      'Combos',
    }.where((c) => c.trim().isNotEmpty).take(8).toList();

    return PopScope<Object?>(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handlePop();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: Text(_isNew ? 'Nuevo producto' : 'Editar producto'),
          leading: IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: <Widget>[
            if (!_isNew)
              IconButton(
                tooltip: 'Eliminar producto',
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.red,
              ),
            const SizedBox(width: 4),
          ],
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
                              key: const ValueKey<String>('productPhotoField'),
                              media: widget.ops.services.media,
                              purpose: MediaPurpose.product,
                              value: _image,
                              isRequired: true,
                              title: 'Foto del producto',
                              helper: 'Se muestra en tu menú y en el pedido.',
                              errorText: _photoMissing
                                  ? 'Agrega una foto para guardar el producto.'
                                  : null,
                              onChanged: (path) => setState(() {
                                _image = path;
                                _dirty = true;
                                if (path.isNotEmpty) _photoMissing = false;
                              }),
                            ),
                            const SizedBox(height: 22),
                            AppField(
                              fieldKey: const ValueKey<String>('editorNameField'),
                              controller: _name,
                              label: 'Nombre',
                              hint: 'Ej. Orden de tacos al pastor',
                              maxLength: 70,
                              textCapitalization: TextCapitalization.sentences,
                              validator: (v) => (v ?? '').trim().length < 2
                                  ? 'Escribe el nombre del producto.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            AppField(
                              controller: _description,
                              label: 'Descripción',
                              optional: true,
                              hint: 'Ingredientes, porción o cómo se sirve.',
                              maxLines: 3,
                              minLines: 2,
                              maxLength: 200,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final price = AppField(
                                  fieldKey:
                                      const ValueKey<String>('editorPriceField'),
                                  controller: _price,
                                  label: 'Precio',
                                  hint: '0.00',
                                  prefixText: '\$ ',
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: <TextInputFormatter>[
                                    MoneyInputFormatter(),
                                  ],
                                  validator: (v) {
                                    final value = parseMoney(v ?? '');
                                    if (value == null || value <= 0) {
                                      return 'Escribe un precio mayor a \$0.';
                                    }
                                    return null;
                                  },
                                );
                                final stock =
                                    ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _stock,
                                  builder: (context, value, _) => StockStepper(
                                    fieldKey: const ValueKey<String>(
                                      'editorStockField',
                                    ),
                                    controller: _stock,
                                    helper: _stockHelper(value.text),
                                    validator: (v) =>
                                        int.tryParse(v ?? '') == null
                                            ? 'Escribe una cantidad.'
                                            : null,
                                  ),
                                );
                                if (constraints.maxWidth < 420) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      price,
                                      const SizedBox(height: 18),
                                      stock,
                                    ],
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
                              controller: _category,
                              label: 'Categoría',
                              hint: 'Ej. Tacos',
                              textCapitalization: TextCapitalization.sentences,
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Elige o escribe una categoría.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _category,
                              builder: (context, value, _) => SuggestionChips(
                                options: categories,
                                selected: value.text,
                                onSelected: (option) {
                                  _category.text = option;
                                  _category.selection = TextSelection.collapsed(
                                    offset: option.length,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 18),
                            AppField(
                              controller: _allergens,
                              label: 'Alérgenos',
                              optional: true,
                              hint: 'Ej. Lácteos, gluten',
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 18),
                            _ToggleTile(
                              title: 'Disponible para clientes',
                              subtitle: _available
                                  ? 'Aparece en tu menú y se puede pedir.'
                                  : 'Oculto hasta que lo vuelvas a activar.',
                              value: _available,
                              onChanged: (v) => setState(() {
                                _available = v;
                                _dirty = true;
                              }),
                            ),
                            const SizedBox(height: 10),
                            _ToggleTile(
                              title: 'Es un combo',
                              subtitle: 'Agrupa varios productos en un precio.',
                              value: _combo,
                              onChanged: (v) => setState(() {
                                _combo = v;
                                _dirty = true;
                              }),
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
                            key: const ValueKey<String>('saveProductButton'),
                            label: _isNew ? 'Publicar producto' : 'Guardar cambios',
                            loadingLabel: 'Guardando…',
                            successLabel: _isNew ? 'Publicado' : 'Guardado',
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

  String? _stockHelper(String text) {
    final stock = int.tryParse(text);
    if (stock == null) return null;
    if (stock == 0) return 'Con 0 el producto se muestra agotado.';
    if (stock <= kLowStockThreshold) return 'Stock bajo: te avisaremos en Inicio.';
    return null;
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppText.subtitle.copyWith(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppText.caption),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
