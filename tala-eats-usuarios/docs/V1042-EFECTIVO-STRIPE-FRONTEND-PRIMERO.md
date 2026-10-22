# TALA EATS Usuarios v1.0.42+53 — Efectivo y Stripe, UI primero

**Alcance:** aplicación Usuarios Flutter. No se modifican backend Node.js/Python,
servidor Kali, Stripe LIVE, llaves, credenciales, portal Admin ni otras apps.

## Cambio funcional
- En `Finalizar pedido → Pago` aparecen **siempre** dos tarjetas:
  **Efectivo** y **Tarjeta con Stripe**.
- La tarjeta desactivada muestra **Pendiente de activación** con un candado;
  carece de `onTap`, está marcada como deshabilitada para accesibilidad y
  no altera `paymentMethod`.
- `GET /orders/payment-methods` sigue siendo la fuente de verdad para habilitar
  cualquiera de las tarjetas. Si el endpoint no responde, ambas quedan bloqueadas.
- `Efectivo` requiere `methods[{id: cash, enabled: true}]`.
  `Stripe` requiere `methods[{id: stripe, enabled: true}]`.
- Si ambos están deshabilitados, no se envía `POST /orders`, no se inicia
  Stripe PaymentSheet, y el CTA es **Revisar métodos de pago**.
- Incluso con una opción habilitada, antes de emitir `POST /orders` se vuelve
  a verificar la capacidad. **Nunca** convertir Stripe en efectivo silenciosamente.
- El backend continúa siendo autoridad de total, comisión, envío, estatus
  de pago y confirmación tras webhook. `Mercado Pago` no aparece para nuevas órdenes.

## Para activar posteriormente en backend Node.js (NO hecho aquí)
1. Validar en staging `GET /orders/payment-methods` y sus campos `id, enabled`.
2. Efectivo: reglas de `POST /orders`, cobro contra entrega/recogida y
   estados consistentes para Restaurante/Repartidor.
3. Stripe: `GET /payments/stripe/config`,
   `POST /payments/stripe/orders/{id}/payment-intent`, PaymentSheet, webhooks
   verificados, idempotencia y reconciliación usando **Stripe TEST**.
4. Probar pago exitoso, rechazo, cancelación, conexión perdida,
   doble toque, reintentos, cambios de método y sesiones.
5. Después de pruebas aisladas, autorizar activación del servidor; la app
   lee las capacidades dinámicamente. **No** almacenar `sk_live`, API secrets,
   claves de firma ni `.env` en GitHub.

## Estado y lanzamiento
- Base: v1.0.41+52, instalada por pruebas internas en Google Play.
- Nueva candidata: **v1.0.42+53** para una actualización futura.
- Solo se ha preparado código en rama de PR; **no** se ha firmado,
  entregado ni publicado un nuevo AAB.
- GitHub Actions comprueba código y Android debug, pero no reemplaza la
  aceptación de Play Console ni los ensayos E2E en Android real.
