part of '../main.dart';

/// Preview login: only the currently functional first-party email flow.
/// Google OAuth and phone OTP are intentionally not displayed until supported.
class TalaLoginMethodsScreen extends StatelessWidget {
  const TalaLoginMethodsScreen({
    super.key,
    required this.onEmail,
    required this.onBack,
    this.onRegister,
  });

  final VoidCallback onEmail;
  final VoidCallback onBack;
  // Retained for compatibility with the surrounding shell.
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF251C32),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              'assets/landing/food_fiesta.webp',
              key: const ValueKey<String>('loginPhotoA'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Color(0xFF251C32)),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0x16000000),
                      Color(0x00000000),
                      Color(0x64000000),
                      Color(0xBF000000),
                    ],
                    stops: <double>[0, .32, .70, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 18,
              child: Material(
                color: const Color(0x60000000),
                shape: const CircleBorder(),
                child: IconButton(
                  key: const ValueKey<String>('methodsBack'),
                  tooltip: 'Volver a bienvenida',
                  icon: const Icon(
                    Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: onBack,
                ),
              ),
            ),
            Positioned(
              bottom: math.max(20, bottom + 18),
              left: 22,
              right: 22,
              child: _LoginEmailButton(
                key: const ValueKey<String>('signInEmail'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onEmail();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginEmailButton extends StatelessWidget {
  const _LoginEmailButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBrandDeep,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 32,
                  child: Icon(
                    Icons.mail_outline_rounded,
                    size: 25,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Continuar con tu correo',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
                SizedBox(width: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
