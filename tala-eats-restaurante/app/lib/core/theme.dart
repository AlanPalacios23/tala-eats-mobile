import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Paleta Tala Eats Restaurante.
///
/// Base "acero de cocina" (neutro frío) para que el color quede reservado a
/// acción y estado. El naranja Tala se usa en CTA principales y en "Nuevo";
/// verde, ámbar y rojo solo comunican estado operativo real.
abstract final class AppColors {
  static const Color canvas = Color(0xFFF1F2EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color sunken = Color(0xFFE7E9E4);
  static const Color ink = Color(0xFF1C1D1B);
  static const Color inkSoft = Color(0xFF525750);
  // v0.6.0: un poco más oscuro para contraste AA (4.6:1 sobre el fondo y
  // 5.2:1 sobre blanco) en textos secundarios pequeños.
  static const Color inkFaint = Color(0xFF696E67);
  static const Color line = Color(0xFFE0E2DC);
  static const Color lineStrong = Color(0xFFC9CCC5);

  static const Color brand = Color(0xFFFF5A1F);
  static const Color brandPressed = Color(0xFFF04C12);
  static const Color brandText = Color(0xFFB53B0A);
  static const Color brandTint = Color(0xFFFFEDE4);

  static const Color green = Color(0xFF127A47);
  static const Color greenTint = Color(0xFFE2F1E8);
  static const Color amber = Color(0xFF8A5000);
  static const Color amberTint = Color(0xFFFBEED2);
  static const Color red = Color(0xFFB3261E);
  static const Color redTint = Color(0xFFFBE6E3);

  // Modo cocina (KDS): riel oscuro, comandas claras para lectura a distancia.
  static const Color kdsBackground = Color(0xFF131412);
  static const Color kdsRail = Color(0xFF1D1F1C);
  static const Color kdsRailLine = Color(0xFF2E312D);
  static const Color kdsPaper = Color(0xFFF8F7F2);
  static const Color kdsMuted = Color(0xFFA6ABA3);
}

/// Superficies oscuras destacadas (ventas, saldo): carbón con un matiz cálido
/// muy leve hacia la esquina inferior. Mismo contraste que [AppColors.ink].
abstract final class AppGradients {
  static const LinearGradient ink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF1C1D1B), Color(0xFF2A221E)],
  );
}

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Margen lateral estándar de pantallas.
  static const double gutter = 20;
}

abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const Radius pill = Radius.circular(999);
}

/// Diseño de producción original v0.6.0. Los TTF se recuperan localmente
/// del paquete canónico del propietario antes de compilar (no se redistribuyen).
abstract final class AppFonts {
  static const String body = 'Figtree';
  static const String display = 'Bricolage';
  static const List<ui.FontFeature> tabular = <ui.FontFeature>[
    ui.FontFeature.tabularFigures(),
  ];
}

abstract final class AppText {
  static const TextStyle display = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 34,
    height: 1.06,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    color: AppColors.ink,
  );
  static const TextStyle headline = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.ink,
  );
  static const TextStyle title = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.15,
    color: AppColors.ink,
  );
  static const TextStyle subtitle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    height: 1.42,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );
  static const TextStyle bodySoft = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    height: 1.42,
    fontWeight: FontWeight.w500,
    color: AppColors.inkSoft,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: AppColors.inkSoft,
  );
  static const TextStyle label = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 13.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const TextStyle button = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.05,
  );

  /// Cifras grandes (ventas, totales, contadores).
  static const TextStyle figure = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 26,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.ink,
    fontFeatures: AppFonts.tabular,
  );

  /// Folio de pedido "#1842".
  static const TextStyle folio = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 22,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.ink,
    fontFeatures: AppFonts.tabular,
  );
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.brand,
    onPrimary: AppColors.ink,
    secondary: AppColors.ink,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkSoft,
    error: AppColors.red,
    onError: Colors.white,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
  );

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppFonts.body,
    scaffoldBackgroundColor: AppColors.canvas,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: const TextTheme(
      displaySmall: AppText.display,
      headlineMedium: AppText.headline,
      titleLarge: AppText.title,
      titleMedium: AppText.subtitle,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.caption,
      labelLarge: AppText.button,
      labelMedium: AppText.label,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(
        color: AppColors.inkFaint,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: AppColors.inkSoft,
      suffixIconColor: AppColors.inkSoft,
      errorStyle: const TextStyle(
        color: AppColors.red,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
        height: 1.3,
      ),
      errorMaxLines: 3,
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      disabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.ink, 1.6),
      errorBorder: border(AppColors.red),
      focusedErrorBorder: border(AppColors.red, 1.6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.brandTint,
      elevation: 0,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? AppColors.ink : AppColors.inkSoft,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? AppColors.brandText
              : AppColors.inkSoft,
        ),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.brandTint,
      selectedIconTheme: IconThemeData(color: AppColors.brandText),
      unselectedIconTheme: IconThemeData(color: AppColors.inkSoft),
      selectedLabelTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.inkSoft,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.surface.withValues(alpha: 0.9);
        }
        return AppColors.surface;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        final on = states.contains(WidgetState.selected);
        if (states.contains(WidgetState.disabled)) {
          return on
              ? AppColors.green.withValues(alpha: 0.45)
              : AppColors.lineStrong.withValues(alpha: 0.6);
        }
        return on ? AppColors.green : AppColors.lineStrong;
      }),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.canvas,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.lineStrong,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      // Borde tenue: el aviso se distingue también sobre el fondo oscuro de
      // cocina.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: Color(0x24FFFFFF)),
      ),
      contentTextStyle: const TextStyle(
        fontFamily: AppFonts.body,
        color: Colors.white,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: AppColors.brand,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
      linearTrackColor: AppColors.line,
      refreshBackgroundColor: AppColors.surface,
    ),
    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.brand,
      textColor: AppColors.ink,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      titleTextStyle: AppText.title,
      contentTextStyle: AppText.bodySoft,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        fontFamily: AppFonts.body,
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.ink,
      selectionColor: AppColors.brand.withValues(alpha: 0.25),
      selectionHandleColor: AppColors.brand,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _AppPageTransitionsBuilder(),
        TargetPlatform.iOS: _AppPageTransitionsBuilder(),
      },
    ),
  );
}

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildAppPageTransition(context, animation, child);
  }
}

/// Transición compartida: fade + desplazamiento corto. Sin rebotes.
Widget buildAppPageTransition(
  BuildContext context,
  Animation<double> animation,
  Widget child,
) {
  if (MediaQuery.of(context).disableAnimations) return child;
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

/// Ruta estándar de la app (260 ms entrada / 200 ms salida).
PageRoute<T> appRoute<T>(
  Widget page, {
  bool fullscreenDialog = false,
}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        buildAppPageTransition(context, animation, child),
  );
}

/// Duraciones de motion. Todas pasan por [Motion.of] para respetar
/// "reducir movimiento" del sistema.
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 260);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
