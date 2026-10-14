# TALA EATS Usuarios v1.0.20 — push al dispositivo (Android)

**Estado 14/10/2026:** interfaz, cliente y contrato Firebase Cloud Messaging guardados en PR #11. **SIN deploy, SIN GitHub Actions, SIN compilación ni E2E Android. No afirmar que push ya funciona en producción.**

## Sistema ya existente en backend (confirmado en código fuente)

El backend incluye `backend/app/native_push.py` con:
- `GET /api/v1/mobile-push/config` público (devuelve enabled/provider).
- `PUT /api/v1/mobile-push/devices` autenticado. Body: `token`, `device_id`, `application: "customer"`, `platform: "android"`, `marketing_opt_in`.
- `DELETE /api/v1/mobile-push/devices/{device_id}` autenticado.
- `PUT /api/v1/mobile-push/devices/{device_id}/preferences` autenticado (`marketing_opt_in`).
- Encolado durable desde `models.Notification` por dispositivo, envío FCM HTTP v1 desde worker, tokens cifrados en backend, intentos/reintentos, rechazo de tokens caducados, supresión marketing sin consentimiento.
- Android priority high para mensajes con `order_id` y canal `orders`; canal `promotions` para otros.
- TTL **actual del backend**: aproximadamente **6 horas para mensajes de pedidos**, **24 horas para otros**. Pasado ese tiempo o si el teléfono sigue apagado, puede perderse la alerta. **El buzón dentro de la app sigue consultando mensajes reales del servidor**.

## Fuentes Flutter incluidas

- `lib/push_notifications.dart`: Firebase opcional, solicitud explícita del permiso Android 13+, registro por usuario/dispositivo, rotación FCM, apertura de pedido o buzón al tocar alerta, sincronización de pedidos/buzón con mensajes foreground, baja de token al desactivar/salir, estado real habilitado/no configurado.
- `lib/ui/account_screens.dart`: tarjeta “Avisos en tu celular” con activar/desactivar y control independiente de promociones; no muestra éxito si falta registro.
- `tools/native/MainActivity.java`: canales Android `orders` alta prioridad y `promotions` normal; ID aleatorio UUID por instalación persistido en preferencias de la app, sin IMEI/Android ID.
- `ci/bootstrap_android.py`: permisos `POST_NOTIFICATIONS`, meta-data `com.google.firebase.messaging.default_notification_channel_id=orders` sin editar Android de producción.
- `pubspec.yaml`: `firebase_core` y `firebase_messaging` fijados, pendientes de resolución con `flutter pub get`.
- `test/push_notifications_contract_test.dart`: tests escritos y pendientes de ejecución.

## Configuración FCM necesaria antes de la primera entrega real

1. Crear/elegir un proyecto Firebase en cuenta controlada por TALA EATS y registrar una **app Android con paquete `com.talaeats.app`**. Habilitar FCM HTTP v1. Los valores de configuración de app (project ID, Android app ID, sender ID, API key) son identificadores públicos de cliente; NO son las credenciales de service-account.
2. Para cliente Android pasar por el flujo CI/controlado, sin comprometer datos privados:
   ```
   --dart-define=TALAEATS_FCM_PROJECT_ID=...
   --dart-define=TALAEATS_FCM_ANDROID_APP_ID=...
   --dart-define=TALAEATS_FCM_SENDER_ID=...
   --dart-define=TALAEATS_FCM_API_KEY=...
   ```
   El cliente **no inicializa Firebase** si falta uno. La alternativa estándar es `flutterfire configure` y opciones generadas revisadas para el proyecto. Validar en un Android real que el inicializador de Firebase y FCM pueden obtener token con la configuración de compilación; aplicar ajustes nativos de Gradle/google-services solo si la verificación lo exige.
3. **Solo tras autorización explícita para cambiar Kali**, configurar en backend/worker la cuenta de servicio Firebase en **ruta segura fuera del repositorio** y las variables:
   ```
   NATIVE_PUSH_ENABLED=true
   FCM_PROJECT_ID=...
   FCM_CREDENTIALS_FILE=/ruta/privada/fcm-service-account.json
   FCM_TOKEN_ENCRYPTION_KEY=<clave Fernet generada y protegida>
   ```
   No imprimir la clave ni subir el JSON a GitHub; respetar copias de seguridad y el procedimiento de despliegue existente. Usar un ambiente de ensayo antes de producción.
4. Abrir Notificaciones, permitir `POST_NOTIFICATIONS` en Android 13+, pulsar «Activar avisos de pedidos» y confirmar que el dispositivo se registró con `application=customer`. Promociones por defecto desactivadas a nivel de dispositivo hasta opt-in explícito.
5. Para notificaciones del sistema fuera de la app, el backend **debe emitir una fila `models.Notification` real** para cada transición. Verificar cada transición concreta en E2E; no asumir que todas ya disparan evento/push.

## Pruebas pendientes (hacer en una SOLA ronda cuando el propietario decida compilar)

- `flutter pub get`, `flutter analyze`, `flutter test`, debug APK; verificar que no rompe Stripe ni MapOSM. Comprobar Java y el bootstrap Android 13+.
- Android físico con permiso concedido/denegado, app activa, minimizada, cerrada desde recientes, pantalla bloqueada, Doze, offline y encendido posterior. Forzar cierre desde **Ajustes** exige reabrir la app en Android antes de poder volver a recibir mensajes.
- Confirmación, preparación, repartidor asignado, salida, llegada, cancelación, pago; app abre pedido autorizado o el buzón, no otra cuenta.
- Logout, sesión expirada, cambio de cuenta, varios dispositivos, rotación de token, reinstalación, duplicados, ofertas sin consentimiento, TTL vencido, entrega tras reconexión.
- Comprobar que el backend no envía datos sensibles (dirección, PIN, teléfono, coordenadas) en la vista previa del push.
- Medir worker FCM (enviados/reintentados/expirados) sin guardar tokens/credenciales en logs; probar que canales de **pagos/seguridad** no se asignen incorrectamente a promociones.
- Evaluar deduplicación de avisos y cancelación de pushes obsoletos cuando el pedido ya terminó.

**Sin teléfono encendido/conectado no hay alerta inmediata.** FCM almacena mensajes hasta TTL y trata de entregar al reconectar; no garantiza entrega ni orden. La app sincroniza el historial del backend al abrir.

**Fuentes:** Firebase Cloud Messaging docs, backend actual `backend/app/native_push.py`. No modificar Kali/Stripe sin aprobación.
