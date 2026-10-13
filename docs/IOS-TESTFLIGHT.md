# TALA EATS · Ruta iOS con GitHub Actions

Se han preparado las tres apps Flutter para compilación **sin firma** en GitHub-hosted macOS:

| Rol | Fuente | Bundle identifier propuesto |
| --- | --- | --- |
| Usuarios | `tala-eats-usuarios/app` | `com.talaeats.app` |
| Restaurante | `tala-eats-restaurante/app` | `com.talaeats.restaurant` |
| Repartidor | `tala-eats-repartidor/app` | `com.talaeats.driver` |

Workflow: `.github/workflows/ios-build.yml`. Bootstrap nativo: `ci/bootstrap_ios.py`. Flutter 3.47.6, macOS 15/Xcode, iOS 15.0 como mínimo.

## Alcance del pipeline

1. Regenera el proyecto iOS de forma temporal (no modifica producción).
2. Configura Info.plist: ubicación, cámara y galería según rol, y URL scheme de Usuarios.
3. Ejecuta `flutter pub get`, `flutter analyze` y `flutter test`.
4. Construye `flutter build ios --release --no-codesign`.
5. Si todo pasa, publica un artefacto `Runner.app` comprimido para diagnóstico.

**ATENCIÓN: Runner.app sin firma NO es un instalable de iPhone y NO equivale a IPA de distribución.** La compilación exitosa solo valida el código y el proyecto nativo. Este workflow no publica a TestFlight.

## Próximo paso: iPhone y TestFlight

Para instalar mediante TestFlight de forma sencilla y sin Mac local, necesitamos primero:
- Apple Developer Program activo y acceso a App Store Connect (se necesita membresía de pago para distribución TestFlight).
- Registrar tres app IDs únicos, confirmar propietario de los identificadores.
- Configurar firma de distribución iOS (certificado + provisioning profiles/identidad de firma) mediante **GitHub Actions Secrets**; nunca introducir claves, contraseñas, API keys, certificados privados ni archivos `.p12` directamente en el chat o repositorio.
- Aprobar permisos/capabilities por rol (por ejemplo Apple Pay, cámara, GPS y posibles modos en segundo plano; no activar capacidades sin revisión).
- Configurar credenciales de App Store Connect en secretos y un flujo de publicación a TestFlight bajo autorización, separado del build de verificación.

Apple revisa/reporta builds y configura testers; TestFlight podrá requerir procesamiento/revisión.

**Costo:** macOS runners para GitHub privados consumen minutos de Actions a una tarifa más alta que Linux. Los runs pueden agotar la cuota. Revisar GitHub → Settings → Billing and licensing → Actions.

## Límites actuales
- Sin firma Apple, sin carga de TestFlight, sin IPA instalable.
- Sin pruebas E2E físicas de pagos, GPS, cámara ni deep links.
- Backend Kali/Stripe LIVE fuera de alcance.
- Antes de distribución: sustituir iconos iOS genéricos por el branding original de TALA EATS.
