# TALA EATS Usuarios v1.0.22 — Push nativo Android / Firebase (opt-in)

## ¿Qué hace esta integración?

- Conecta la app de Usuarios (rol `customer`) con `GET /api/v1/mobile-push/config`, `PUT /api/v1/mobile-push/devices`, `PUT /api/v1/mobile-push/devices/{device_id}/preferences` y `DELETE /api/v1/mobile-push/devices/{device_id}`.
- **Nunca solicita permiso en login de forma automática**. El usuario lo activa desde la pantalla Notificaciones; la autorización se guarda en Android por cuenta. Si se revoca, la app elimina el token FCM local y solicita baja remota.
- Al refrescar FCM token, actualiza el registro de la misma cuenta si la sesión sigue vigente. Los clics en avisos navegan a Pedidos, sin ejecutar acciones ni confiar en ID remotos.
- El dispositivo usa un UUID aleatorio persistente, **no IMEI, identificador de publicidad, dirección GPS ni credenciales de banco**.
- Un push recibido en primer plano solo refresca el buzón de notificaciones legítimas desde el backend, no crea mensajes ficticios.
- Cambiar preferencias de marketing actualiza el flag push solamente si existe registro activo.

## Configuración deliberadamente deshabilitada de fábrica

Requiere ambas condiciones:

1. **Backend en staging (no LIVE) y luego despliegue aprobado en Kali:** `NATIVE_PUSH_ENABLED`, `FCM_PROJECT_ID`, credencial **servidor** de FCM y `FCM_TOKEN_ENCRYPTION_KEY`, gestionadas **solo en el servidor**, jamás en APK o GitHub. El endpoint `mobile-push/config` debe reportar `enabled=true`.
2. **Android Firebase público**: un proyecto Firebase legítimo registrado con application ID `com.talaeats.app`. En el build suministrar parámetros públicos mediante flags `--dart-define`:
   - `TALAEATS_FCM_API_KEY`
   - `TALAEATS_FCM_APP_ID`
   - `TALAEATS_FCM_SENDER_ID`
   - `TALAEATS_FCM_PROJECT_ID`

Si faltan o son falsos, la integración **no registra tokens** ni solicita permiso. No incluir `google-services.json`, claves de servicio FCM, JWT, Stripe LIVE ni cuentas reales en el repositorio. Las opciones públicas Firebase pueden ir empaquetadas en la app una vez configuradas; eso no habilita pagos ni retiros.

## Android

- `firebase_core: 4.15.0`, `firebase_messaging: 16.7.0`; Flutter 3.47.6 y Java 21 en CI.
- `POST_NOTIFICATIONS` en el Manifest generado, requisito en Android 13+.
- La compilación debug del CI **no** suministra parámetros Firebase: prueba la compatibilidad, no certifica entrega efectiva FCM. El SDK permanece inactivo cuando la configuración está ausente.
- Borrado de token local y `DELETE` remoto al desactivar o al cerrar sesión, incluso tras reinicio usando el ID persistido. Si falla la revocación remota, la app nunca afirma que el backend la confirmó.

## QA antes de activar en personas reales

1. Pruebas mock de todos los contratos, token/UUID inválidos, marketing y baja; `flutter analyze`, suite Flutter y `flutter build apk --debug`.
2. En laboratorio autorizado, configurar FCM TEST y backend TEST para comprobar consentimiento denegado/aceptado, recepción en primer plano/segundo plano/cerrada, rotación de token y cambio de cuenta.
3. Verificar expiración, logout offline, Android sin Google Play Services, y que el backend no entrega promociones sin opt-in.
4. No desplegar la configuración de push desde esta PR. Kali, pagos LIVE y otras dos apps permanecen intactos.

## Estado que NO puede declararse listo

- **Sin Firebase público real ni backend push verificado**, no hay entrega push certificada. El buzón `/platform/notifications` sí permanece funcional.
- Firma release, instalación en teléfono y Play Store siguen pendientes de QA físico.
