import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/core/theme.dart';
import 'package:talaeats_driver/widgets/common.dart';

void main() {
  for (final width in <double>[320, 360]) {
    for (final scale in <double>[1.0, 1.3]) {
      testWidgets('confirmation CTA fits ${width.toInt()}dp x$scale',
          (tester) async {
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = Size(width * 3, 720 * 3);
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          MaterialApp(
            theme: driverTheme(),
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width <= 340 ? Space.l : Space.xl,
                ),
                child: Center(
                  child: PrimaryButton(
                    label: 'Sí, completar entrega',
                    icon: Icons.check_rounded,
                    stackOnNarrow: true,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
