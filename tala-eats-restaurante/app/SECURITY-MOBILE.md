# Seguridad móvil — v0.5.1

- HTTPS productivo por defecto; Android bloquea cleartext traffic.
- `android:allowBackup=false`.
- Bearer token y device token se guardan con `flutter_secure_storage`.
- la instalación genera un `X-Device-ID` aleatorio, persistente y no basado en un identificador de hardware.
- el backend firma `X-Device-Token` y valida su enlace con usuario/dispositivo.
- login soporta OTP de 6 dígitos cuando la cuenta ya tiene 2FA.
- las cuentas de restaurante sin 2FA pasan por setup TOTP antes de operar.
- GET puede reintentarse una vez por error de red; POST/PATCH/DELETE no se reintentan ciegamente.
- los errores técnicos se traducen a `AppFailure` y no se imprimen crudos en UI.
