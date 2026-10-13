// v0.5.16: pantallas de espera y seguridad sin logotipo, textos para el
// restaurante (sin jerga interna) y hoja de confirmación con ícono.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talaeats_restaurant/core/theme.dart';
import 'package:talaeats_restaurant/data/app_services.dart';
import 'package:talaeats_restaurant/data/local/qa_scenario.dart';
import 'package:talaeats_restaurant/models/entities.dart';
import 'package:talaeats_restaurant/screens/onboarding_pending_screen.dart';
import 'package:talaeats_restaurant/screens/two_factor_setup_screen.dart';
import 'package:talaeats_restaurant/state/session_controller.dart';
import 'package:talaeats_restaurant/widgets/feedback.dart';
import 'package:talaeats_restaurant/widgets/surfaces.dart';

SessionController _session({required String status, String notes = ''}) {
  final session = SessionController(
    AppServices.local(
      latency: const LocalLatency.none(),
      scenario: QaScenario.normal,
    ),
  );
  session.onboardingApplication = OnboardingApplication(
    id: 7,
    businessName: 'Tacos Alan',
    status: status,
    notes: notes,
  );
  return session;
}

/// Monta una pantalla como lo hace `main.dart`: reconstruye al cambiar la
/// sesión. Sin animaciones para que las ondas de espera queden estáticas.
Future<void> _mount(
  WidgetTester tester,
  SessionController session,
  Widget Function() screen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: ListenableBuilder(
            listenable: session,
            builder: (context, _) => screen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('pantalla de espera', () {
    testWidgets('limpia: sin logotipo y sin jerga interna', (tester) async {
      final session = _session(status: 'pending');
      await _mount(
        tester,
        session,
        () => OnboardingPendingScreen(session: session),
      );

      expect(find.byType(BrandLockup), findsNothing);
      expect(find.text('Tu restaurante está en revisión'), findsOneWidget);
      expect(
        find.textContaining('el equipo de Tala Eats apruebe el alta'),
        findsOneWidget,
      );
      expect(find.textContaining('ADMIN'), findsNothing);
      expect(find.text('Mientras tanto'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('rechazada sin nota no menciona una nota inexistente',
        (tester) async {
      final session = _session(status: 'rejected');
      await _mount(
        tester,
        session,
        () => OnboardingPendingScreen(session: session),
      );

      expect(find.textContaining('Contacta a soporte'), findsOneWidget);
      expect(find.textContaining('nota de revisión'), findsNothing);
      expect(find.text('Nota de revisión'), findsNothing);
      expect(find.text('Mientras tanto'), findsNothing);
    });

    testWidgets('suspendida con nota la muestra', (tester) async {
      final session = _session(
        status: 'suspended',
        notes: 'Falta la constancia fiscal.',
      );
      await _mount(
        tester,
        session,
        () => OnboardingPendingScreen(session: session),
      );

      expect(
        find.textContaining('suspendida por el equipo de Tala Eats'),
        findsOneWidget,
      );
      expect(find.text('Nota de revisión'), findsOneWidget);
      expect(find.text('Falta la constancia fiscal.'), findsOneWidget);
    });

    testWidgets('«Actualizar estado» informa el resultado de la consulta',
        (tester) async {
      // Pantalla alta para leer el mensaje de estado sin depender de lazy
      // viewport/touch targets; conserva comprobación real del refresh.
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = _session(status: 'pending');
      await _mount(
        tester,
        session,
        () => OnboardingPendingScreen(session: session),
      );

      final button = find.text('Actualizar estado');
      // Es un elemento perezoso de ListView, puede no estar construido aún.
      // scrollUntilVisible busca también widgets más allá del viewport.
      await tester.scrollUntilVisible(
        button,
        180.0,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      await tester.pumpAndSettle();
      await tester.tap(button.hitTestable());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // El texto se inserta DESPUÉS del botón al terminar el refresh y
      // puede quedar fuera del viewport del ListView perezoso. Comprobamos
      // que aparezca realmente tras desplazar la pantalla, no lo simulamos.
      expect(session.approvalRefreshing, isFalse);
      final caption = find.byKey(const ValueKey<String>('pendingCheckedAt'));
      await tester.scrollUntilVisible(
        caption,
        100.0,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 12,
      );
      await tester.pumpAndSettle();
      expect(caption.hitTestable(), findsOneWidget);
      // Sin sesión guardada en el teléfono la consulta falla: lo dice.
      expect(
        tester.widget<Text>(caption).data,
        startsWith('Último intento: '),
      );
    });
  });

  testWidgets('verificación en dos pasos sin logotipo', (tester) async {
    final session = _session(status: 'pending');
    await _mount(
      tester,
      session,
      () => TwoFactorSetupScreen(session: session),
    );

    expect(find.byType(BrandLockup), findsNothing);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.text('Protege tu restaurante'), findsOneWidget);
  });

  testWidgets('la hoja de confirmación muestra un ícono según la acción',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await confirmAction(
                    context,
                    title: '¿Cerrar sesión?',
                    message: 'Tu restaurante seguirá configurado.',
                    confirmLabel: 'Cerrar sesión',
                    destructive: true,
                    icon: Icons.logout_rounded,
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
