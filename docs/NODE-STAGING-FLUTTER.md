# Tala Eats · Node.js staging en las 3 aplicaciones Flutter

## Estado comprobado (20-oct-2026)

- API pública de pruebas: `https://api-stage-talaeats.alan-palacios-dev.com/api/v1`.
- Cloudflare HTTPS: HTTP 200 en `/health`, `/ready` y `/restaurants` al probar a través de Cloudflare.
- PostgreSQL y Redis: disponibles. Stripe: operaciones financieras **deshabilitadas** (`financialWrites=false`, `onlinePaymentsEnabled=false`).
- La conectividad **no equivale a compatibilidad funcional completa**: validar autenticación, contratos JSON, catálogo, onboarding, pedidos y entregas en dispositivos reales antes de publicar.

## Compilar las tres APK de pruebas con Node.js

En GitHub → Actions → **Tala Eats | APK Android (solo manual)** → **Run workflow**:

1. Elegir la rama de integración mientras esté sin fusionar.
2. `app: todas`
3. `backend: node-staging` (predeterminado).
4. Ejecutar manualmente y descargar los tres artefactos APK si análisis, tests y compilación pasan.

Para probar el backend Python existente elegir `backend: python-production`. **Nunca se alteran las URL de producción en el código Dart ni se ejecutan compilaciones automáticas por push/PR.** El workflow Windows también admite ambos destinos, pero conserva su restricción de ejecutar solo desde `main` tras la fusión.

## Ejecutar manualmente desde cada carpeta `app/`

La configuración de Flutter se inyecta solo en el build. No contiene secretos.

```bash
# tala-eats-usuarios/app
flutter run --dart-define=TALAEATS_API_BASE_URL=https://api-stage-talaeats.alan-palacios-dev.com/api/v1

# tala-eats-restaurante/app
flutter run --dart-define=TALA_EATS_API_BASE=https://api-stage-talaeats.alan-palacios-dev.com/api/v1

# tala-eats-repartidor/app
flutter run --dart-define=TALA_EATS_API_BASE=https://api-stage-talaeats.alan-palacios-dev.com/api/v1
```

Si se usan comandos de instalación/compilación locales en Windows, comprobar que también reciban el `--dart-define` correspondiente. Si no, siguen usando los valores predeterminados de Python producción.

## QA necesario antes de considerar la integración completa

- Usuarios: registro/login de prueba, `auth/me`, lista/detalle de restaurantes, productos, carrito, precios, pedidos.
- Restaurante: onboarding, login OWNER, ficha de negocio, menú, KDS, aceptación y actualización de pedidos.
- Repartidor: onboarding/aprobación, login DRIVER, dashboard, disponibilidad, ubicación y flujo de entrega.
- Contratos entre Python/Node: verificar estructura, códigos HTTP, rol/autorización, campos y estados por ruta; no basta con que una ruta exista.
- **No usar cobros, retiros o datos reales en staging.** El backend Node.js aún tiene flujos de checkout/entrega no habilitados o sin paridad funcional total.

El portal ADMIN y el backend Python actuales **no se modifican** desde este repositorio. El API de staging puede ser accesible públicamente: restringir pruebas a cuentas/datos ficticios y endurecer seguridad antes de producción.
