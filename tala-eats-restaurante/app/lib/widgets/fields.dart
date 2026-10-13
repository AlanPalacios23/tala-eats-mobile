import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Campo de texto con etiqueta visible arriba (no flotante), ayuda y error
/// inline. Escala con el tamaño de texto del sistema.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.optional = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.obscureText = false,
    this.suffix,
    this.prefixIcon,
    this.prefixText,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.enabled = true,
    this.fieldKey,
    this.autocorrect = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final bool optional;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final Widget? suffix;
  final IconData? prefixIcon;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final bool enabled;
  final Key? fieldKey;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Row(
            children: <Widget>[
              Flexible(child: Text(label, style: AppText.label)),
              if (optional) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  'Opcional',
                  style: AppText.caption.copyWith(fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction:
              maxLines > 1 ? TextInputAction.newline : textInputAction,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          onChanged: onChanged,
          obscureText: obscureText,
          autocorrect: autocorrect && !obscureText,
          enableSuggestions: !obscureText,
          inputFormatters: inputFormatters,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          style: AppText.body.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperMaxLines: 2,
            helperStyle: AppText.caption,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 21),
            prefixText: prefixText,
            prefixStyle: AppText.body.copyWith(
              fontSize: 16,
              color: AppColors.inkSoft,
            ),
            suffixIcon: suffix,
            counterStyle: AppText.caption.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Contraseña con mostrar/ocultar accesible.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Contraseña',
    this.helper,
    this.validator,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.autofillHints = const <String>[AutofillHints.password],
    this.fieldKey,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final Key? fieldKey;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return AppField(
      fieldKey: widget.fieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      label: widget.label,
      helper: widget.helper,
      obscureText: _hidden,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      prefixIcon: Icons.lock_outline_rounded,
      suffix: IconButton(
        tooltip: _hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
        onPressed: () => setState(() => _hidden = !_hidden),
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 21,
        ),
      ),
    );
  }
}

/// Sugerencias tocables que rellenan un campo (tipo de comida, categoría).
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected =
            option.toLowerCase() == selected.trim().toLowerCase();
        return Semantics(
          selected: isSelected,
          button: true,
          child: Material(
            color: isSelected ? AppColors.ink : AppColors.surface,
            shape: StadiumBorder(
              side: BorderSide(
                color: isSelected ? AppColors.ink : AppColors.line,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(option),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      option,
                      style: AppText.label.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Stock con botones −/+ grandes y campo numérico editable.
class StockStepper extends StatelessWidget {
  const StockStepper({
    super.key,
    required this.controller,
    this.label = 'Stock disponible',
    this.helper,
    this.validator,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final Key? fieldKey;

  void _bump(int delta) {
    final current = int.tryParse(controller.text) ?? 0;
    final next = (current + delta).clamp(0, 99999);
    controller.text = '$next';
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return AppField(
      fieldKey: fieldKey,
      controller: controller,
      label: label,
      helper: helper,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      validator: validator,
      prefixIcon: Icons.inventory_2_outlined,
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Restar 1',
            onPressed: () => _bump(-1),
            icon: const Icon(Icons.remove_rounded),
          ),
          IconButton(
            tooltip: 'Sumar 1',
            onPressed: () => _bump(1),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Formateador de montos: dígitos y un separador decimal, máx. 2 decimales.
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    if (text.isEmpty) return newValue.copyWith(text: '');
    final valid = RegExp(r'^\d{0,6}(\.\d{0,2})?$').hasMatch(text);
    if (!valid) return oldValue;
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Validadores reutilizables con mensajes de producto.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? notEmpty(String? value, String message) =>
      (value ?? '').trim().isEmpty ? message : null;

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Escribe tu correo.';
    if (!_email.hasMatch(text)) return 'Revisa el formato, por ejemplo nombre@correo.com';
    return null;
  }

  static String? phoneMx(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Escribe un teléfono de contacto.';
    if (digits.length != 10) return 'Usa 10 dígitos, sin lada internacional.';
    return null;
  }
}
