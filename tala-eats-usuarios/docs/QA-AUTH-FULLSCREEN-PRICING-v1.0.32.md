# Tala Eats Usuarios v1.0.32+43 · Correcciones QA Android

## Entradas
- Capturas reales del 17/10/2026: la sesión 2FA ya permite introducir TOTP; fondo gastronómico sólo visible en la parte superior y logotipo de reparto duplicado.
- Imagen adjunta de comida/color para LOGIN ya empaquetada como `assets/branding/login_food.png`.
- Nueva imagen adjunta vertical de madera/comida para REGISTRO, RECUPERAR y CAMBIAR CONTRASEÑA copiada exactamente a `assets/branding/auth_secondary.jpg` (JPEG real aunque el archivo suministrado tenía nombre .png); SHA-256 `16f86aac5a5966c3a3f1235dcaeaecb8a664c9887e648b8153c31297b6feb45c`.

## UI
- Ambos fondos con `Positioned.fill` y `BoxFit.cover`, imagen constante al hacer scroll, velo blanco para contraste. El formulario y el texto de encabezado están centrados; campos y CTA preservados, pantalla scrolleable y accesible con teclado.
- Se elimina el logo/wordmark redundante del login y resto de formularios de autenticación. No se elimina la marca del splash de cuatro segundos.
- Pantallas con imagen secundaria: crear cuenta, confirmar registro, olvidé contraseña, definir nueva contraseña, confirmación de contraseña actualizada y cambio autenticado desde Cuenta.
- Se preserva el paso de TOTP y los dos enlaces navegables de Términos de Uso y Privacidad.

## Backend vigente (GitHub, sólo lectura)
- `backend/app/routes/orders.py`, `GET /orders/payment-methods`, emite `commercial_pricing_version` y `delivery_base_fee`, `service_fee_rate`, `service_fee_cap`, `delivery_included_km`, `delivery_additional_per_km`. Para v1.6.2, el cobro real del envío depende de GPS y de reglas vigentes.
- `RestaurantPublic.delivery_fee` es campo de restaurante, NO cotización vinculante del cliente. Por tanto las tarjetas y detalle de restaurante dicen **«Envío según distancia»** sin afirmar que el envío es gratis ni anunciar $15.
- El desglose de carrito/checkout conserva `Subtotal` del menú efectivo, tasa de servicio de política pública, referencia mínima de envío y total de **referencia**. Texto descriptivo de política genera sus cifras del backend, sin valores hardcodeados $35/2 km/$5 en la app. El pedido definitivo lo calcula el backend cuando crea la orden. No se cambian cobros ni cálculos de servidor.
- No crear falsa cotización en el frontend ni cambiar los precios comerciales del restaurante. No modificar producción Kali, .env, Stripe/MP LIVE, apps Restaurante/Repartidor o ADMIN.

## Gates
- Flutter analyze y suite completa, incluyendo `customer_auth_fullscreen_pricing_test.dart` y `fair_pricing_v162_test.dart`.
- Seguridad Android, compilación debug y SHA-256 del artefacto del HEAD exacto.
- Quedan pendientes pruebas reales 2FA, teclado, visual en dispositivos Android, backend QA y checkout E2E; no marcar esos checks como cerrados.
