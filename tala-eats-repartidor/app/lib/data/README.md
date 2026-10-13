# Capa de datos — Repartidor v1.0.7

La app de producción usa `DriverController.production()` y Backend TALA EATS v1.6.0.
Los constructores locales de `DriverController` existen solo para pruebas/widget tests.

Base por defecto: `https://talaeats.alan-palacios-dev.com/api/v1`.
Puede sustituirse en builds controlados con `--dart-define=TALA_EATS_API_BASE=https://.../api/v1`.
Nunca se almacenan contraseñas; JWT/device attestation se guardan con `flutter_secure_storage`.
