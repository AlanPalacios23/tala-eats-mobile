# Tala Eats ADMIN · Flutter independiente (MVP 0.1.1 en revisión)

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
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=TALAEATS_ADMIN_API_BASE_URL=https://SU-GATEWAY-STAGING/api/v1
```
Se permite `http://10.0.2.2` únicamente en builds DEBUG del emulador. En dispositivos reales es obligatorio HTTPS con certificado válido. El Node actual se publica solo en loopback de Kali y **no** se debe abrir a Internet sin un gateway administrativo autenticado/seguro.

Backend verificado contra `node-backend/src/app.ts`, `src/auth/routes.ts` y `src/operational/routes.ts` de la rama `feat/node-kali-direct-pm2-release-20261020` (20 oct 2026). Requiere `AUTH_V02_ENABLED=true` y `MARKETPLACE_B_ENABLED=true`, DB de staging migrada, datos de ADMIN de staging y Node operativo. La existencia del endpoint no confirma un despliegue en Kali ni pruebas E2E.

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
