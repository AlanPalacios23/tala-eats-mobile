# Tala Eats ADMIN · Flutter independiente (MVP 0.1.3 (QA Node RC6) en revisión)

Cuarta app del monorepo, separada de Usuarios / Restaurante / Repartidor y del portal ADMIN web ya existente. Consume exclusivamente el backend compartido de Tala Eats. **No introduce un servidor ni una base de datos nuevos.**

## Funciones V1
- Inicio de sesión con correo, contraseña y TOTP; cierre de sesión remoto.
- Solo cuenta con `role=admin` y `two_factor_enabled=true` entra al panel. Además,
el backend exige que la sesión haya validado el OTP al iniciar sesión: no basta con tener 2FA configurado.
- Alta de TOTP existente en el backend (`/api/v1/v9/security/2fa/setup` + `confirm`) cuando falta configuración. Al confirmar se revoca localmente la sesión previa y se solicita un **nuevo inicio de sesión con TOTP**, porque el JWT de alta no contiene `mfa=true`.
- Panel con KPIs reales de `GET /admin/stats`.
- Pedidos, usuarios y solicitudes de restaurante/repartidor en modo consulta (50 resultados recientes).
- Decisiones **explícitas y confirmadas** para onboarding, desactivadas por defecto. Solo habilitar en staging revisado con dos definiciones (flag y URL exacta): aprobar, rechazar y pedir información mediante `PATCH /operations/admin/onboarding/{id}`.

No habilita pagos, reembolsos, cambios de precios, ajustes Wallet, verificación bancaria ni modificaciones del estado de pedidos. Esos flujos requieren QA adicional y nunca deben fingirse operativos.

## Configuración de backend
La app **no tiene URL por defecto** por seguridad. Se compila con:
```bash
cd tala-eats-admin/app
flutter create --platforms=android --project-name talaeats_admin --org com.talaeats .
# Flutter genera un test de ejemplo que busca "MyApp", ausente en ADMIN.
# Bash: rm -f test/widget_test.dart
# Windows PowerShell: Remove-Item test/widget_test.dart -ErrorAction SilentlyContinue
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=TALAEATS_ADMIN_API_BASE_URL=https://SU-GATEWAY-STAGING/api/v1
```
Se permite `http://10.0.2.2` únicamente en builds DEBUG del emulador. En dispositivos reales es obligatorio HTTPS con certificado válido. El release Node RC6 en Kali escucha en loopback 127.0.0.1:18190 y el dominio HTTPS público de Tala Eats se redirigió a él mediante Cloudflare Tunnel (según documentación operativa del 22/oct/2026). No abrir el puerto directamente a Internet.

Backend verificado contra `node-backend/src/app.ts`, `src/auth/routes.ts` y `src/operational/routes.ts` de la rama `feat/node-kali-direct-pm2-release-20261020` (20 oct 2026). Requiere `AUTH_V02_ENABLED=true` y `MARKETPLACE_B_ENABLED=true`, DB de staging migrada, datos de ADMIN de staging y Node operativo. El SHA Node RC6 30ab51b5… se reporta desplegado con migraciones Prisma y TOTP/soporte/archivo. La documentación confirma la ejecución reportada en Kali, pero la lectura de GitHub NO verifica el estado del servidor en este instante.

El inicio de sesión de Node hoy retorna token Bearer para mobile. En Flutter se guarda únicamente usando flutter_secure_storage después de verificar rol+MFA; no se guardan contraseñas, secretos de TOTP o datos de negocio offline. Servidor debe rechazar rol incorrecto o TOTP inactivo. Este repositorio no almacena claves de firma o tokens.

## Publicar APK de pruebas
Desde GitHub, ejecutar manualmente `Actions → Tala Eats ADMIN Android QA → Run workflow` sobre la rama propuesta. CI genera Android, ejecuta analyze/test y compila APK debug. No hay despliegue ni firma para Play Store y no modifica Kali.

**Gate de mutaciones:** el APK generado por CI es **solo consulta**. Para probar aprobaciones
en una API de STAGING revisada, el operador debe fijar **ambas** variables de compilación:
```bash
flutter run \
  --dart-define=TALAEATS_ADMIN_API_BASE_URL=https://TU-STAGING-ADMIN/api/v1 \
  --dart-define=TALAEATS_ADMIN_WRITES_ENABLED=true \
  --dart-define=TALAEATS_ADMIN_WRITE_API_BASE_URL=https://TU-STAGING-ADMIN/api/v1
```
Solo funciona en compilaciones **DEBUG** para QA; los builds release permanecen en modo consulta.
Las dos URLs deben coincidir **exactamente** y utilizar HTTPS. No basta con activar el
booleano; todo destino distinto queda en modo consulta. Esta barrera cliente no sustituye
la autorización ADMIN + TOTP, validación transaccional y auditoría del servidor. Revisar
solicitud/documentos antes de aprobar, y no compilar el modo de escrituras contra LIVE.

## Soporte y restaurantes (extensión del MVP)
- El cliente de Usuarios ya genera tickets mediante `POST /platform/support`.
- La bandeja Soporte llama `GET /admin/support` y presenta cliente, correo, pedido, texto y estado. La respuesta requiere confirmación y se guarda en `PATCH /admin/support/{id}`; el backend la envía a notificaciones del cliente y la devuelve en `GET /platform/support`.
- Restaurantes consulta `GET /admin/restaurants`, permite **suspender** un comercio y **archivar** uno cerrado sin pedidos activos; jamás se borran pedidos o registros financieros. El backend lo excluye del catálogo y bloquea operaciones de propietario.
- Todas las mutaciones requieren `TALAEATS_ADMIN_WRITES_ENABLED=true` y `TALAEATS_ADMIN_WRITE_API_BASE_URL` apuntando a la misma URL exacta HTTPS del build de staging. Las APK estándar y GitHub CI son de solo lectura.
- La respuesta de soporte requiere la migración aditiva `20261020_admin_helpdesk_reply` en la DB aislada Node. Nunca aplicarla a producción Python sin plan de promoción.

## Auditoría de integración · 22 de octubre de 2026

- El código ADMIN original está en [Mobile PR #48](https://github.com/AlanPalacios23/tala-eats-mobile/pull/48).
- Su dependencia Node MFA + tickets + archivo está en [Backend PR #109](https://github.com/AlanPalacios23/AlanPalacios23-tala-eats-backend/pull/109); **no está en `main` y no acredita desplegado en Kali**.
- El cliente Usuarios de PR #48 tiene envío/listado de tickets propios y respuesta del ADMIN; Restaurante/Repartidor siguen siendo apps independientes y no se modifican en esta mejora.
- Se rechazan redirecciones HTTP al invocar endpoints sensibles, para evitar el reenvío de Bearer a un origen ajeno.
- Frente a 401/403 se borra sesión y caché del panel; ante error de red se vacía la pestaña para no presentar métricas antiguas como actuales.
- Un CI de PR comprueba análisis estático, tests read-only, tests de escrituras solo sobre host sintético de staging y APK debug sin credenciales.
- **Pendiente para GO**: pruebas reales PostgreSQL/Redis aislados con PR #109, migración revisada, flujo completo de tickets y archivo, verificación de gateway administrativo y APK en dispositivo físico. No publicar ni mezclar a la línea de Play de Usuarios sin pasar esos controles.


## v0.1.2: Crear cuenta y APK de QA con API preconfigurada (22-oct-2026)

- Pantalla **Crear cuenta** independiente del formulario de inicio de sesión. Solicita nombre, correo, contraseña y confirmación; usa `POST /auth/register` del backend compartido.
- **Seguridad:** la ruta solo crea `role=customer`. Ni el formulario ni el backend promueven automáticamente a ADMIN. Si el servidor entrega un token temporal de registro, el cliente intenta revocarlo con `POST /auth/logout` y siempre lo descarta. Para usar el panel se necesita alta/promoción autorizada fuera de este formulario y TOTP obligatorio.
- Botón **Probar conexión al backend**: consulta `GET /health` sin autenticación y distingue Node staging de otras APIs cuyo contrato administrativo aún no se comprobó.
- APK debug de GitHub Actions: se compila con `TALAEATS_ADMIN_API_BASE_URL=https://talaeats.alan-palacios-dev.com/api/v1` (dominio previamente documentado para la API compartida). **La dirección se incluye en el build, pero no equivale a conexión real validada desde GitHub/ChatGPT.** Si sigue sirviendo Python, las funciones Node de los PR #109 seguirán faltando y el APK indicará error real, no simulará respuestas.
- **Solo QA, sin escrituras ADMIN:** el flag de mutaciones queda en `false`, ningún `--dart-define` ni secreto productivo se sube a GitHub; es un APK debug, **no** una versión firmada release de Play.
- Requisitos para funcionalidad administrativa completa: exponer el Node staging con gateway HTTPS ADMIN de acceso restringido tras superar sus preflight, cambiar la URL del build al gateway real y ejecutar E2E role/MFA/soporte/archivo con base de staging.


## 0.1.3: APK debug para QA de ADMIN operativo (22 octubre 2026)

- El operador reportó en GitHub Node RC6 público en `https://talaeats.alan-palacios-dev.com/api/v1`, SHA servidor `30ab51b587b21127c3f3419e0ec4c3a8539dfb0a` con soporte y archivado de comercios. **NO** está listo para transacciones comerciales (`productionReady=false`).
- GitHub Actions construye **solo DEBUG** v0.1.3 con `TALAEATS_ADMIN_API_BASE_URL`, `TALAEATS_ADMIN_WRITES_ENABLED=true` y `TALAEATS_ADMIN_WRITE_API_BASE_URL` fijadas **exactamente** al dominio HTTPS indicado. Las mutaciones siguen denegadas en release, contra URLs distintas, sin rol ADMIN o sin MFA verificada. Esta versión solo se distribuye al propietario para QA, no a Play Store.
- El usuario puede registrarse mediante `POST /auth/register`, pero adquiere exclusivamente el rol `customer`. La promoción controlada se realiza **desde Kali** contra la DB de STAGING Node con auditoría y revocación de sesiones; nunca incluirla como un endpoint público ni hacer que el registro conceda admin.
- Flujo de primera activación: registrar cuenta -> promover por operador local -> iniciar sesión sin OTP -> configurar TOTP -> cerrar sesión temporal -> nuevo inicio con TOTP -> leer estadísticas -> probar soporte/archivo con datos de ensayo.
- La promoción de rol NO implica que este PR, por sí mismo, haya modificado base de datos o activado un usuario real; requiere ejecución interactiva local en Kali.
- No se cambian Python legado, Stripe LIVE, datos, DB, túneles o servidores. No registrar claves, correos particulares, contraseñas ni tokens en commits o logs.
