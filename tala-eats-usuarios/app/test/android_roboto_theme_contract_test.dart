import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

// Prevent screenshots from silently reverting to Ahem black rectangles.
// This also keeps buttons and app bars typographically consistent on Android.
void main() {
  test('Android text, app bar, CTAs and notices select explicit Roboto', () {
    final ThemeData theme = buildTalaTheme();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Roboto');
    expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Roboto');
    expect(theme.filledButtonTheme.style?.textStyle
        ?.resolve(<WidgetState>{})?.fontFamily, 'Roboto');
    expect(theme.outlinedButtonTheme.style?.textStyle
        ?.resolve(<WidgetState>{})?.fontFamily, 'Roboto');
    expect(theme.textButtonTheme.style?.textStyle
        ?.resolve(<WidgetState>{})?.fontFamily, 'Roboto');
    expect(theme.snackBarTheme.contentTextStyle?.fontFamily, 'Roboto');
  });

  test('Roboto does not replace TALA EATS brand or CTA contrast', () {
    expect(kBrand, const Color(0xFFFF5A1F));
    expect(themeColor(), kBrandDeep);
  });
}

Color? themeColor() => buildTalaTheme().filledButtonTheme.style
    ?.backgroundColor?.resolve(<WidgetState>{});
