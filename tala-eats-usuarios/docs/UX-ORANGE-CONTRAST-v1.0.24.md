# TALA EATS Usuarios v1.0.24 · Orange readability polish

Accesibilidad incremental sobre UX premium v1.0.23, sin recrear la app, sin cambios al backend, checkout, servidor o claves.

## Identidad y contraste

- Marca conservada: naranja característico TALA EATS #FF5A1F (kBrand). Logo e imágenes originales intactos.
- Texto de énfasis y botones con letras blancas: tono funcional naranja más profundo #CE3C0A (kBrandDeep). Contraste calculado sobre blanco ~4.91:1, objetivo WCAG AA 4.5:1 para texto común.
- Fondo casi blanco y notas/small caps usan tono oscuro; se evita usar naranja claro del logo en texto de 11px.
- CTA principal y barra Ver carrito usan naranja profundo, igual que insignia numérica de notificaciones y botón enviar mensaje.
- Tarjeta Tala Club mantiene gradiente naranja de la propia marca, con tonos más ricos #CF4512 → #CE3C0A → #AA2D09 y texto blanco legible.
- No copiar colores o logos de Uber Eats.

## Validación

Tests automáticos verifican que kBrand no cambió, que kBrandDeep cumple 4.5:1 en blanco y fondo claro, y que el tema Flutter aplica realmente este tono a botones con texto blanco. Se ejecutan junto al smoke Inicio/Buscar, suite Flutter y compilación Android debug.

Esta verificación matemática no reemplaza un review visual en dispositivo físico ni una auditoría WCAG exhaustiva de cada pantalla, foco y estado.

## Seguridad

Sin activar Firebase, sin pedidos ni pagos LIVE, sin cambios en backend de Kali, Restaurante ni Repartidor. El filtro Ameca permanece NO-GO de la auditoría externa previa.
