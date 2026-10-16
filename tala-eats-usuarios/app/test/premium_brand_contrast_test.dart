import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

double contrast(Color a, Color b) {
  final double l1 = a.computeLuminance();
  final double l2 = b.computeLuminance();
  final double light = l1 > l2 ? l1 : l2;
  final double dark = l1 > l2 ? l2 : l1;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  test('La marca naranja original se conserva', () {
    expect(kBrand, const Color(0xFFFF5A1F));
  });

  test('Naranja de acción y texto cumple WCAG AA contra blanco', () {
    expect(contrast(kBrandDeep, Colors.white), greaterThanOrEqualTo(4.5));
    expect(contrast(kBrandDeep, kBackground), greaterThanOrEqualTo(4.5));
  });

  test('Botones principales usan naranja con contraste AA', () {
    final ThemeData theme = buildTalaTheme();
    final Color? color = theme.filledButtonTheme.style?.backgroundColor
        ?.resolve(<WidgetState>{});
    final Color? foreground = theme.filledButtonTheme.style?.foregroundColor
        ?.resolve(<WidgetState>{});
    expect(color, kBrandDeep);
    expect(foreground, Colors.white);
    expect(contrast(color!, foreground!), greaterThanOrEqualTo(4.5));
  });

  test('Overline pequeño no usa el naranja claro del logotipo', () {
    expect(TalaText.overline.color, kBrandDeep);
    expect(contrast(TalaText.overline.color!, Colors.white),
        greaterThanOrEqualTo(4.5));
  });
}
