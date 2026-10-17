# TALA EATS Usuarios v1.0.36+47 — Hero sin franja y motion de inicio

## Cambios solicitados (QA Android 17/oct/2026)
1. El degradado oscuro de login/registro/recuperación empezaba debajo del status bar de Android, dejando una tira superior de fotografía clara. Se añadió scrim **solo en el inset de la barra superior** con misma opacidad inicial del hero (`0x59000000`). Mantiene la fotografía original y no oscurece el cuerpo blanco.
2. Pantalla original `assets/branding/tala_intro.png`: movimiento Ken Burns **muy sutil 3.8%**, 3400 ms, una única vez, opacidad 94-100%. Se mantiene la permanencia original de 4 segundos en paralelo a restauración de sesión, sin loaders adicionales.
3. Cambio desde intro a login/tienda: crossfade 620 ms con escala mínima (98.5% a 100%). **Reduce Motion** usa duración 0 con `TalaMotion.of` tanto en intro como en transición. No animación infinita ni pantalla duplicada.

## Pruebas
- `customer_auth_status_bar_hero_test.dart`: inspecciona 28dp de inset en login, registro, recuperación y color apropiado. 
- `customer_login_2fa_branding_test.dart`: imagen original, zoom monotónico no-looping, `Reduce Motion` y sin loaders ni marca inventada.
- CI completo: analyze, full Flutter, Android debug + SHA256.
- Revalidación en dispositivo real: franja negra superior continúa en fotos de login/recuperar, animación perceptible pero discreta, sin tearing en pantalla de entrada, consistencia con teclado.
- No backend, no Stripe, no SMTP, no pagos, no cambios de seguridad, otras apps ni Kali.
