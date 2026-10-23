# TALA EATS — Alineación Flutter para Node RC7 (solo TEST)

**Corte:** 22 de octubre de 2026. Este PR es preventivo, **NO conecta Stripe LIVE**, no activa botones comerciales y no requiere credenciales privadas en las apps.

**Backend de referencia:** [RC7 v5, PR #133](https://github.com/AlanPalacios23/AlanPalacios23-tala-eats-backend/pull/133). El servidor Kali publicado todavía ejecuta RC6; no suponer que los endpoints RC7 existen hasta tener despliegue y E2E confirmados.

## Usuarios

- `production_api.dart` ahora expone `paymentMethods()` (`GET /orders/payment-methods`) y `stripePaymentStatus(id)` (`GET /payments/stripe/orders/:id/status`).
- `stripePaymentIntent(id)` solicita el intento al backend y el monto siempre se calcula del lado del servidor.
- Solo presentar "Pagado" cuando `confirmed_by_server == true`; una pantalla de éxito de PaymentSheet o un `client_secret` NO equivale a fondos capturados.
- La llamada Mercado Pago obsoleta `checkout()` pasa a fallar de forma explícita para que no intente usar un PSP deshabilitado.
- La app todavía requiere integración visual y funcional de PaymentSheet, botones de efectivo/Stripe condicionados a `enabled` y pruebas de regresión antes del lanzamiento.

## Restaurante

- Respuesta Node RC7 `GET /withdrawals/restaurant/:id/balance` tiene `available_for_withdrawal="0.00"`, `provider="not-configured"`, `eligible=false` y `reconciliation_hold=true`, distinta de los campos `withdrawable_cents` de Python.
- El gateway acepta esa forma **solo** como `WithdrawalOverview` con saldo **no verificado**, banco no disponible, `serverAllowsRequests=false`, `reconciling=true`.
- No convierte el valor `0.00` en `WithdrawalBalance`: evita que la pantalla lo presente falsamente como saldo liquidado.
- Respuestas 401/403 y otros errores no se ocultan; la interfaz sigue bloqueando retiros hasta que exista dinero y Stripe Connect auténticamente verificados.

## Repartidor

- Cuando Connect informa `configuration=disabled-node-staging`, no se solicita código TOTP ni se intenta abrir onboarding, se presenta mensaje de no disponibilidad.
- El estado futuro de onboarding **no debe confundirse con payouts aún inactivos**: una cuenta podría estar completando onboarding mientras la transferencia sigue bloqueada. El UI seguirá los flags del backend.
- La función de retiros y el flujo de delivery comercial todavía no están disponibles en RC7.

## No autorizar producción hasta

- Validar la migración/datos de Node, rutas Flutter, restauración y rollback.
- Ejecutar pruebas reales contra **Stripe TEST** incluyendo webhooks firmados, idempotencia, falta de conexión y reembolsos.
- Completar y probar flujo de **efectivo a domicilio** (caja en manos del repartidor) y Stripe Connect Accounts v2 con KYC, saldos disponibles y webhooks.
- Firmar AAB de los tres paquetes con sus claves propias **sin subir keystores a GitHub**, aprobar calidad y publicar mediante Play Console en etapas.
- Mantener `rk_test_/sk_test_`, `whsec_`, `sk_live_/rk_live_` únicamente en servidor o almacén de secretos; nunca en Dart, repos públicos ni artefactos.
