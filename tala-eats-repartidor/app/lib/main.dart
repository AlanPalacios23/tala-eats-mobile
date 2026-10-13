import 'package:flutter/material.dart';

import 'core/controller.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'widgets/brand.dart';
import 'widgets/motion.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TalaEatsDriverApp());
}

class TalaEatsDriverApp extends StatefulWidget {
  const TalaEatsDriverApp({super.key, this.controller});

  /// Inyectable para pruebas/integración. Si es `null`, la app crea y
  /// administra su propio [DriverController] conectado al backend de producción.
  final DriverController? controller;

  @override
  State<TalaEatsDriverApp> createState() => _TalaEatsDriverAppState();
}

class _TalaEatsDriverAppState extends State<TalaEatsDriverApp> {
  late final DriverController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? DriverController.production();
    _controller.bootstrap();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Tala Eats Repartidor',
        theme: driverTheme(),
        home: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final Widget screen = _controller.booting
                ? const _Splash(key: ValueKey('splash'))
                : _controller.signedIn
                    ? DriverShell(
                        key: const ValueKey('shell'),
                        controller: _controller,
                      )
                    : LoginScreen(
                        key: const ValueKey('login'),
                        controller: _controller,
                      );
            final largeText =
                MediaQuery.textScalerOf(context).scale(1) >= 1.25;
            // Con texto aumentado evitamos mantener dos pantallas completas
            // montadas durante el cambio Login -> Home. Además de ser más
            // accesible, elimina overflows transitorios de la pantalla saliente.
            if (Motion.reduced(context) || largeText) return screen;
            return AnimatedSwitcher(
              duration: Motion.medium,
              switchInCurve: Motion.standard,
              switchOutCurve: Motion.exit,
              child: screen,
            );
          },
        ),
      );
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLockup(center: true),
            const SizedBox(height: Space.xxl),
            Semantics(
              label: 'Iniciando',
              child: SizedBox(
                width: 120,
                child: reduced
                    ? const Text(
                        'Iniciando…',
                        textAlign: TextAlign.center,
                        style: AppText.caption,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.pill),
                        child: const LinearProgressIndicator(minHeight: 3),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
