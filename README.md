# TALA EATS · Apps Flutter Android

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
