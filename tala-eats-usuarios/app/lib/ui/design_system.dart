part of '../main.dart';

// ---------------------------------------------------------------------------
// Tala Eats design system (premium discovery polish v1.0.23)
// Tokens, theme, motion and shared building blocks. UI only: nothing in this
// file talks to the network or changes TalaModel state.
// ---------------------------------------------------------------------------

const Color kInkSoft = Color(0xFF3B3633);
const Color kSubtle = Color(0xFFA29C97);
const Color kSunken = Color(0xFFF3EFEB);
const Color kLineStrong = Color(0xFFE2DBD5);
const Color kDanger = Color(0xFFC6312A);
const Color kDangerSoft = Color(0xFFFFEDEA);
const Color kScrim = Color(0x591C140F);

/// WCAG contrast for small labels on colored notices and status surfaces.
/// Adapts functional text only; logo and original brand color stay unchanged.
class TalaReadableText {
  static double contrast(Color foreground, Color background) {
    final double a = foreground.computeLuminance();
    final double b = background.computeLuminance();
    return ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
  }

  static Color against(Color foreground, Color background) {
    if (contrast(foreground, background) >= 4.5) return foreground;
    for (int i = 1; i <= 20; i++) {
      final Color candidate = Color.lerp(
        foreground, Colors.black, i / 20,
      )!;
      if (contrast(candidate, background) >= 4.5) return candidate;
    }
    return Colors.black;
  }
}

const List<BoxShadow> kShadowSoft = <BoxShadow>[
  BoxShadow(color: Color(0x0B25211E), blurRadius: 20, offset: Offset(0, 6)),
];
const List<BoxShadow> kShadowLifted = <BoxShadow>[
  BoxShadow(color: Color(0x1225211E), blurRadius: 28, offset: Offset(0, 10)),
];

/// Spacing scale (dp).
class TalaSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double page = 20;
}

/// Typography scale. Roboto (Android system font) with a tight, confident
/// display style and calm body text.
class TalaText {
  static const TextStyle display = TextStyle(color: kInk, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.08);
  static const TextStyle h1 = TextStyle(color: kInk, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.12);
  static const TextStyle h2 = TextStyle(color: kInk, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.2);
  static const TextStyle title = TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1, height: 1.25);
  static const TextStyle body = TextStyle(color: kInkSoft, fontSize: 14, fontWeight: FontWeight.w400, height: 1.45);
  static const TextStyle muted = TextStyle(color: kMuted, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);
  static const TextStyle caption = TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3);
  static const TextStyle overline = TextStyle(color: kBrandDeep, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4);
  static const TextStyle price = TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2);
}

/// Motion tokens. Every animated widget in the app reads durations from here
/// and honours the Android "remove animations" accessibility setting.
class TalaMotion {
  static const Duration micro = Duration(milliseconds: 140);
  static const Duration select = Duration(milliseconds: 200);
  static const Duration reveal = Duration(milliseconds: 300);
  static const Duration page = Duration(milliseconds: 320);
  static const Duration pageReverse = Duration(milliseconds: 260);
  static const Duration success = Duration(milliseconds: 620);
  static const Curve ease = Curves.easeOutCubic;
  static const Curve inOut = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration value) => reduced(context) ? Duration.zero : value;
}

ThemeData buildTalaTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    primary: kBrand,
    brightness: Brightness.light,
    surface: kSurface,
  );
  final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return ThemeData(
    useMaterial3: true,
    // Make Roboto explicit for Android and for faithful, legible golden tests.
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: kBackground,
    canvasColor: kBackground,
    fontFamilyFallback: const <String>['Roboto', 'Arial'],
    splashFactory: InkRipple.splashFactory,
    splashColor: kBrand.withValues(alpha: 0.08),
    highlightColor: Colors.transparent,
    dividerColor: kLine,
    dividerTheme: const DividerThemeData(color: kLine, thickness: 1, space: 1),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: TalaPageTransitionsBuilder(),
        TargetPlatform.iOS: TalaPageTransitionsBuilder(),
        TargetPlatform.fuchsia: TalaPageTransitionsBuilder(),
        TargetPlatform.linux: TalaPageTransitionsBuilder(),
        TargetPlatform.macOS: TalaPageTransitionsBuilder(),
        TargetPlatform.windows: TalaPageTransitionsBuilder(),
      },
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kLine)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBackground,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 4,
      titleTextStyle: TextStyle(fontFamily: 'Roboto', color: kInk, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3),
      iconTheme: IconThemeData(color: kInk),
      actionsIconTheme: IconThemeData(color: kInk),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrandDeep,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFF2D6CB),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.1),
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: kInk,
        backgroundColor: Colors.white,
        side: const BorderSide(color: kLineStrong),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 15),
        shape: buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kBrandDeep,
        minimumSize: const Size(48, 44),
        textStyle: const TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: kInk),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: const TextStyle(color: kSubtle, fontWeight: FontWeight.w500),
      labelStyle: const TextStyle(color: kMuted, fontWeight: FontWeight.w600),
      floatingLabelStyle: const TextStyle(color: kBrandDeep, fontWeight: FontWeight.w700),
      prefixIconColor: kMuted,
      suffixIconColor: kMuted,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kBrand, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kDanger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kDanger, width: 1.6)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kBrand, linearTrackColor: kSoftOrange),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) => states.contains(WidgetState.selected) ? Colors.white : const Color(0xFFBDB6B0)),
      trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) => states.contains(WidgetState.selected) ? kBrand : kSunken),
      trackOutlineColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) => states.contains(WidgetState.selected) ? kBrand : kLineStrong),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) => states.contains(WidgetState.selected) ? kBrand : Colors.white),
      side: const BorderSide(color: kLineStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: kInk, contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: kScrim,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kInk,
      contentTextStyle: const TextStyle(fontFamily: 'Roboto', color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
      actionTextColor: const Color(0xFFFFB498),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Page transitions: soft fade + short horizontal glide. No zoom, no dark
// scrim, no snapshotting — avoids the black/blank flash between screens.
// ---------------------------------------------------------------------------

class TalaPageTransitionsBuilder extends PageTransitionsBuilder {
  const TalaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return TalaPageTransition(animation: animation, secondaryAnimation: secondaryAnimation, child: child);
  }
}

class TalaPageTransition extends StatelessWidget {
  const TalaPageTransition({super.key, required this.animation, required this.secondaryAnimation, required this.child});

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (TalaMotion.reduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final Animation<double> enter = CurvedAnimation(parent: animation, curve: TalaMotion.ease, reverseCurve: Curves.easeInCubic);
    final Animation<double> exit = CurvedAnimation(parent: secondaryAnimation, curve: TalaMotion.ease, reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween<Offset>(begin: Offset.zero, end: const Offset(-0.03, 0)).animate(exit),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(enter),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: animation, curve: const Interval(0, 0.7, curve: Curves.easeOut))),
          child: ColoredBox(color: kBackground, child: child),
        ),
      ),
    );
  }
}

/// Route used across the app. A MaterialPageRoute so it gets the themed
/// transition, Android back handling and correct semantics.
Route<T> premiumRoute<T>(Widget page) {
  return MaterialPageRoute<T>(builder: (BuildContext context) => page);
}

// ---------------------------------------------------------------------------
// Motion primitives
// ---------------------------------------------------------------------------

/// Press feedback: a short, subtle scale-down while the pointer is down.
/// The child keeps its own InkWell / onTap; this only adds the tactile feel.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = 0.975});

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset _origin = Offset.zero;

  void _set(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || TalaMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (event) {
        _origin = event.position;
        _set(true);
      },
      onPointerMove: (event) {
        if ((event.position - _origin).distance > 10) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: TalaMotion.micro,
        curve: TalaMotion.ease,
        child: widget.child,
      ),
    );
  }
}

/// One-shot entrance: fade + short rise. Staggered by [index] (capped) and
/// driven by a single tween — no timers, so it is test- and scroll-safe.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.offset = 14});

  final Widget child;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    if (TalaMotion.reduced(context) || index > 7) return child;
    final int delay = index * 45;
    final int total = 300 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (BuildContext context, double value, Widget? child) {
        final double local = ((value * total - delay) / 300).clamp(0.0, 1.0).toDouble();
        final double t = Curves.easeOutCubic.transform(local);
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, offset * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }
}

/// Backwards-compatible name used by earlier builds.
class StaggeredReveal extends StatelessWidget {
  const StaggeredReveal({super.key, required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) => Reveal(index: (delay / 45).round(), child: child);
}

/// Small "pop" used when a value changes (favorite, quantity, badge).
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.from = 0.82});

  final Widget child;
  final double from;

  @override
  Widget build(BuildContext context) {
    if (TalaMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: from, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double value, Widget? child) => Transform.scale(scale: value, child: child),
      child: child,
    );
  }
}

/// Subtle breathing placeholder for loading content.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TalaMotion.reduced(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: const Color(0xFFEDE7E2), borderRadius: BorderRadius.circular(radius)),
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

/// White surface with hairline border. Tappable variant adds ripple + press.
class TalaCard extends StatelessWidget {
  const TalaCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.color = Colors.white,
    this.borderColor = kLine,
    this.shadow = false,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color borderColor;
  final bool shadow;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(radius);
    final Widget inner = Padding(padding: padding, child: child);
    Widget card = Material(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: br, side: BorderSide(color: borderColor)),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? inner : InkWell(onTap: onTap, child: inner),
    );
    if (shadow) {
      card = DecoratedBox(decoration: BoxDecoration(borderRadius: br, boxShadow: kShadowSoft), child: card);
    }
    if (onTap != null) card = Pressable(child: card);
    return Padding(padding: margin, child: card);
  }
}

/// Round 44dp icon button on a white surface (back, favorite, notifications).
class TalaCircleButton extends StatelessWidget {
  const TalaCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconColor = kInk,
    this.background = Colors.white,
    this.size = 44,
    this.bordered = true,
    this.badge = 0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color iconColor;
  final Color background;
  final double size;
  final bool bordered;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final Widget button = Pressable(
      scale: 0.92,
      child: Material(
        color: background,
        shape: CircleBorder(side: bordered ? const BorderSide(color: kLine) : BorderSide.none),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(width: size, height: size, child: Icon(icon, color: iconColor, size: size * 0.5)),
        ),
      ),
    );
    final Widget withBadge = badge <= 0
        ? button
        : Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              button,
              Positioned(
                right: -2,
                top: -2,
                child: PopIn(
                  key: ValueKey<int>(badge),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: kBrandDeep, borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white, width: 2)),
                    child: Text(badge > 9 ? '9+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, height: 1)),
                  ),
                ),
              ),
            ],
          );
    if (tooltip == null) return withBadge;
    return Tooltip(message: tooltip!, child: withBadge);
  }
}

class TalaSectionHeader extends StatelessWidget {
  const TalaSectionHeader({super.key, required this.title, this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: TalaText.h2),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(subtitle!, style: TalaText.caption),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Small rounded count/label chip (e.g. "4" next to a section title).
class TalaCountChip extends StatelessWidget {
  const TalaCountChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: kSunken, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: const TextStyle(color: kInkSoft, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Selectable pill used for tips, filters, preferences and delivery mode.
class TalaChoicePill extends StatelessWidget {
  const TalaChoicePill({super.key, required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Duration d = TalaMotion.of(context, TalaMotion.select);
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        scale: 0.95,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: AnimatedContainer(
              duration: d,
              curve: TalaMotion.ease,
              constraints: const BoxConstraints(minHeight: 42),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? kSoftOrange : Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: selected ? kBrand : kLine, width: selected ? 1.4 : 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 17, color: selected ? kBrandDeep : kMuted),
                    const SizedBox(width: 6),
                  ],
                  AnimatedDefaultTextStyle(
                    duration: d,
                    style: TextStyle(color: selected ? kBrandDeep : kInkSoft, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, fontSize: 14),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// − qty + control shared by product sheet and cart.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
    this.compact = false,
    this.deleteAtOne = false,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final bool compact;
  final bool deleteAtOne;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 36 : 44;
    final bool showDelete = deleteAtOne && quantity <= 1;
    return Container(
      height: size + 4,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: kSunken, borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepperButton(
            icon: showDelete ? Icons.delete_outline_rounded : Icons.remove_rounded,
            tooltip: showDelete ? 'Quitar' : 'Menos',
            size: size,
            onTap: onDecrement,
            color: showDelete ? kDanger : kInk,
          ),
          SizedBox(
            width: compact ? 26 : 32,
            child: AnimatedSwitcher(
              duration: TalaMotion.of(context, TalaMotion.select),
              transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: Tween<double>(begin: 0.7, end: 1).animate(animation), child: child),
              ),
              child: Text(
                '$quantity',
                key: ValueKey<int>(quantity),
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 15 : 17, color: kInk),
              ),
            ),
          ),
          _StepperButton(icon: Icons.add_rounded, tooltip: 'Más', size: size, onTap: onIncrement, color: kInk),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.tooltip, required this.size, required this.onTap, required this.color});

  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.48, color: onTap == null ? kSubtle : color),
          ),
        ),
      ),
    );
  }
}

/// Full status block: empty, error, offline, closed, unavailable...
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.tone = StatusTone.neutral,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final StatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (tone) {
      StatusTone.neutral => kBrand,
      StatusTone.danger => kDanger,
      StatusTone.success => kGreen,
    };
    final Color soft = switch (tone) {
      StatusTone.neutral => kSoftOrange,
      StatusTone.danger => kDangerSoft,
      StatusTone.success => kSoftGreen,
    };
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: compact ? 20 : 36),
        child: Reveal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: compact ? 64 : 76,
                height: compact ? 64 : 76,
                decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
                child: Icon(icon, size: compact ? 30 : 34, color: accent),
              ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: TalaText.h2.copyWith(fontSize: 19)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(body, textAlign: TextAlign.center, style: TalaText.muted.copyWith(fontSize: 14)),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 18),
                SizedBox(
                  width: 220,
                  child: OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum StatusTone { neutral, danger, success }

/// Backwards-compatible empty state used across the app.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => StatusView(icon: icon, title: title, body: body, actionLabel: actionLabel, onAction: onAction);
}

/// Inline notice (info / error). Kept the historical name `AuthNotice`.
class AuthNotice extends StatelessWidget {
  const AuthNotice({super.key, required this.icon, required this.text, this.danger = false});

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color background = danger ? kDangerSoft : kSoftGreen;
    final Color color = TalaReadableText.against(
      danger ? kDanger : kGreen, background,
    );
    return Semantics(
      liveRegion: danger,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, color: color, size: 19)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4))),
          ],
        ),
      ),
    );
  }
}

/// Neutral, quiet info line (no colored box).
class QuietNote extends StatelessWidget {
  const QuietNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: kSubtle),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TalaText.caption.copyWith(fontWeight: FontWeight.w500))),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: TalaText.h2);
}

/// Grouped settings-style list: one white surface with hairline dividers.
class TalaGroup extends StatelessWidget {
  const TalaGroup({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) rows.add(const Padding(padding: EdgeInsets.only(left: 60), child: Divider()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title!.toUpperCase(), style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.9)),
          ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: kLine)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

/// A row inside [TalaGroup].
class AccountLink extends StatelessWidget {
  const AccountLink({super.key, required this.icon, required this.title, required this.onTap, this.subtitle, this.trailing, this.danger = false});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color = danger ? kDanger : kInk;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: danger ? kDangerSoft : kSoftPeach, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: danger ? kDanger : kBrandDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: TalaText.caption.copyWith(fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[trailing!, const SizedBox(width: 6)],
              const Icon(Icons.chevron_right_rounded, color: kSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Image with warm placeholder, soft fade-in and local fallback. Accepts the
/// HTTPS media fields the backend already returns (resolved in TalaModel).
class RestaurantMedia extends StatelessWidget {
  const RestaurantMedia({
    super.key,
    required this.assetPath,
    this.imageUrl = '',
    this.width,
    this.height,
    this.radius = 0,
    this.fit = BoxFit.cover,
    this.desaturate = false,
  });

  final String assetPath;
  final String imageUrl;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final bool desaturate;

  static const List<double> _softGray = <double>[
    0.62, 0.31, 0.07, 0, 0,
    0.19, 0.74, 0.07, 0, 0,
    0.19, 0.31, 0.50, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final Duration fade = TalaMotion.of(context, const Duration(milliseconds: 280));
    Widget fadeIn(BuildContext context, Widget child, int? frame, bool wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded) return child;
      return AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, curve: TalaMotion.ease, child: child);
    }

    final Widget fallback = assetPath.trim().isNotEmpty
        ? Image.asset(
            assetPath,
            width: width,
            height: height,
            fit: fit,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            frameBuilder: fadeIn,
            errorBuilder: (BuildContext context, Object error, StackTrace? stack) => const _MediaFallback(),
          )
        : const _MediaFallback();
    Widget image = imageUrl.startsWith('https://')
        ? Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            frameBuilder: fadeIn,
            errorBuilder: (BuildContext context, Object error, StackTrace? stack) => fallback,
          )
        : fallback;
    if (desaturate) {
      image = ColorFiltered(colorFilter: const ColorFilter.matrix(_softGray), child: image);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(width: width, height: height, color: const Color(0xFFF1EBE6), child: image),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF1EBE6),
      child: Center(child: Icon(Icons.restaurant_rounded, color: kSubtle, size: 28)),
    );
  }
}

/// Dish visual: real photo when the backend sends one, otherwise a clean
/// illustrated tile (never a repeated restaurant cover pretending to be the dish).
class DishThumb extends StatelessWidget {
  const DishThumb({super.key, required this.item, required this.size, this.radius = 16});

  final FoodItem item;
  final double size;
  final double radius;

  static IconData iconFor(String text) {
    final String t = _fold(text);
    // Generic merchandise must not look like a fake restaurant dish when
    // the merchant has not uploaded a real product photograph.
    if (t.contains('ferreter') || t.contains('tornillo') || t.contains('herramienta')) return Icons.handyman_rounded;
    if (t.contains('papeler') || t.contains('cuaderno') || t.contains('lapiz')) return Icons.edit_note_rounded;
    if (t.contains('florer') || t.contains('flores') || t.contains('ramo')) return Icons.local_florist_rounded;
    if (t.contains('regalo') || t.contains('obsequio')) return Icons.card_giftcard_rounded;
    if (t.contains('verdura') || t.contains('fruta') || t.contains('vegetal')) return Icons.eco_rounded;
    if (t.contains('carnicer') || t.contains('carne de')) return Icons.outdoor_grill_rounded;
    if (t.contains('abarrote') || t.contains('despensa')) return Icons.local_grocery_store_rounded;
    if (t.contains('bebida') || t.contains('refresco') || t.contains('agua') || t.contains('jugo') || t.contains('cafe')) return Icons.local_cafe_rounded;
    if (t.contains('postre') || t.contains('helado') || t.contains('pastel') || t.contains('dulce')) return Icons.icecream_rounded;
    if (t.contains('sushi') || t.contains('ramen') || t.contains('rollo')) return Icons.ramen_dining_rounded;
    if (t.contains('pizza')) return Icons.local_pizza_rounded;
    if (t.contains('hamburg') || t.contains('burger')) return Icons.lunch_dining_rounded;
    if (t.contains('ensalada') || t.contains('bowl')) return Icons.eco_rounded;
    if (t.contains('taco') || t.contains('burrito') || t.contains('quesadilla')) return Icons.local_fire_department_rounded;
    return Icons.restaurant_menu_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl.startsWith('https://')) {
      return RestaurantMedia(assetPath: item.image, imageUrl: item.imageUrl, width: size, height: size, radius: radius);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFFF1E8), Color(0xFFFFE3D4)]),
      ),
      child: Icon(iconFor('${item.category} ${item.name}'), color: kBrand.withValues(alpha: 0.75), size: size * 0.36),
    );
  }
}

/// Accent-insensitive lowercase for client-side filtering.
String _fold(String value) {
  const Map<String, String> map = <String, String>{'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final StringBuffer out = StringBuffer();
  for (final String ch in value.toLowerCase().split('')) {
    out.write(map[ch] ?? ch);
  }
  return out.toString();
}

/// Rating chip; hidden by callers when the backend reports no rating yet.
class RatingChip extends StatelessWidget {
  const RatingChip({super.key, required this.rating, this.onDark = false});

  final double rating;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: onDark ? Colors.white : const Color(0xFFFFF5DC), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, color: kGold, size: 15),
          const SizedBox(width: 3),
          Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: kInk)),
        ],
      ),
    );
  }
}

/// "icon text · icon text" meta line.
class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.items, this.color = kMuted});

  final List<(IconData, String)> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(width: 3, height: 3, decoration: BoxDecoration(color: color.withValues(alpha: 0.6), shape: BoxShape.circle)),
        ));
      }
      children.add(Icon(items[i].$1, size: 15, color: color));
      children.add(const SizedBox(width: 4));
      children.add(Flexible(child: Text(items[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))));
    }
    return Row(children: children);
  }
}

/// Status pill (Abierto / Cerrado / order states).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.dot = true,
  });

  final String label;
  final Color color;
  final Color background;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final Color textColor = TalaReadableText.against(color, background);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: (screenWidth - 40).clamp(120.0, 600.0).toDouble()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (dot) ...<Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: textColor,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor,
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fixed bottom action area with hairline top border and safe-area padding.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kLine)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: child,
      ),
    );
  }
}

/// Progress-aware primary button label (spinner while busy).
class BusyLabel extends StatelessWidget {
  const BusyLabel({super.key, required this.busy, required this.label, this.color = Colors.white});

  final bool busy;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: TalaMotion.of(context, const Duration(milliseconds: 180)),
      child: busy
          ? SizedBox(key: const ValueKey<String>('busy'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: color))
          : Text(label, key: ValueKey<String>(label), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Consistent page scaffold with a clean, light app bar.
class TalaPage extends StatelessWidget {
  const TalaPage({super.key, required this.title, required this.body, this.actions, this.bottom});

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: body,
      bottomNavigationBar: bottom,
    );
  }
}

class MoneyRow extends StatelessWidget {
  const MoneyRow({super.key, required this.label, required this.amount, this.bold = false, this.hint});

  final String label;
  final double amount;
  final bool bold;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: TextStyle(color: bold ? kInk : kInkSoft, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16 : 14)),
              if (hint != null) Text(hint!, style: TalaText.caption.copyWith(fontWeight: FontWeight.w500, fontSize: 11)),
            ],
          ),
        ),
        Text(
          money(amount),
          style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 20 : 14, color: amount < 0 ? kGreen : kInk, letterSpacing: bold ? -0.3 : 0),
        ),
      ],
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.model, required this.radius});

  final TalaModel model;
  final double radius;

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object>? provider;
    final String localPath = model.userLocalAvatarPath.trim();
    final String remoteUrl = model.userAvatarUrl.trim();
    if (localPath.isNotEmpty && File(localPath).existsSync()) {
      provider = FileImage(File(localPath));
    } else if (remoteUrl.startsWith('https://')) {
      provider = NetworkImage(remoteUrl);
    }
    final String initials = model.userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .map((String part) => part.substring(0, 1).toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: kSoftOrange,
      backgroundImage: provider,
      child: provider == null
          ? Text(initials.isEmpty ? 'TE' : initials, style: TextStyle(color: kBrandDeep, fontWeight: FontWeight.w800, fontSize: radius * 0.72))
          : null,
    );
  }
}

void showMessage(BuildContext context, String message) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2800)));
}

String money(double value) {
  final String sign = value < 0 ? '-' : '';
  return '$sign\$${value.abs().toStringAsFixed(0)}';
}

/// Customer-facing label for backend payment_status values (display only).
String paymentStatusLabel(String raw) {
  switch (raw) {
    case 'paid':
      return 'Pagado';
    case 'pending':
      return 'Pendiente';
    case 'in_process':
    case 'processing':
      return 'En revisión';
    case 'rejected':
    case 'failed':
      return 'Rechazado';
    case 'cancelled':
      return 'Cancelado';
    case 'refunded':
      return 'Reembolsado';
    default:
      return raw.isEmpty ? 'Pendiente' : raw;
  }
}

String firstName(String full) {
  final String trimmed = full.trim();
  if (trimmed.isEmpty) return '';
  final String first = trimmed.split(RegExp(r'\s+')).first;
  return first.isEmpty ? '' : '${first[0].toUpperCase()}${first.substring(1)}';
}
