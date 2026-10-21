part of '../main.dart';

/// Photo B: only the chosen wooden-table photograph. No carousel and no
/// opaque logo tile. Glass is reserved exclusively for the continue CTA.
class TalaWelcomeScreen extends StatefulWidget {
  const TalaWelcomeScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;
  @override
  State<TalaWelcomeScreen> createState() => _TalaWelcomeScreenState();
}

class _TalaWelcomeScreenState extends State<TalaWelcomeScreen> {
  bool _continuing = false;

  void _continue() {
    if (_continuing) return;
    _continuing = true;
    HapticFeedback.selectionClick();
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF25291C),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              'assets/landing/food_tala.webp',
              key: const ValueKey<String>('welcomePhotoB'),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              alignment: Alignment.center,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF25291C),
              ),
            ),
            const IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x0A000000), Color(0x22000000),
                    Color(0x34000000), Color(0x60000000),
                  ],
                  stops: <double>[0, .27, .65, 1],
                ),
              ),
            )),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(25, 10, 25, 24),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints area) {
                    final bool compact = area.maxWidth < 350 ||
                        area.maxHeight < 680;
                    final double titleSize = compact ? 33 : 40;
                    return Column(
                      children: <Widget>[
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  // Original transparent lettering: NO tile,
                                  // border, shadow, outline or glow.
                                  Image.asset(
                                    'assets/landing/tala_eats_wordmark_transparent.png',
                                    key: const ValueKey<String>('welcomeWordmark'),
                                    width: compact ? 250 : 290,
                                    height: compact ? 75 : 92,
                                    filterQuality: FilterQuality.high,
                                    fit: BoxFit.contain,
                                    semanticLabel: 'Tala Eats',
                                    errorBuilder: (_, __, ___) => const Text(
                                      'Tala Eats',
                                      style: TextStyle(
                                        fontSize: 35,
                                        color: Color(0xFFFF5A1F),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 20 : 28),
                                  Text(
                                    'Bienvenido\na Tala Eats',
                                    key: const ValueKey<String>('welcomeTitle'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: titleSize,
                                      fontWeight: FontWeight.w800,
                                      height: 1.08,
                                      letterSpacing: -1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Tus platillos favoritos,\nmás cerca de ti.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: compact ? 17 : 19,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _WelcomeGlassContinue(onPressed: _continue),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeGlassContinue extends StatelessWidget {
  const _WelcomeGlassContinue({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: const Color(0x88FFFFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xE6FFFFFF), width: 1.2),
          ),
          child: InkWell(
            key: const ValueKey<String>('talaWelcomeContinue'),
            onTap: onPressed,
            borderRadius: BorderRadius.circular(24),
            child: const SizedBox(
              height: 64,
              child: Row(
                children: <Widget>[
                  Spacer(),
                  Text('Continuar',
                    style: TextStyle(
                      color: kInk, fontWeight: FontWeight.w800, fontSize: 18,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: kBrandDeep),
                  SizedBox(width: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
