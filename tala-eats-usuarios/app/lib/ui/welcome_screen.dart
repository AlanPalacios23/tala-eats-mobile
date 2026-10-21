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
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compact = constraints.maxHeight < 700;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 36),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(height: compact ? 84 : constraints.maxHeight * .17),
                            // Exact brand letter artwork (transparent crop);
                            // never place it in a pill, card or shadowed box.
                            Image.asset(
                              'assets/landing/tala_eats_wordmark_transparent.png',
                              key: const ValueKey<String>('welcomeWordmark'),
                              width: compact ? 250 : 288,
                              height: compact ? 78 : 102,
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.contain,
                              semanticLabel: 'Tala Eats',
                              errorBuilder: (_, __, ___) => const Text(
                                'Tala Eats',
                                style: TextStyle(
                                  fontSize: 38, fontWeight: FontWeight.w800,
                                  color: Color(0xFFFF5A1F),
                                ),
                              ),
                            ),
                            const SizedBox(height: 17),
                            Text(
                              'Bienvenido\na Tala Eats',
                              key: const ValueKey<String>('welcomeTitle'),
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 35 : 41,
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                                letterSpacing: -1.2,
                              ),
                            ),
                            const SizedBox(height: 13),
                            Text(
                              'Tus platillos favoritos,\nmás cerca de ti.',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 17 : 19,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 26),
                            _WelcomeGlassContinue(onPressed: _continue),
                          ],
                        ),
                      ),
                    ),
                  );
                },
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
