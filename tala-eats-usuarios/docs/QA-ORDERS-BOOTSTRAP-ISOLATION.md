# TALA EATS Usuarios · QA de carga inicial tolerante a pedidos offline

## Hallazgo
Después del hotfix de historial (PR #31), `refreshOrders()` diferenciaba un error de la respuesta `[]`, pero `refreshAll()` seguía incluyendo `GET /orders/mine` en un `Future.wait` de siete servicios obligatorios. Un HTTP 503 aislado impedía cargar catálogo, direcciones, perfil, billetera y notificaciones aun si respondían correctamente.

## Cambio limitado a Usuarios Flutter
- Aísla únicamente la consulta de historial de pedidos en la carga inicial: un 503, timeout o error imprevisto conserva pedidos previos y registra `ordersLoadError`; las demás secciones autorizadas pueden renderizarse.
- Un GET de historial exitoso con `[]` continúa siendo autoritativo y limpia el error.
- Los errores HTTP 401/403 NO se enmascaran ni convierten en historial vacío: la autenticación sigue siendo obligatoria.
- Una carga iniciada antes del logout no puede volver a aplicar respuestas de la cuenta anterior; el cierre de sesión también cancela el indicador visual de carga.
- No toca checkout, precios, tarjetas, pagos, backend ni autenticación de otras apps.

## Gate y límites
Pruebas fake API de catálogo sano + pedidos 503/reconexión; resultado tardío tras logout; rechazo 401. CI exige `flutter analyze`, test específico, regresión completa, 44 P0, controles Android de seguridad y compilación debug efímera del HEAD de la PR antes de considerar un merge.

**No es evidencia E2E** de red móvil, Android físico, Stripe TEST, Mercado Pago sandbox, Firebase, GPS, filtro de Ameca ni ejecución en Kali. Mantener los checks generales abiertos y sin distribución de APK.
