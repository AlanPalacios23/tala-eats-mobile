# QA Android Usuarios v1.0.31+42 · Login 2FA y única presentación

## Reporte de dispositivo físico (17 oct 2026)
- En login, servidor respondía **«Código de verificación 2FA requerido o inválido»** sin campo OTP. Motivo: modelo/api ya aceptaban `otp`, pero la pantalla no capturaba ni entregaba ese valor.
- Al iniciar Android mostraba un icono genérico `T` antes de la animación de logo/repartidor. Requerimiento: no duplicar pantallas de carga.
- Diseño solicitado: fotografías exactas aportadas por el usuario (comida a color para login, arte Tala Eats en fondo blanco para la presentación).

## Cambios solo Usuarios
1. Login de correo, contraseña y **Código 2FA (si aplica)** de seis dígitos, teclado numérico, sin log/persistencia del código y envío en `POST /auth/login` como campo `otp` ya soportado. El 2FA sigue verificándose exclusivamente en el backend. Un error de verificación enfoca la casilla sin borrar el correo/contraseña.
2. Fotografía original `assets/branding/login_food.png` visible como cabecera limpia y no integrada al catálogo real. Enlaces de Términos/Privacidad siguen abriendo documentos internos actuales. Inicio de sesión, crear cuenta y recuperar contraseña conservados.
3. Una sola presentación de Flutter sin animación ni indicador artificial: `assets/branding/tala_intro.png` durante **mínimo cuatro segundos** junto al restore de sesión. Si red/inicialización demora más, no se fabrica completitud.
4. Android 12+ muestra su splash administrado por OS por un instante inevitable; el `T` genérico se oculta con glyph transparente y fondo blanco para no mostrar un segundo logotipo.
5. 2 imágenes originales se importaron con SHA-256 idéntico al material entregado; no se regeneró marca, no hay demo de comercios. Verifica checks en test `customer_login_2fa_branding_test.dart`.

## Límites
No hay afirmación de E2E 2FA exitoso hasta validar con un autenticador legítimo en el teléfono físico; no solicitar códigos, contraseñas ni capturas de tokens para QA. APK debug no es release firmada de Play Store. **No cambiar backend, Kali, pagos LIVE, Restaurante, Repartidor ni ADMIN.**

## Evidencia pendiente
CI Flutter analyze, 44 P0, suite completa Flutter, pruebas del login, seguridad del manifest, compilación Android debug y test físico con lector de pantalla, teclado/IME y enlaces legales.
