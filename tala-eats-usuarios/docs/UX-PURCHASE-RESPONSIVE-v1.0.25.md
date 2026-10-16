# TALA EATS Usuarios v1.0.25 — Menú, carrito, checkout y pedidos responsive

## Alcance
Pulido incremental solo de interfaz Usuarios. No cambia tarifas, Stripe/Mercado Pago, GPS, catálogo, disponibilidad, lógica de backend ni política comercial. No se despliega en Kali.

## Elementos pulidos
- Carrito: debajo de 330dp útiles, control de cantidad bajo nombre y fotografía; importe visible sin cortar el nombre.
- Checkout: entrega y recoger se apilan con ancho íntegro cuando el espacio disponible es menor a 320dp.
- Desglose: etiquetas e importes se distribuyen verticalmente bajo 310dp útiles. «Por confirmar» cuando el backend no ofrece referencia; nunca se inventa total definitivo.
- Pedido activo: el estado ocupa segunda línea en tarjetas estrechas; se conserva estado, total y progreso recibidos del servidor.

## Gates
Tests widget dedicados en 320/360/390/430dp, tipografía x1.3: carrito, resumen del checkout, opciones de entrega, pedido activo y ficha producto. Análisis Flutter, suite completa, P0 de idempotencia, gate de seguridad Android y compilación debug efímera sin firma release/distribución.

## Checklist y límites
Se puede cerrar solo subcheck de UI responsive simulada cuando CI sea PASS; no el flujo E2E con GPS, teclado real, screenshots físicos, pagos TEST y repartidores. El servidor sigue sin aislamiento regional válido para Ameca y FCM real apagado según los últimos GET de observabilidad. No inventar cobertura o capturas.