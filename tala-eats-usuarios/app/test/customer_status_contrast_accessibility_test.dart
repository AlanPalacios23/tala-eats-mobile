import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_users/main.dart';

void main() {
  test('Todos los tokens comunes de texto en badges y avisos alcanzan AA', () {
    final pairs = <(Color, Color)>[
      (kBrand, Colors.white),
      (kBrandDeep, kSoftOrange),
      (kBrandDeep, kSoftPeach),
      (kGreen, kSoftGreen),
      (kGreen, Colors.white),
      (kDanger, kDangerSoft),
      (kInkSoft, kSunken),
      (kMuted, kBackground),
    ];
    for (final (Color foreground, Color background) in pairs) {
      final Color readable = TalaReadableText.against(foreground, background);
      expect(TalaReadableText.contrast(readable, background),
          greaterThanOrEqualTo(4.5),
          reason: 'El texto de un badge o aviso pequeño necesita WCAG AA.');
    }
    expect(kBrand, const Color(0xFFFF5A1F),
        reason: 'El tono original del logotipo no cambia.');
  });

  test('Paletas con contraste suficiente conservan exactamente su color', () {
    expect(TalaReadableText.against(kInk, kSurface), kInk);
    expect(TalaReadableText.against(kBrandDeep, kSurface), kBrandDeep);
  });

  testWidgets('Pill largo 320dp x1.3 se ajusta sin desbordamientos',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: StatusPill(
              label: 'Promoción de comercio auténtica con descripción muy extensa',
              color: kBrandDeep,
              background: kSoftOrange,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final Text text = tester.widget<Text>(find.textContaining('Promoción de comercio'));
    expect(text.softWrap, true);
    expect(text.maxLines, 3);
    expect(TalaReadableText.contrast(text.style!.color!, kSoftOrange),
        greaterThanOrEqualTo(4.5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Avisos de error y éxito tienen contraste y texto legible',
      (WidgetTester tester) async {
    for (final bool danger in <bool>[false, true]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AuthNotice(
            icon: Icons.info_outline_rounded,
            text: danger ? 'No se pudo iniciar sesión.' : 'Cambios guardados.',
            danger: danger,
          ),
        ),
      ));
      await tester.pump();
      final Text label = tester.widget<Text>(
        find.text(danger ? 'No se pudo iniciar sesión.' : 'Cambios guardados.'),
      );
      final Color bg = danger ? kDangerSoft : kSoftGreen;
      expect(TalaReadableText.contrast(label.style!.color!, bg),
          greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
