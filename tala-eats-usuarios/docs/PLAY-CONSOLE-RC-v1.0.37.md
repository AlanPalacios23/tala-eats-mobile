# Tala Eats Usuarios v1.0.37+48 — Release candidate, NO PUBLICAR AÚN

Base: PR #38 v1.0.36. Solo app `tala-eats-usuarios/app` (`com.talaeats.app`).
Mantener Restaurante, Repartidor, ADMIN, Kali, base de datos y Stripe LIVE intactos.
No confundir 28 checks CI debug con aprobación en dispositivo.

## 1. Firebase FCM Android: falta aprovisionamiento REAL
El código Flutter (`CustomerNativePush`) ya registra dispositivos **solo con consentimiento**; backend tiene FCM HTTP v1, cola y worker. Sin valores reales ambos permanecen OFF.

1. Crear o seleccionar un proyecto Firebase propio de Tala Eats. Registrar exactamente una app **Android** con package `com.talaeats.app`. En la consola obtener cuatro valores públicos: API key de Firebase, Firebase App ID Android, Sender ID numérico y Project ID.
2. En el equipo local (no en GitHub) configurar variables `TALAEATS_FCM_API_KEY`, `TALAEATS_FCM_APP_ID`, `TALAEATS_FCM_SENDER_ID`, `TALAEATS_FCM_PROJECT_ID`. El AAB release exige las cuatro; *no* colocar JSON de service account en la app.
3. En **backend de staging** y con autorización separada configurar por secreto privado `FCM_CREDENTIALS_FILE` apuntando a credencial de cuenta de servicio con permiso mínimo FCM HTTP v1, `FCM_PROJECT_ID` mismo ID, `FCM_TOKEN_ENCRYPTION_KEY` válido y `NATIVE_PUSH_ENABLED=true`. El servidor devuelve `/mobile-push/config` con `project_id` público. La app valida igualdad exacta antes de registrar tokens. Nunca comitear ni pegar aquí credenciales privadas.
4. Probar desde un dispositivo QA consentido: denegación/permisos, token FCM, refresh, foreground/background/cerrada, logout/baja de token y cambio de usuario, notificación de pedido sin datos cruzados y promos solo por opt-in. Backend debe generar `Notification` real y worker enviarla; recepción efectiva es obligatorio para marcar PASS.

**Bloqueo:** faltan opciones Firebase y configuración REAL del backend, no se afirma activación.

## 2. Recuperación contraseña por correo — backend #68
Ya existen `POST /auth/password/forgot`, token seguro, enlace web/deep link y outbox con trabajador SMTP. Respuesta 202 **no prueba envío**.

En operador autorizado y contenedor de backend: ejecutar SOLO lectura
`python scripts/release_delivery_readiness.py --with-db` (PR de backend requerida), sin escribir ni mostrar claves. Revisar **solo** flags de configuración, conteos pending/retry/sent y reintentos máximos. Confirmar ejecución del worker con heartbeat existente; revisar SMTP_HOST, PORT, TLS/SSL, credenciales y FROM válidos, FRONTEND_URL HTTPS. Provisionar proveedor SMTP transaccional en staging con remitente verificado, SPF/DKIM/DMARC, y probar recepción real en buzón QA propio. Verificar reset de contraseña y revocación de sesiones; texto neutro para cuenta inexistente. Nunca mostrar tokens ni URLs del email de recuperación.

**Bloqueo:** no hay prueba SMTP ni entrega verificada; NO desplegar datos reales hasta aprobación separada.

## 3. E2E pedido completo (solo en staging / Stripe TEST)
- [ ] Cliente QA inicia sesión, recibe catálogo real y abre restaurante con imágenes.
- [ ] Dos productos, decremento, carrito flotante, stock y precio coinciden.
- [ ] Entrega: GPS / localidad y elegibilidad; envío y tarifa servicio calculados **solo por backend**. Probar también recogida sin enviar repartidor.
- [ ] Efectivo permitido: pedido registrado exactamente una vez; confirmar tienda y seguimiento. No dinero real.
- [ ] Stripe TEST: `PaymentSheet` visible, cancelar, reintentar y luego pagar usando tarjeta de prueba oficial; eventos `payment_intent.succeeded` validados por firma en webhook; backend pasa `payment_status=paid`, UI se actualiza sola. No usar tarjeta real.
- [ ] Doble tap / timeout tras POST pedidos + reinicio del móvil: **no duplicar** y recuperar `client_reference` / journal.
- [ ] Restaurante QA acepta y prepara; Repartidor QA recibe, recoge, completa con evidencia/PIN simulada; mismas cantidades, IDs y estados para las tres apps.
- [ ] Cancelación por falta de pago o expiración reestablece inventario, sin marcar pagado localmente; idempotencia de webhook.
- [ ] Wi-Fi→sin conexión→datos, regreso desde Stripe, retención de imagen, sin ver pedido ajeno.
- [ ] Verificar roles, logs sanitizados, no revelar tarjeta/datos personales.
- [ ] Guardar capturas con IDs ficticios y resultados; no marcar E2E aprobado por CI de mocks.

## 4. Clave de subida y Play Signing (sin secretos en GitHub)
Ya tienes Play Console, pero aún no existe una upload key. Generarla **en tu propio equipo** con Java `keytool`, contraseña larga, alias único, archivo y respaldo cifrados **fuera de este repositorio**. Ejemplo interactivo PowerShell Windows (NO incluir contraseña en el comando):

```powershell
# Directorio PRIVADO fuera de GitHub, respaldarlo cifrado en otro medio.
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\TalaEats-Keys" | Out-Null
keytool -genkeypair -v -keystore "$env:USERPROFILE\TalaEats-Keys\talaeats-upload.jks" -storetype JKS -keyalg RSA -keysize 3072 -validity 10000 -alias talaeats-upload
```

En esa sesión local definir (NO pegarlas en ChatGPT, Issues o Actions):
`TALAEATS_UPLOAD_KEYSTORE`, `TALAEATS_UPLOAD_STORE_PASSWORD`,
`TALAEATS_UPLOAD_KEY_ALIAS`, `TALAEATS_UPLOAD_KEY_PASSWORD`.
Definir además cuatro variables públicas Firebase. En repo local:

```sh
cd tala-eats-usuarios
python ci/build_signed_play_bundle.py --check
python ci/build_signed_play_bundle.py --build
```

El script crea scaffold Android cuando falta, exige package `com.talaeats.app`, `compileSdk = targetSdk = 36`, no permite firmar con DEBUG, compila `flutter build appbundle --release` firmado con keystore fuera del repo y verifica firma usando `jarsigner`. Entrega local esperada `app/build/app/outputs/bundle/release/app-release.aab`, SHA256 en consola; **no sube nada a Play**. Si no existen las claves o Firebase válido, ABORTA. Habilitar Play App Signing en Console, registrar certificado upload. Nunca volver a cambiar el package/applicationId.

## 5. QA adicional de Play Console
- [ ] Compatibilidad real API 36 Android 16; verificar SDKs/NDK de terceros y 16 KB páginas en AAB con bundletool/Play Console.
- [ ] Enlaces de privacidad, condiciones y **eliminación de cuenta por web** pública real, además del botón en app; no basta registrar solicitudes que nadie ejecuta.
- [ ] Publicar política legal verificable HTTPS y completar Play Data Safety, ubicación, notificaciones, cifrado, pagos externos, fotos y retención.
- [ ] Ícono original, nombre, descripción, screenshots no sintéticos de Android, cuenta QA accesible y respuestas de revisión.
- [ ] Subir AAB primero a **Pruebas internas**, ejecutar Play pre-launch report, luego pruebas cerradas si Console lo exige, y después de gates E2E pedir aprobación para producción.
- [ ] Mantener Tala como piloto. No anunciar comercios/localidades sin cobertura.

## Estado 
Código de gate release preparado pero **AAB firmado aún NO generado**. SMTP/FCM y pedidos E2E requieren configuración de entorno de pruebas y datos suministrados por propietario. No merge/deploy ni LIVE sin autorización.
