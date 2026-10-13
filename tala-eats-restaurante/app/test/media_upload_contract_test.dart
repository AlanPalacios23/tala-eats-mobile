import 'package:flutter_test/flutter_test.dart';
import 'package:talaeats_restaurant/core/failures.dart';
import 'package:talaeats_restaurant/data/remote/remote_api.dart';

void main() {
  test('mapea firmas JPG PNG WEBP y PDF al MIME del backend', () {
    final jpg = detectUploadMediaHeader([0xFF, 0xD8, 0xFF, 0xE0]);
    final png = detectUploadMediaHeader([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);
    final webp = detectUploadMediaHeader('RIFF1234WEBP'.codeUnits);
    final pdf = detectUploadMediaHeader('%PDF-1.7'.codeUnits);

    expect(jpg.contentType.toString(), 'image/jpeg');
    expect(jpg.extension, '.jpg');
    expect(png.contentType.toString(), 'image/png');
    expect(png.extension, '.png');
    expect(webp.contentType.toString(), 'image/webp');
    expect(webp.extension, '.webp');
    expect(pdf.contentType.toString(), 'application/pdf');
    expect(pdf.extension, '.pdf');
  });

  test('rechaza HEIC/AVIF antes de llegar al servidor', () {
    expect(
      () => detectUploadMediaHeader([0,0,0,24,102,116,121,112,104,101,105,99]),
      throwsA(isA<AppFailure>()),
    );
  });
}
