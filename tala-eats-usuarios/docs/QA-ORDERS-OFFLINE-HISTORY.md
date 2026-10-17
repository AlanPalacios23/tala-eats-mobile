# TALA EATS Usuarios · Hotfix QA de historial offline (base v1.0.29/v1.0.30)

## Problema detectado
La función refreshOrders() ignoraba cualquier error de HTTP sin notificar a UI. Cuando el historial estaba vacío o todavía no se había recibido respuesta, la pantalla «Pedidos» podía afirmar «Aún no tienes pedidos», aunque la red o el servidor estuvieran fallando.

## Cambio
- Registrar ordersLoadError independientemente de la lista de pedidos y de errores de otras vistas.
- Preservar el historial ya descargado ante un error; una respuesta exitosa con lista vacía sí es autoritativa.
- Evitar refreshOrders superpuestos mediante ordersRefreshing.
- Estado UI específico: «No pudimos cargar tus pedidos», botón «Reintentar», y estado «Cargando tus pedidos».
- Limpiar esos datos de sesión al cerrar sesión. La lógica y validación de pagos, recálculo de precios y API siguen exactamente iguales.

## Prueba
Fake API local devuelve error 503 y luego [] con dos escenarios: historial previo no desaparece ante error, y pantalla de Pedidos no afirma vacío hasta GET exitoso. En 320dp, fontScale 1.3, el botón de reintento responde; sin POST, cuentas reales ni órdenes generadas. CI completo Flutter + Android debug, no APK distribuida.

## Límites
No equivale a historial E2E de una cuenta real, red inestable en teléfono físico, notificaciones FCM, estados push en vivo ni pedido pagado. Mantener check original abierto; cerrar solo subcheck de distinción offline/empty. No modificar backend Kali ni Stripe LIVE.
