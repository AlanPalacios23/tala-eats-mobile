# TALA EATS · Fase 2 · Recuperación de pedido después de cerrar Android

## Garantía propuesta (solo después de instalar una APK compilada)

Al confirmar checkout, Usuarios genera una `client_reference` opaca
y ejecuta `writePendingOrder(userId, reference)` **antes** de cada
`POST /orders`. Android la almacena con **AES-256-GCM y clave Android
Keystore**, en preferencias privadas, usando `commit()` síncrono.
Nunca guarda carrito, número de tarjeta, dirección ni otro dato del
pedido en ese registro. Si el guardado falla, no se inicia la petición.

En reintentos mientras la app sigue abierta, reutiliza clave y cuerpo.
Si se cerró y abrió después de un timeout, recupera del Keystore
la referencia ligada al usuario y realiza únicamente
`GET /api/v1/orders/by-reference/{client_reference}` al backend.

- Si la respuesta existe, coincide con el usuario autenticado y la
  referencia, añade el pedido recuperado a «Mis pedidos» sin duplicarlo
  y elimina el registro cifrado.
- Si devuelve 404, 5xx, red caída, referencia ajena o respuesta inválida,
  **no elimina el registro** ni crea una compra nueva: indica revisar
  «Mis pedidos» o contactar a soporte. Un 404 no es evidencia de que
  la petición anterior jamás se confirmó.
- Una sesión cerrada limpia token + registro pendiente. La validación
  de generación de sesión bloquea respuestas tardías.
- En la sesión original, errores terminales 400/401/403/404/422 liberan
  el intento; timeout/408/409/429/5xx mantienen la referencia.
- No invoca Stripe, Mercado Pago, payout, devolución ni nuevo
  checkout al resolver una compra de un proceso anterior.

## QA

`flutter analyze --no-fatal-infos` y
`test/pending_checkout_recovery_test.dart` (además del gate previo).
Los tests simulan guardado antes de POST, error de almacenamiento, cierre
después de COMMIT sin ACK, GET válido, 404/offline, propiedad de cuenta,
respuesta adulterada, doble toque/reintento y cambio de sesión.

**Importante:** CI de Flutter comprueba el código Dart, pero **no**
compila el Java nativo a un APK Android, ni verifica un Keystore real.
Antes del check final P0 se debe regenerar el scaffold Android con
`tools/native/MainActivity.java`, compilar una APK con Flutter
3.47.6, ejecutar pruebas de dispositivo físico con reinicio/cierre
forzado y comprobar en staging que el backend desplegado incluye
`GET /orders/by-reference` (PR backend #64).

Sin esto, se puede cerrar solo el **subcontrol técnico de fuente y QA
sintético**, no la prueba real de instalación/recuperación ni F2.07 de
Stripe TEST/MP sandbox. No desplegar backend en Kali ni habilitar pagos
LIVE por este cambio. El repositorio privado móvil permanece aislado.
