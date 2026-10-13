import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_driver/widgets/brand.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official Tala Eats logo asset is the exact approved source', () async {
    final data = await rootBundle.load(kTalaEatsLogoAsset);
    // Byte size + dimensions are pinned to the approved official source.
    // Replacing it with the old orange T or another reinterpretation fails.
    expect(data.lengthInBytes, 165998);

    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 418);
    expect(frame.image.height, 418);
    frame.image.dispose();
    codec.dispose();
  });

  test('Android generator forces official launcher and native splash', () {
    final script = File('tools/generar_android_compatible.ps1').readAsStringSync();
    expect(script, contains('ic_launcher_round.png'));
    expect(script, contains('mipmap-anydpi-v26'));
    expect(script, contains('tala_eats_splash.png'));
    expect(script, contains('android:windowSplashScreenAnimatedIcon'));

    // INSTALAR.cmd genera Android antes de ejecutar este test. Si Android ya
    // existe, verificamos el resultado real del generador, no solo su código.
    final android = Directory('android');
    if (android.existsSync()) {
      for (final density in <String>[
        'mipmap-mdpi',
        'mipmap-hdpi',
        'mipmap-xhdpi',
        'mipmap-xxhdpi',
        'mipmap-xxxhdpi',
      ]) {
        expect(
          File('android/app/src/main/res/$density/ic_launcher.png').existsSync(),
          isTrue,
        );
        expect(
          File('android/app/src/main/res/$density/ic_launcher_round.png')
              .existsSync(),
          isTrue,
        );
      }
      expect(
        File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
            .existsSync(),
        isFalse,
      );
      expect(
        File('android/app/src/main/res/drawable/tala_eats_splash.png')
            .existsSync(),
        isTrue,
      );
      final v31 = File('android/app/src/main/res/values-v31/styles.xml');
      if (v31.existsSync()) {
        expect(
          v31.readAsStringSync(),
          contains('@drawable/tala_eats_splash'),
        );
      }
    }
  });
}
