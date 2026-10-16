# TALA EATS Usuarios — Android v1.0.20 (+31): contratos backend

## Alcance y política de seguridad
- Cambios exclusivamente en `tala-eats-usuarios/` y su CI de Usuarios. Se conservan branding y UX existente.
- `TALAEATS_API_BASE_URL` apunta por defecto a `https://talaeats.alan-palacios-dev.com/api/v1`. CI no hace peticiones a Kali, bancos o proveedores LIVE.
- El código de GitHub del backend v1.6.4 no prueba que Kali tenga esos endpoints. Si un endpoint no está desplegado, la app mostrará un error; nunca simula una sesión revocada, reembolso pagado ni sustitución aceptada.
- La app de Usuarios NO debe exponer endpoints ADMIN, Restaurante, Repartidor, Stripe Connect, retiros bancarios o ajustes financieros administrativos.

## Funciones ya integradas y conservadas

| Área | Contrato backend usado |
| --- | --- |
| Cuenta | `/auth/register`, `/auth/login`, `/auth/me`, `/auth/logout`, `/auth/password/forgot`, `/auth/password/reset` |
| Descubrir | `/restaurants`, `/restaurants/{id}`, `/v9/restaurants/{id}/effective-menu` |
| Preferencias | `/v11/privacy/preferences`, `/v9/privacy` |
| Compra | `/orders/payment-methods`, `POST /orders`, `/orders/mine`, `/orders/by-reference/{client_reference}`, `/orders/{id}/cancel` |
| Pagos | `/payments/stripe/config`, `/payments/stripe/orders/{id}/payment-intent`, `/payments/mercadopago/orders/{id}/checkout` |
| Seguimiento | `/v11/orders/{id}/live`, `/platform/orders/{id}/chat` |
| Cuenta social | `/platform/addresses`, `/platform/favorites`, `/platform/notifications`, `/platform/loyalty`, `/platform/wallet`, `/platform/reviews`, `/platform/support` |

## Integrado en esta PR

1. **Seguridad de cliente:** `GET /auth/devices`, `POST /auth/devices/{id}/revoke` y `POST /auth/devices/revoke-others`. Requiere confirmación humana para cerrar accesos. No permite controlar cuentas ajenas.
2. **Sustituciones del cliente:** `GET /v11/orders/{id}/substitutions`, `POST /v11/orders/{id}/substitutions/{sid}/respond` con acciones explícitamente permitidas. La app NO calcula reembolsos financieros.
3. **Historial de reembolsos:** `GET /v11/orders/{id}/refunds`, mostrando el estado que reporta el backend sin declarar fondos devueltos automáticamente.
4. **Dirección predeterminada:** `PATCH /platform/addresses/{id}` con `is_default` y posterior `GET /platform/addresses`. Al geocodificar ya no se fuerza el municipio de Tala.
5. **Android:** v1.0.20+31; CI analiza, ejecuta suite completa Flutter y compila una APK debug efímera sin publicación.

## Pendientes deliberados (no declarar completados)
- **Mercados** (Tala, Ameca, Ahualulco, Tequila, Cuisillos, Amatitán): contrato backend PR #65 todavía borrador. Hasta merge y rollout autorizado no se usa un filtro remoto no desplegado; continuar con GPS + selección manual y aislamiento de mercado en PR separada.
- **Notificaciones push nativas FCM**: confirmar contrato de token Android y flujo de permiso/posterior logout, no confundir con notificaciones in-app actuales.
- **Sesiones, sustituciones y reembolsos en Kali**: necesitan atestación de versión activa. Los tests en GitHub son mocks de rutas.
- **Pagos reales**: Stripe TEST, Mercado Pago sandbox, cancelaciones, contracargos e idempotencia tras kill/reinicio requieren backend/staging autorizado; no habilitar LIVE por una APK compilada.
- **Android físico**: iniciar sesión, direcciones GPS, historial, FCM, deep links, checkout, cancelaciones, reconexión y recuperación cifrada tras cierre forzoso.
- **APK final**: la compilación debug de CI no equivale a firma release/Play Store. La firma deberá realizarse sin exponer keystore o claves a GitHub.

## Evidencia requerida para aceptación
`flutter analyze --no-fatal-infos`, `flutter test`, smoke tests de los nuevos contratos, compilación nativa Android debug con Flutter 3.47.6, SHA y enlaces CI PASS. Si falla alguno, no fusionar la PR.
