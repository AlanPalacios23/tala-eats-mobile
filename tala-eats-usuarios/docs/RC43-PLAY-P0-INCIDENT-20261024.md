# TALA EATS Usuarios — P0 tras la primera AAB de Play (24 oct 2026)

**Estado: DRAFT / NO publicar una nueva AAB.** El propietario confirmó que la primera AAB firmada ya está en Play Console. El versionCode real de esa carga debe verificarse allí antes de incrementar versión.

## Evidencia en seis capturas de Android
- Splash: barra de progreso innecesaria debajo de «Pide, disfruta y repite».
- Tala Club: mensaje HTTP 5xx/servidor no disponible, saldo visual $0 y «Sin movimientos» no verificables.
- Carrito/Checkout: tarifas y total «Por confirmar»; el servidor no facilita precio final de envío basado en recorrido.
- Checkout Stripe: «Existe un pedido sin confirmar» al reintentar con cesta distinta: journal cifrado de idempotencia.
- FCM: Firebase de la app dado de alta, pero entrega end-to-end no certificada.

## Cambios móvil de este PR
1. Barra inferior retirada del splash. Branding y transición existentes conservados.
2. Wallet/notifications fallan independientemente del catálogo principal. Tala Club enseña «Sin verificar» y «Movimientos no disponibles», en vez de inventar cero al fallar el GET.
3. Detección de `delivery_checkout_supported=false` o modos de pago `*-pickup`: se bloquea DELIVERY antes de POST /orders, se muestra explicación y se permite elegir Recoger. No hay cobros ni estimaciones falsas.
4. Recuperación opcional por GET `/orders/by-reference/{reference}`: si el servidor identifica pedido y cuenta, se muestra el pedido existente. Ante 404/5xx se conserva journal cifrado. **Nunca reintentar automáticamente un nuevo POST ni eliminar journal de una compra ambigua.**
5. Tests de splash, degradación parcial de Wallet y Node pickup-only.

## Backend Node RC8.6 — estado real, no supuestos
- Código de órdenes actual acepta sólo pickup con efectivo/Stripe bajo flags y auditorías financieras, no entrega a domicilio. El archivo `node-backend/src/marketplace/checkout.ts` lo declara explícitamente.
- El motor `finance/pricing.ts` calcula *referencias*:
  - Política 1.6.2: servicio 7% sobre mercancía neta, máximo MXN $25; envío MXN $35 hasta 2 km, más MXN $5 por km adicional.
  - Política 1.5.2: servicio 7%; envío base MXN $39.
- **No hay cotización firme de ruta a domicilio** ni orden de DELIVERY comercial implementada en Node. Nunca mostrar un total definitivo ni habilitar Stripe para delivery hasta que el backend calcule distancia autorizada, promociones y total y acepte ese tipo de orden.
- PR Node separado publica en `/orders/payment-methods` tasas de referencia y el soporte pickup-only, sin permitir cobros ni aplicar migraciones.
- Para cotización comercial real falta endpoint de cotización autenticado, con lat/lng validadas, comercio/menú/stock vigente, distancia de ruta calculada del lado servidor, tarifa efectiva, cupones/Plus, caducidad y revalidación atómica al crear la orden.

## Diagnóstico de conectividad SOLO GET (sin tokens)
Desde el Kali o equipo que tiene acceso, consultar:
```bash
curl -i --max-time 10 https://talaeats.alan-palacios-dev.com/api/v1/health
curl -i --max-time 10 https://talaeats.alan-palacios-dev.com/api/v1/ready
curl -i --max-time 10 https://talaeats.alan-palacios-dev.com/api/v1/mobile-push/config
```
Alternativa ya existente: `python3 tala-eats-usuarios/ci/live_readonly_contract_probe.py`. Un status 503 puede ser origen, Cloudflare o base de datos; el código Flutter no puede reparar PM2/Postgres/Cloudflared remotamente.

## FCM Android — puertas de activación
- Flutter ya implementa solicitud de permisos Android, consentimiento por usuario, token rotativo, listeners y pantalla de notificaciones.
- La firma local de AAB exige `TALAEATS_FCM_API_KEY`, `TALAEATS_FCM_APP_ID`, `TALAEATS_FCM_SENDER_ID` y `TALAEATS_FCM_PROJECT_ID` sin guardar secretos de firma en GitHub.
- El backend Node RC8.6 inspeccionado no monta `/mobile-push/config` ni las rutas `PUT/DELETE /mobile-push/devices` ni demuestra un worker FCM de órdenes. Una aplicación registrada en Firebase **no activa** automáticamente esos servicios.
- Para activar: credencial FCM servidor protegida fuera de GitHub, proyecto Android idéntico al de la app, almacenamiento cifrado de tokens/revocación por usuario, control de marketing, entrega de alertas desde eventos *confirmados* de órdenes, pruebas con dos cuentas y dispositivos reales, logout/revocación y Play Data Safety. No insertar claves de servicio en Flutter ni en este repositorio.

## QA pendiente antes de una nueva AAB
- Ejecutar manualmente `Tala Eats | Usuarios QA y APK (solo manual)` sobre SHA exacto: `flutter analyze`, `flutter test`, APK debug.
- E2E Node staging: catálogos/Wallet, pickup cash, Stripe TEST, timeout/reintento con mismo client_reference, pago cancelado, 404/503 al recuperar y permisos de cuenta.
- FCM: proyecto/config, token físico y alerta real tras evento orden; pruebas cuenta separada y logout.
- Validación device 320/360/390/430 dp, Android 16 y compatibilidad 16 KB.
- Revalidar SHA y recursos HD originales, versión mayor a la AAB de Play, firmar localmente y **solo entonces** enviar actualización.

Este documento no certifica conexión al servidor, cargos, envío GPS, webhook, despliegue o aprobación Play.
