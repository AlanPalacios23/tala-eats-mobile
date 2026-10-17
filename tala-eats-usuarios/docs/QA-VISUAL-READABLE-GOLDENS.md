# TALA EATS Usuarios · Visual QA Roboto & Material icons

## Why this QA hotfix is necessary

The 9 synthetic reference PNGs from v1.0.28 rendered text as black rectangles and icons as missing-glyph boxes. This is the default Ahem/FlutterTest behavior in Flutter widget tests, **not the real Android UI**. The images were valid for basic layout size assertions but were unsuitable for reviewing visual hierarchy, text, iconography or polish. They are NOT Android screenshots.

This change makes the existing optional golden-capture test explicitly load Google's open-source **Roboto** font and the **MaterialIcons** glyph font. In CI, Roboto is fetched from google/fonts and MaterialIcons is located in the Flutter 3.47.6 SDK. Both are used only for the test run; **neither font is committed to the app or published to the user**. Missing font files or corrupt assets fail the capture test instead of silently rendering Ahem.

## Evidence and acceptance

- The capture continues to use only synthetic restaurants, customer, orders and money. Absolutely no call to a live payment or customer endpoint.
- Nine images: 7 screens at 390×844dp plus Home and Buscar at 320×844dp (1.3 text), now using legible glyphs for QA. The zip artifact is named talaeats-usuarios-v1029-capturas-roboto-legibles (7-day retention). No APK artifact.
- Manually inspect extracted images for text readability, icon visibility, text truncation, overlaps, page hierarchy, bottom CTA and need for further cleanup before certifying **synthetic** screenshot review.
- CI retains all existing Flutter functional tests including keyboard simulation and Reduce Motion, Android secret/manifest gate, and debug compile. No production changes; v1.0.28 app version remains unchanged.

## Not certified

Even legible golden captures on Linux do not certify Android font rasterization, native IME, actual merchant photos, GPS, Stripe TEST, push, or actual phone screenshots. Leave physical QA tasks open. Ameca market isolation and FCM remain backend-dependent.
