# TALA EATS Usuarios v1.0.28 · Referencias visuales y teclado

## Qué se puede validar sin un teléfono físico
- customer_keyboard_reduced_motion_test.dart: Buscar y cupón en Checkout a 320/360/390/430 dp, fuente 1.3 y área de teclado simulada de 290 dp. Aplicar cupón no crea pedidos ni llama a API de cobro.
- customer_visual_reference_capture_test.dart: nueve imágenes renderizadas con Flutter Test sobre Linux, NO capturas de teléfono Android. Home, Buscar, Restaurante, Carrito, Checkout, Pedidos y Cuenta a 390×844dp; más Home y Buscar a 320×844dp, escala 1.3.
- Modelos y precios sintéticos, sin tokens, datos reales, pagos, fotografías CDN, GET a producción ni credenciales.
- Generar: flutter test --update-goldens --dart-define=TALA_VISUAL_CAPTURE=true test/customer_visual_reference_capture_test.dart. La suite normal omite esta captura.
- Actions adjunta únicamente test/goldens/*_mock_*.png durante 7 días como artefacto talaeats-usuarios-v1028-capturas-sinteticas; NO adjunta APK.

## Criterio PASS
Pruebas de teclado/scroll/textScale/cupón sin side effects, Reduce Motion, nueve capturas PNG reproducibles, flutter analyze, suite Flutter completa, P0 44/44 y compilación Android debug efímera. Si cualquier paso falla mantener PR en borrador.

## Límites
El test Linux no certifica renders físicos de Android, IME real, Back predictivo, GPS, fotos CDN, contraste integral, FCM ni pagos TEST. No cerrar Capturas reales sin teléfono Android y evidencia anonimizada. El aislamiento de Ameca y FCM siguen pendientes del backend. No tocar Kali ni Stripe LIVE.

## Protocolo Android físico pendiente
Con app autorizada de prueba, comprobar Home, Buscar, Restaurante, Menú, Carrito, Checkout, Pedidos y Cuenta en distintas densidades, con texto 1.0/1.3, teclado, gestos Back, Reduce Motion y caída de imágenes; no confirmar pedidos ni pagos LIVE. Guardar capturas anonimizadas más modelo de dispositivo, versión Android, fecha y resultado. No instalar desde el APK debug efímero de CI.