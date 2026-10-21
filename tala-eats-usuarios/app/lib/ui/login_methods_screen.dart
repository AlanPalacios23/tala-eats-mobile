part of '../main.dart';

/// Photo A: clean full-bleed login-method selector. No hero copy, no central
/// wordmark and no fake social authentication.
class TalaLoginMethodsScreen extends StatelessWidget {
  const TalaLoginMethodsScreen({
    super.key,
    required this.onEmail,
    required this.onBack,
    this.onRegister,
  });

  final VoidCallback onEmail;
  final VoidCallback onBack;
  final VoidCallback? onRegister;

  void _unsupported(BuildContext context, String provider) {
    HapticFeedback.selectionClick();
    if (provider != 'Google') {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'El acceso por celular aún no está disponible. '
          'Puedes entrar o crear tu cuenta con correo.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Correo', onPressed: onEmail),
      ));
      return;
    }
    // Critical security boundary: never imitate Google OAuth. The existing
    // backend accepts only an independent Tala Eats password.
    showModalBottomSheet<void>(
      context: context, useSafeArea: true, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (BuildContext sheet) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          const Text('Acceso a TALA EATS',
            style: TextStyle(fontSize: 25, color: Colors.black,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          const Text(
            'El inicio de sesión con Google todavía no está conectado. '
            'Puedes crear una cuenta de TALA EATS con tu correo, '
            'usando una contraseña nueva, distinta de la de Google.',
            style: TextStyle(fontSize: 15, height: 1.45)),
          const SizedBox(height: 18),
          FilledButton(
            key: const ValueKey<String>('createTalaAccount'),
            style: FilledButton.styleFrom(
              backgroundColor: kBrandDeep, minimumSize: const Size.fromHeight(56)),
            onPressed: () {
              Navigator.of(sheet).pop();
              (onRegister ?? onEmail)();
            },
            child: const Text('Crear cuenta TALA EATS'),
          ),
          const SizedBox(height: 10),
          TextButton(
            key: const ValueKey<String>('existingTalaAccount'),
            onPressed: () {
              Navigator.of(sheet).pop();
              onEmail();
            },
            child: const Text('Ya tengo cuenta: iniciar sesión'),
          ),
        ]),
      ),
    );
  }

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
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF251C32),
              ),
            ),
            const IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x40000000), Color(0x00000000),
                    Color(0x45000000), Color(0xD6000000),
                  ],
                  stops: <double>[0, .26, .55, 1],
                ),
              ),
            )),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 18,
              child: Material(
                color: const Color(0x60000000),
                shape: const CircleBorder(),
                child: IconButton(
                  key: const ValueKey<String>('methodsBack'),
                  tooltip: 'Volver a bienvenida',
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: onBack,
                ),
              ),
            ),
            Positioned(
              bottom: math.max(20, bottom + 18),
              left: 22,
              right: 22,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _LoginMethodButton(
                    key: const ValueKey<String>('signInGoogle'),
                    label: 'Continuar con Google',
                    leading: const Text('G',
                        style: TextStyle(color: Colors.white,
                            fontSize: 28, fontWeight: FontWeight.w800)),
                    color: const Color(0xFF2262E9),
                    onPressed: () => _unsupported(context, 'Google'),
                  ),
                  const SizedBox(height: 12),
                  _LoginMethodButton(
                    key: const ValueKey<String>('signInPhone'),
                    label: 'Continuar con tu celular',
                    leading: const Icon(Icons.phone_in_talk_rounded,
                        size: 25, color: Colors.white),
                    color: const Color(0xFF15803D),
                    onPressed: () => _unsupported(context, 'celular'),
                  ),
                  const SizedBox(height: 12),
                  _LoginMethodButton(
                    key: const ValueKey<String>('signInEmail'),
                    label: 'Continuar con tu correo',
                    leading: const Icon(Icons.mail_outline_rounded,
                        size: 26, color: Colors.white),
                    color: const Color(0xFF64748B),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onEmail();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginMethodButton extends StatelessWidget {
  const _LoginMethodButton({
    super.key,
    required this.label,
    required this.leading,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Widget leading;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: <Widget>[
                SizedBox(width: 35, child: Center(child: leading)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 35),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
