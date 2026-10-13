# Tala Eats · Restaurante · Flutter CI

- App fuente de referencia: **v0.7.6** (Biblioteca del proyecto).
- Repositorio GitHub recomendado: `tala-eats-restaurante` (**privado**).
- Workflow: `.github/workflows/android-ci.yml`.
- Dispara automáticamente en `main` y PR; también admite `Run workflow`.
- **No publica**, no instala en dispositivos, no llama pagos, no despliega backend.
- Flutter: **3.47.6**, Java runner: **21**, Java bytecode: **17** para Usuarios, minSdk **23**.
- APK que genera (si todas las etapas dan PASS): `app/build/app/outputs/flutter-apk/app-debug.apk`.
- Conservar el Android applicationId original y las pantallas; la generación nativa replica el scaffold del instalador local.
- El repositorio omite tipografías binaras; Restaurante descarga Figtree y Bricolage OFL en el entorno CI. **No garantiza rasterización idéntica** a las TTF estáticas originales.
- Los archivos originales no incluyen `pubspec.lock` ni carpeta `android/`: el workflow genera Android de manera efímera. **Después del primer PASS conviene guardar y versionar `pubspec.lock`**, y controlar el scaffold Android en el repositorio para reproducibilidad a largo plazo.
- Este paquete es **configuración preparada, sin compilación realizada ni estado PASS afirmado**.

## Primer uso
1. Crea un repositorio privado vacío `tala-eats-restaurante` en GitHub.
2. Sube todo el contenido de esta carpeta, **incluido `.github/workflows/android-ci.yml`**, a `main`.
3. Ve a la pestaña **Actions** y abre `Tala Eats Android QA + APK`. Si está permitido, selecciona **Run workflow**.
4. Si el flujo termina exitosamente, descarga el Artifact con la APK de prueba desde la página de la ejecución.
5. Instala la APK en tu Android para comprobar UI, login, permisos y backend. No garantiza prueba real de pagos ni equivalencia de firmas.

**Advertencias:** una APK debug del servidor puede usar una clave distinta a la APK que tienes instalada. Android podría bloquear una actualización in-place; **no desinstales sin respaldar datos**. Las APK de producción requieren firma y QA adicionales. No guardes `.env`, llaves Stripe secretas o claves de firma en el repo.
