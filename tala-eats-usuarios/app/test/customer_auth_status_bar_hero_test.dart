import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  for (final (String title, Widget Function(TalaModel) screen) in
      <(String, Widget Function(TalaModel))>[
    ('login', (TalaModel m) => LoginScreen(model: m)),
    ('recuperar contraseña', (TalaModel m) => ForgotPasswordScreen(model: m)),
    ('crear cuenta', (TalaModel m) => SignUpScreen(model: m)),
  ]) {
    testWidgets('El fondo oscuro del hero cubre la barra de estado: $title',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final TalaModel model = TalaModel();
      await tester.pumpWidget(MaterialApp(
        theme: buildTalaTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 28),
          ),
          child: screen(model),
        ),
      ));
      await tester.pumpAndSettle();
      final scrim = find.byKey(const ValueKey<String>('auth-status-bar-scrim'));
      expect(scrim, findsOneWidget);
      expect(tester.getSize(scrim).height, 28);
      expect(tester.widget<ColoredBox>(scrim).color,
          const Color(0x59000000));
      expect(find.byKey(const ValueKey<String>('auth-hero-title')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('auth-surface')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      model.dispose();
    });
  }
}
