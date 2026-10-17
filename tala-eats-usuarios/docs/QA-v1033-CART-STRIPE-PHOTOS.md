# QA v1.0.33+44 · 17 octubre 2026

Contexto: capturas reales Android Usuarios v1.0.32+43 tras QA de login y pricing.

## Cambios en Mobile
- Restaurante: **Para recoger** alineado a la derecha de **Envío según distancia** en **una misma fila**, evitando overflow incluso a 320 dp (el texto de envío puede ocupar 2 líneas dentro de su mitad de fila).
- Carrito: FloatingActionButton visible en todas las secciones principales si contiene artículos, con número y subtotal; el restaurante conserva su barra inferior.
- Ficha: al abrir artículo existente utiliza la cantidad del carrito, no siempre 1. Actualizar sustituye esa cantidad en vez de sumar duplicados; el botón - permite reducir a 0 y retirar artículo. Los cargos del backend no cambian.
- Foto: reconstrucción de líneas de pedido usa precio/nombre/qty devueltos por servidor y foto de catálogo vigente, carrito actual o historial de la sesión. La lista de órdenes se convierte completamente **antes** de limpiar las viejas, así no se pierden URLs con refresh. El fallback sin catálogo previo no garantiza foto tras reinstalación/offline; no se inventa URL.
- Pago: pantalla pendiente auto-consulta backend cada 8 s solo en primer plano, mantiene sesión y se detiene al confirmar/cancelar. Desaparece botón “Verificar pago”. **Solo webhook/backend** puede marcar paid. `Stripe PaymentSheet` es UI nativa (no Checkout URL); errores de configuración/Android se muestran sin cancelar automáticamente la reserva ni fabricar éxito.
- Auth: overlay blanco del 75% pasa a 53%, mayor contraste en subtítulo, imágenes de fondos originales visibles.

## Verificaciones y límites
- Pruebas agregadas para cantidad/restauración de foto/carrito global/polling; CI Flutter analyze, full tests, Android security y compilación debug.
- Stripe NO confirmado end-to-end: requiere en dispositivo observar error concreto de apertura nativa y revisar la configuración de Stripe/backend autorizada, sin pagos reales.
- Recuperación por correo NO confirmada: endpoint devuelve HTTP 202 y encola; **requiere entregar realmente por SMTP/worker**. Seguimiento backend [#68](https://github.com/AlanPalacios23/AlanPalacios23-tala-eats-backend/issues/68). Mobile no puede garantizar recepción.
- Se conservan tres apps separadas. Nada se despliega en Kali ni se modifica Stripe LIVE, `.env.production`, bases de datos o pagos reales.
