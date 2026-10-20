# TALA EATS · Apps Flutter Android

## Ecosistema · 4 apps independientes

1. **Usuarios** — `tala-eats-usuarios/app` (v1.0.30).
2. **Restaurante** — `tala-eats-restaurante/app` (v0.7.6).
3. **Repartidor** — `tala-eats-repartidor/app` (v1.2.7).
4. **ADMIN** — `tala-eats-admin/app` (MVP v0.1.0, en revisión).

La app ADMIN es Flutter independiente y **comparte la API existente**; no reemplaza al portal ADMIN web ni agrega otro backend. Implementa acceso con rol+TOTP y consulta estadísticas, pedidos, usuarios y solicitudes. Las decisiones administrativas están bloqueadas en builds estándar hasta activar explícitamente el gate de STAGING. Guía: [Tala Eats ADMIN](tala-eats-admin/README.md).

La compilación de ADMIN se ejecuta manualmente con [ADMIN Android QA](.github/workflows/admin-android-qa.yml), separada de la matriz histórica de las otras tres apps. La rama Node de staging todavía no sustituye la producción Python; ningún PR despliega Kali ni habilita Stripe LIVE.


## Prioridad actual · Android-first (13 oct 2026)

✅ **Android CI:** las tres APK debug compilaron y pasaron análisis/tests en [ejecución #3](https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38451662979).

🧪 **Aún pendiente:** pruebas de inicio de sesión, navegación, GPS, pedidos y sincronización entre tres roles en teléfonos Android reales. Los tests de widget/unidad y una APK compilada no equivalen a un flujo E2E validado contra backend.

🍎 **iOS:** flujo configurado en GitHub, pero pausado en modo **solo manual** mientras se prioriza Android y se controla gasto macOS.

**Plan de trabajo / seguimiento**

1. **[P0: Pedido completo Usuarios → Restaurante → Repartidor](https://github.com/AlanPalacios23/tala-eats-mobile/issues/1).**
2. **[Usuarios: catálogo, carrito, checkout y precios](https://github.com/AlanPalacios23/tala-eats-mobile/issues/2).**
3. **[Restaurante: onboarding, menú, KDS, pagos y ubicación](https://github.com/AlanPalacios23/tala-eats-mobile/issues/3).**
4. **[Repartidor: GPS, asignaciones, pruebas de entrega y ganancias](https://github.com/AlanPalacios23/tala-eats-mobile/issues/4).**

Guías: [QA Android](docs/QA-ANDROID.md) · [iOS y TestFlight](docs/IOS-TESTFLIGHT.md).

**Seguridad:** las APK debug apuntan al endpoint configurado de Tala Eats; no ejecutar cobros o retiros reales para QA y no usar cuentas personales, bancarias ni credenciales en capturas/logs. El backend de Kali **no se modifica** desde este repositorio.

---


Repositorio privado para **Usuarios (v1.0.19)**, **Restaurante (v0.7.6)** y **Repartidor (v1.2.7)**.

## Estado actual

- ✅ Repositorio privado.
- ✅ Workflow `.github/workflows/android-apk.yml` publicado.
- ⏳ Falta **una sola carga** del ZIP inicial con el código fuente.
- ⏳ Sin ejecuciones PASS ni APK reales verificadas todavía.

## Activación (una sola vez, sin instalar nada en Windows)

1. Descargar el archivo **`TalaEats-GitHub-Actions-3-Apps-CI-KIT.zip`** desde la conversación de ChatGPT.
2. Abrir la página principal del repositorio y pulsar **Add file → Upload files**.
3. Subir **ese ZIP intacto**, con el mismo nombre, directamente a la **raíz** del repositorio (no a una subcarpeta). No hace falta descomprimirlo.
4. Pulsar **Commit changes** en la rama `main`.

El flujo en la pestaña **Actions** se activa con esa carga. Primero valida y extrae el kit en los tres directorios `tala-eats-usuarios/`, `tala-eats-restaurante/` y `tala-eats-repartidor/`, los guarda como archivos editables en Git y elimina el ZIP de la rama principal. Después ejecuta tres trabajos Android independientes.

En cada app: Flutter 3.47.6, Java 21, bootstrap Android, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`. Si todas las etapas pasan, la APK aparece en **Actions → ejecución → Artifacts**. Los diagnósticos se guardan incluso cuando una etapa falla.

### Importante

- Las APK son de **prueba/debug**, no versiones finales firmadas para tiendas ni garantía de funcionar sin defectos.
- Si una app falla QA, no se publica su APK: consultar el artefacto de diagnóstico de ese trabajo.
- La primera ejecución puede descubrir incompatibilidades reales de dependencias, Android/Gradle o tests.
- No publicar claves privadas, credenciales, contraseñas ni archivos de firma.
- Este flujo no despliega ni modifica el backend de Kali, Stripe LIVE, PostgreSQL, Redis, Cloudflared ni la web.
