import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../widgets/motion.dart';

// ---------------------------------------------------------------------------
// Color tokens
// ---------------------------------------------------------------------------
// Identidad base heredada de v0.2.0 (sin cambios de marca).
const Color kBrand = Color(0xFFFF5A1F);
const Color kBrandDeep = Color(0xFFE9470F);
const Color kInk = Color(0xFF181614);
const Color kMuted = Color(0xFF6F6A65);
const Color kBackground = Color(0xFFF8F7F5);
const Color kSurface = Color(0xFFFFFFFF);
const Color kSoftOrange = Color(0xFFFFF0E9);
const Color kGreen = Color(0xFF157A43);
const Color kLine = Color(0xFFE9E5E1);
const Color kRed = Color(0xFFB73831);

// Tonos auxiliares v1.0.0 (documentados en CLAUDE-CHANGES-v1.0.0.md).
/// Naranja para TEXTO sobre blanco. kBrand (3.1:1) y kBrandDeep (3.9:1) no
/// alcanzan AA en texto pequeño; este tono da 5.6:1 manteniendo la familia.
const Color kBrandInk = Color(0xFFB93D0C);
const Color kSoftGreen = Color(0xFFEAF6EE);
const Color kSoftRed = Color(0xFFFBECEA);
const Color kAmber = Color(0xFF8A5A00);
const Color kSoftAmber = Color(0xFFFFF5E3);
const Color kSurfaceSunken = Color(0xFFF3F1EE);
const Color kLineStrong = Color(0xFFD9D4CF);
const Color kDisabledBg = Color(0xFFE7E4E0);
const Color kDisabledFg = Color(0xFF8F8983);
const Color kOfflineDot = Color(0xFFA9A39D);

// ---------------------------------------------------------------------------
// Spacing / radius tokens
// ---------------------------------------------------------------------------
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Margen horizontal de pantalla.
  static const double gutter = 18;
}

abstract final class Radii {
  static const double s = 10;
  static const double m = 14;
  static const double l = 20;
  static const double pill = 999;

  static const BorderRadius sm = BorderRadius.all(Radius.circular(s));
  static const BorderRadius md = BorderRadius.all(Radius.circular(m));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(l));
}

/// Altura mínima de controles táctiles críticos (CTA principal).
const double kPrimaryCtaHeight = 56;

// ---------------------------------------------------------------------------
// Typography tokens
// ---------------------------------------------------------------------------
abstract final class AppText {
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Montos principales (ganancia del día).
  static const TextStyle display = TextStyle(
    color: kInk,
    fontSize: 40,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    fontFeatures: _tabular,
  );

  /// Título de pantalla.
  static const TextStyle screenTitle = TextStyle(
    color: kInk,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -.6,
  );

  /// Título del estado actual de una entrega.
  static const TextStyle stageTitle = TextStyle(
    color: kInk,
    fontSize: 23,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -.4,
  );

  static const TextStyle section = TextStyle(
    color: kInk,
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -.15,
  );

  static const TextStyle title = TextStyle(
    color: kInk,
    fontSize: 15,
    height: 1.25,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle body = TextStyle(
    color: kInk,
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyMuted = TextStyle(
    color: kMuted,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    color: kMuted,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  /// Etiquetas cortas en mayúsculas (sobretítulos).
  static const TextStyle overline = TextStyle(
    color: kMuted,
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: .6,
  );

  static const TextStyle metric = TextStyle(
    color: kInk,
    fontSize: 18,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -.3,
    fontFeatures: _tabular,
  );

  static const TextStyle money = TextStyle(
    color: kInk,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w800,
    letterSpacing: .1,
  );
}

// ---------------------------------------------------------------------------
// ThemeData
// ---------------------------------------------------------------------------
ThemeData driverTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: Brightness.light,
    surface: kSurface,
  ).copyWith(
    primary: kInk,
    onPrimary: Colors.white,
    secondary: kBrandDeep,
    error: kRed,
    outline: kLine,
    outlineVariant: kLine,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBackground,
    fontFamily: 'Roboto',
    visualDensity: VisualDensity.standard,
    // Ripple sobrio en lugar de InkSparkle (más ruidoso visualmente).
    splashFactory: InkRipple.splashFactory,
  );

  final buttonShape = RoundedRectangleBorder(borderRadius: Radii.md);

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineLarge: AppText.screenTitle,
      headlineSmall: AppText.stageTitle,
      titleLarge: AppText.section,
      titleMedium: AppText.title,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.bodyMuted,
      labelLarge: AppText.button,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBackground,
      surfaceTintColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.section,
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lg,
        side: const BorderSide(color: kLine),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kInk,
        foregroundColor: Colors.white,
        disabledBackgroundColor: kDisabledBg,
        disabledForegroundColor: kDisabledFg,
        minimumSize: const Size(0, kPrimaryCtaHeight),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
        shape: buttonShape,
        textStyle: AppText.button,
        animationDuration: Motion.short,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kInk,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        side: const BorderSide(color: kLineStrong),
        shape: buttonShape,
        textStyle: AppText.button.copyWith(fontSize: 14.5),
        animationDuration: Motion.short,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kInk,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: buttonShape,
        textStyle: AppText.button.copyWith(fontSize: 14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: kInk,
        minimumSize: const Size(48, 48),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: kMuted, fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(
        color: kInk,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(color: kDisabledFg),
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.error)
            ? kRed
            : states.contains(WidgetState.focused)
                ? kInk
                : kMuted,
      ),
      suffixIconColor: kMuted,
      errorStyle: const TextStyle(
        color: kRed,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      errorMaxLines: 2,
      border: OutlineInputBorder(
        borderRadius: Radii.md,
        borderSide: const BorderSide(color: kLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: Radii.md,
        borderSide: const BorderSide(color: kLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: Radii.md,
        borderSide: const BorderSide(color: kInk, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: Radii.md,
        borderSide: const BorderSide(color: kRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: Radii.md,
        borderSide: const BorderSide(color: kRed, width: 1.4),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? kSurface
            : states.contains(WidgetState.selected)
                ? kSurface
                : kMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? (states.contains(WidgetState.selected)
                ? kGreen.withValues(alpha: .45)
                : kDisabledBg)
            : states.contains(WidgetState.selected)
                ? kGreen
                : kSurfaceSunken,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : kLineStrong,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kSurface,
      indicatorColor: kSoftOrange,
      elevation: 0,
      height: 70,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? kInk : kMuted,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? kBrandInk : kMuted,
          size: 24,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: kLine, thickness: 1, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: kLineStrong,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: Radii.lg),
      titleTextStyle: AppText.section,
      contentTextStyle: AppText.bodyMuted,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kInk,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      shape: RoundedRectangleBorder(borderRadius: Radii.md),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kBrandDeep,
      linearTrackColor: kSurfaceSunken,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: DriverPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

/// Transición de páginas estándar: fade + desplazamiento vertical corto.
/// Con reducir movimiento activo, la página aparece sin desplazamiento.
class DriverPageTransitionsBuilder extends PageTransitionsBuilder {
  const DriverPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.reduced(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.emphasized,
      reverseCurve: Motion.exit,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
