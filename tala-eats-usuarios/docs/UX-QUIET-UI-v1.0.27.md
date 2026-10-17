# TALA EATS Usuarios v1.0.27 — Pantallas silenciosas, decisiones claras

## Objetivo
Quitar ruido visual **sin reconstruir la app**. Usuarios debe permitir ver negocios reales, encontrar comida, saber cuánto/cómo recibirla y entrar a su cuenta sin encabezados repetidos, badges redundantes o publicidad artificial.

## Cambios concretos
- **Inicio:** sin contador decorativo del total de comerciantes junto al título. Mantiene localidad, dirección, saludo, buscar y catálogo real.
- **Buscar:** sin nube de chips de categoría en blanco, sin subtítulo local repetido y sin contadores en resultados. Comercios abiertos listados sin límite arbitrario de cuatro; búsquedas por nombre/categoría/platillo siguen activas al escribir. Si no hay catálogo, diferencia carga, error recuperable y ausencia real de comercios.
- **Restaurante:** nombre, categoría y descripción; rating/ETA/tarifa y modalidad de recoger en líneas compactas, sin la tarjeta de tres indicadores ni chips duplicados de abierto/recoger. Conserva promociones **solo provenientes del backend** y aviso funcional de comercio cerrado.
- **Cuenta:** Tala Club conserva saldo, puntos y acceso a billetera, pero deja de competir visualmente con el perfil mediante un panel naranja grande. Perfil conserva navegación a editar con chevron, sin CTA duplicado. Se elimina pie con versión **v1.0.12 obsoleta**; la versión válida queda en pubspec.yaml.
- **No se tocan:** contratos de red, carrito, checkout, cobros, promociones reales, tarifario, sesiones, Android nativo o apps Restaurante/Repartidor.

## Evidencia necesaria para cerrar subchecks
flutter analyze, 5 tests nuevos de UI sin ruido + búsqueda categórica y billetera navegables (320dp, letra 1.3); los 96 tests existentes; Android security gate y compilación APK debug efímera en GitHub Actions. Solo dar por cerrada **QA widget de jerarquía limpia**, nunca inspección visual real.

## Pendientes explícitos
Fotos reales CDN, QA en Android físico de Inicio, Buscar, Restaurante, Cuenta, UX con teclado, diseño en 320/360/390/430 dp reales, pruebas E2E pagos TEST, geolocalización y tres roles. Backend Kali sigue sin certificar Ameca (FAIL_MIXED_MARKET) y FCM permanece OFF; no cambiar despliegue ni Stripe LIVE.
