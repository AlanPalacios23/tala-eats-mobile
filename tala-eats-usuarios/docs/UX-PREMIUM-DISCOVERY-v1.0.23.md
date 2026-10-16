# TALA EATS Usuarios · v1.0.23 Premium Discovery

Alcance: Flutter Usuarios Android-first. Evolución visual incremental sobre v1.0.22. Sin reconstruir apps ni modificar backend, pedidos o pagos.

## Dirección visual

- Referencia de calidad: jerarquía, navegación y limpieza visual de plataformas líderes de delivery (como Uber Eats), sin copiar sus logotipos, pantallas o assets.
- Marca: identidad naranja TALA EATS (#FF5A1F), negro y superficies blancas. Conservar logos originales.
- Home sigue centrado en pedir: Entregar en, localidad seleccionada, saludo, pregunta, barra de búsqueda y comercios reales del backend. No banners, promociones inventadas ni categorías decorativas.
- Tarjetas: fotografía 16:9, bordes suaves, nombre y metadatos separados de la imagen; indicador Cerrado solo cuando corresponda, favorito accesible y patrocinio solo si proviene del backend.
- Datos reales: calificación solo si existe, categoría, ETA y tarifa. No inventar descuentos, negocios, reseñas ni tiempos.
- Buscar en blanco: categorías del catálogo real y hasta cuatro comercios abiertos del mercado activo, sin añadir endpoints ni mezclar localidades.
- Estado vacío contextualizado a la localidad elegida.
- Sistema: fondos neutros más claros, elevación y sombras discretas, barra inferior de cuatro acciones intacta, Reduce Motion y accesibilidad preservados.

## QA exigido

- Flutter analyze sin errores
- Test dedicado de Inicio/Buscar: 320/360/390/430 dp, texto 1.3, búsqueda y estados vacíos
- Suite Flutter completa con pruebas de pedido, idempotencia, mercado, sesiones y FCM
- Validación de manifiesto Android y patrones de secretos
- Compilación APK Android debug solo temporal en CI, sin firma release ni publicación

## Límites

Estas verificaciones NO certifican calidad fotográfica del catálogo real, funcionamiento con Android físico, GPS, FCM de verdad, pago TEST ni filtro backend de Ameca. La observabilidad read-only previa encontró mezclas de mercados en la API actual; no modificar Kali ni declarar expansión activa.

Antes: tarjetas voluminosas con marco/sombra y etiqueta Abierto repetida; búsqueda inicial mayormente vacía.
Ahora: tarjetas más editoriales con imagen protagonista y metadatos legibles; búsqueda con establecimientos reales disponibles, sin datos decorativos ficticios.
