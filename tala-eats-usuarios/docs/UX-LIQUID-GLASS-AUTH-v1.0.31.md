# TALA EATS · Usuarios · v1.0.31+42 · Liquid Glass Auth

## Alcance
Evolución exclusivamente visual a partir del HEAD de main v1.0.30+41.
Las pantallas Login y Crear cuenta activan liquidGlass: true en
PremiumAuthScaffold. El inicio blanco, el catálogo, los pagos, la navegación
principal y las apps Restaurante/Repartidor no se modifican.

## Diseño
- Fondo blanco con reflejos naranja estáticos y discretos.
- Tres paneles flotantes de vidrio por pantalla: marca/regreso, título y formulario.
- BackdropFilter recortado al radio del panel, no a pantalla completa.
- Gradientes blancos translúcidos, borde claro, profundidad suave.
- Inputs de alto contraste con foco naranja profundo (kBrandDeep).
- CTA naranja legible; mantener autofill, mostrar/ocultar contraseña,
  avisos legales y feedback háptico.
- Scroll vertical con teclado, anchos de 320 a 430 dp y tipografía 1.3.
- La animación Reveal sigue respetando Reduce Motion.
- No se introducen paquetes Flutter, fuentes, APIs ni imágenes externas.

## Límites y seguridad
PremiumAuthScaffold mantiene liquidGlass: false por defecto, de modo
que recuperación, verificación y restablecimiento conservan su diseño.
No se modifican TalaModel, credenciales, registro, API, Stripe, estado
de sesión, permisos ni rutas de producción.

## QA
- flutter pub get
- flutter analyze --no-fatal-infos
- flutter test test/liquid_glass_auth_test.dart
- flutter test
- Revisión visual física en Android con teclado, orientación vertical,
  pantallas pequeñas, contraste y rendimiento de blur.
- El workflow GitHub Actions del PR ejecuta suite completa y APK debug
  efímera; NO genera AAB firmado ni publica.

Estado: candidato para revisión; no afirmar build PASS antes de que
GitHub Actions lo confirme. Fusionar únicamente después de QA.
