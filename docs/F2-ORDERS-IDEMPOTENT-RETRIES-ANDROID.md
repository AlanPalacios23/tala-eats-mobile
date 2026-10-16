# TALA EATS · Fase 2 · Pedido exactamente una vez desde Usuarios

## Problema auditado

`TalaModel.placeOrder()` generaba cada `client_reference` con la hora
al pulsar «Pedir». Después de un timeout o pérdida de la confirmación
HTTP, el servidor podía haber confirmado la compra y otro toque
asignaba una referencia nueva. Aunque PostgreSQL deduplica correctamente
**la misma referencia por usuario**, no puede asociar referencias distintas.

## Corrección (solo Usuarios)

- `OrderSubmissionGuard` asigna una referencia aleatoria mediante
  `Random.secure` a un checkout y conserva cuerpo/clave ante respuestas
  ambiguas (offline, 408/409/429, 5xx).
- `placeOrder` coalesce toques simultáneos en una sola petición lógica,
  evitando duplicar el pedido en la lista de la app.
- `POST /orders` envía la cabecera `Idempotency-Key` idéntica a la
  `client_reference` del JSON. No se añade a otras rutas.
- Reintentar sin cambiar nada reutiliza exactamente cuerpo y referencia.
  Cambiar el carrito mientras existe respuesta incierta se rechaza;
  se indica revisar «Mis pedidos» antes de seguir.
- Éxito confirmado o rechazo definitivo 400/401/403/404/422 libera la
  referencia. Logout invalida la sesión local y evita insertar respuesta
  tardía de la cuenta anterior.

## QA exigido

Workflow `users-order-contract-qa.yml`: Flutter 3.47.6, analyze y
pruebas sintéticas de doble toque, ACK perdido, cuerpo idéntico,
validación 422, desajuste de carrito, aislamiento de header.
Sin APK, dispositivos, PSP, CI de producción ni pagos.

## Limitaciones para cierre real de F2

**PENDIENTE**: persistir referencia en almacenamiento seguro ante cierre
forzoso/reinicio del proceso, reconciliar un pedido remoto por
`client_reference` o recuperar `orders/mine` de forma confiable,
probar E2E Android instalado y checkout online REAL con Stripe TEST y
Mercado Pago sandbox. El cambio no habilita LIVE, no certifica F2.07,
F2.08 ni cierra las diez tareas principales del issue maestro #43.

Este código es una candidata de PR; no modificar una APK instalada
ni desplegar backend para verificarlo.
