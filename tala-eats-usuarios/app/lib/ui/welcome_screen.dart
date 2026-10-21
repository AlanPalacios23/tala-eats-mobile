part of '../main.dart';

/// Full-bleed first-run welcome using the two owner-provided photos.
/// The CTA opens the existing email/password LoginScreen, not a mock sign-in.
class TalaWelcomeScreen extends StatefulWidget {
  const TalaWelcomeScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<TalaWelcomeScreen> createState() => _TalaWelcomeScreenState();
}

class _TalaWelcomeScreenState extends State<TalaWelcomeScreen> {
  static const List<String> _photographs = <String>[
    'assets/landing/food_fiesta.webp',
    'assets/landing/food_tala.webp',
  ];
  Timer? _rotation;
  int _current = 0;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = TalaMotion.reduced(context);
    if (reduce == _reduceMotion && _rotation != null) return;
    _reduceMotion = reduce;
    _rotation?.cancel();
    _rotation = null;
    if (!reduce) {
      _rotation = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted) setState(() => _current = (_current + 1) % _photographs.length);
      });
    }
  }

  @override
  void dispose() {
    _rotation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFF17120F),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Cover fills the entire screen, including behind the status bar.
          AnimatedSwitcher(
            duration: _reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 1200),
            switchInCurve: Curves.easeInOutCubic,
            switchOutCurve: Curves.easeInOutCubic,
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              fit: StackFit.expand,
              children: <Widget>[...previous, if (current != null) current],
            ),
            child: Image.asset(
              _photographs[_current],
              key: ValueKey<int>(_current),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              excludeFromSemantics: true,
              errorBuilder: (BuildContext context, Object error,
                  StackTrace? trace) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFF87462D), Color(0xFF271B16)],
                  ),
                ),
              ),
            ),
          ),
          // Text contrast holds for either colorful or dark food photograph.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x87000000),
                    Color(0x1A000000),
                    Color(0x3D000000),
                    Color(0xD9000000),
                  ],
                  stops: <double>[0, 0.34, 0.58, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: top + 26,
            left: 22,
            right: 22,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 17, sigmaY: 17),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xE8FFFFFF),
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(
                        color: const Color(0xF2FFFFFF),
                        width: 1.1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Image.asset(
                        'assets/landing/tala_eats_original_wordmark.png',
                        width: 202,
                        height: 76,
                        fit: BoxFit.contain,
                        semanticLabel: 'Tala Eats',
                        errorBuilder: (BuildContext context, Object error,
                                StackTrace? stack) =>
                            const Text('TALA EATS',
                                style: TextStyle(
                                  fontSize: 26,
                                  color: kBrandDeep,
                                  fontWeight: FontWeight.w800,
                                )),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: bottom + 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Comienza a pedir lo que más te gusta.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                    shadows: <Shadow>[
                      Shadow(
                        color: Color(0x4D000000),
                        offset: Offset(0, 2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tu comida favorita, más cerca de ti.',
                  style: TextStyle(
                    color: Color(0xFFFAF6F3),
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  label: 'Continuar para iniciar sesión',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 23, sigmaY: 23),
                      child: Material(
                        color: const Color(0xDDFDFBF9),
                        child: InkWell(
                          key: const ValueKey<String>('talaWelcomeContinue'),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onContinue();
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 64),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xF5FFFFFF),
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text('Continuar',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: kInk,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      )),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward_rounded,
                                      color: kBrandDeep, size: 23),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List<Widget>.generate(
                    _photographs.length,
                    (int i) => AnimatedContainer(
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      width: i == _current ? 30 : 14,
                      decoration: BoxDecoration(
                        color: i == _current
                            ? Colors.white
                            : const Color(0x80FFFFFF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
