# TALA EATS USUARIOS · v1.0.32+43

## Flujo real Android
LaunchScreen (blanco; nombre original naranja/rosa; entrada fade/scale y salida fade)
→ TalaWelcomeScreen (2 fotos fullscreen, alternancia cada seis segundos,
letras TALA EATS en overlay y CTA Continuar translúcido)
→ LoginScreen (Liquid Glass existente)
→ SignUpScreen o recuperación o sesión → CustomerShell.

No se ha agregado autenticación Google, SMS, passkeys ni otras rutas fake.
No cambiar lógica de TalaModel, Stripe, API, permisos ni navegación principal.
El onboarding no se presenta al usuario que ya tiene sesión iniciada.
El modo testMode de TalaEatsApp sigue entrando al Login para no romper tests preexistentes.
Reduce Motion suprime animaciones en el splash y la bienvenida.

## Assets necesarios (locales; no URLs)
Flutter requiere estos archivos dentro de app/assets/landing:
- food_fiesta.webp
- food_tala.webp
- tala_eats_original_wordmark.png

**Bloqueo de entrega:** el repositorio sólo puede incorporar fuentes de texto desde
esta integración; el ZIP adjunto en el chat contiene los 3 binarios originales
optimizados listos para subir con estos nombres. No fusionar hasta incorporarlos;
los fallback de color son exclusivamente defensivos, no reemplazan las fotos.

## Validación
1. Subir las tres imágenes al directorio exacto de esta rama.
2. flutter pub get
3. flutter analyze --no-fatal-infos
4. flutter test
5. flutter build apk --debug
6. Revisar pantalla física 320–430 dp, teclado, navegación atrás, contraste y memoria.
7. Dejar PR en draft hasta CI y QA visual físicos PASS.
