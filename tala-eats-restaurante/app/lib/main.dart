import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'data/app_services.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_pending_screen.dart';
import 'screens/two_factor_setup_screen.dart';
import 'screens/shell.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/session_controller.dart';
import 'widgets/motion.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(TalaEatsRestaurantApp(services: AppServices.production()));
}

void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final figtree = await rootBundle.loadString('assets/fonts/OFL-Figtree.txt');
    yield LicenseEntryWithLineBreaks(const <String>['Figtree'], figtree);
    final bricolage = await rootBundle.loadString(
      'assets/fonts/OFL-BricolageGrotesque.txt',
    );
    yield LicenseEntryWithLineBreaks(
      const <String>['Bricolage Grotesque'],
      bricolage,
    );
  });
}

class TalaEatsRestaurantApp extends StatefulWidget {
  const TalaEatsRestaurantApp({super.key, this.services});

  /// Capa de datos. Si es nula se usa la integración productiva remota.
  final AppServices? services;

  @override
  State<TalaEatsRestaurantApp> createState() => _TalaEatsRestaurantAppState();
}

class _TalaEatsRestaurantAppState extends State<TalaEatsRestaurantApp> {
  late final AppServices _services = widget.services ?? AppServices.production();
  late final SessionController _session = SessionController(_services);

  @override
  void initState() {
    super.initState();
    _session.bootstrap();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tala Eats Restaurante',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.35,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _RootGate(session: _session),
    );
  }
}

/// Decide la pantalla raíz según el estado de sesión, con un fundido corto.
class _RootGate extends StatelessWidget {
  const _RootGate({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final Widget screen;
        switch (session.status) {
          case SessionStatus.booting:
            screen = const SplashScreen(key: ValueKey<String>('splash'));
            break;
          case SessionStatus.welcome:
            screen = WelcomeScreen(
              key: const ValueKey<String>('welcome'),
              session: session,
            );
            break;
          case SessionStatus.signedOut:
            screen = LoginScreen(
              key: const ValueKey<String>('login'),
              session: session,
            );
            break;
          case SessionStatus.pendingApproval:
            screen = OnboardingPendingScreen(
              key: const ValueKey<String>('pendingApproval'),
              session: session,
            );
            break;
          case SessionStatus.securitySetup:
            screen = TwoFactorSetupScreen(
              key: const ValueKey<String>('securitySetup'),
              session: session,
            );
            break;
          case SessionStatus.signedIn:
            screen = RestaurantShell(
              key: ValueKey<String>('shell-${session.user?.email ?? ''}'),
              session: session,
            );
            break;
        }
        return ColoredBox(
          color: AppColors.canvas,
          child: StateSwitcher(expand: true, child: screen),
        );
      },
    );
  }
}
