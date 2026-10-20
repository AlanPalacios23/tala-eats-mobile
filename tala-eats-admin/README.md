# Tala Eats ADMIN · Flutter independiente (MVP 0.1.0)

Cuarta app del monorepo, separada de Usuarios / Restaurante / Repartidor y del portal ADMIN web ya existente. Consume exclusivamente el backend compartido de Tala Eats. **No introduce un servidor ni una base de datos nuevos.**

## Funciones V1
- Inicio de sesión con correo, contraseña y TOTP; cierre de sesión remoto.
- Solo cuenta con `role=admin` y `two_factor_enabled=true` entra al panel.
- Alta de TOTP existente en el backend (`/api/v1/v9/security/2fa/setup` + `confirm`) cuando falta configuración.
- Panel con KPIs reales de `GET /admin/stats`.
- Pedidos, usuarios y solicitudes de restaurante/repartidor en modo consulta (50 resultados recientes).
- Decisiones **explícitas y confirmadas** para onboarding, desactivadas por defecto. Solo habilitar en staging revisado con `--dart-define=TALAEATS_ADMIN_WRITES_ENABLED=true`: aprobar, rechazar y pedir información mediante `PATCH /operations/admin/onboarding/{id}`.

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

**Gate de mutaciones:** el APK generado por CI es **solo consulta**. Para probar aprobaciones en STAGING, compilar explícitamente con `--dart-define=TALAEATS_ADMIN_WRITES_ENABLED=true` y revisar la solicitud y documentos desde la consola segura antes de decidir. Nunca activar esta bandera apuntando accidentalmente a LIVE.
