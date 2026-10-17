# TALA EATS Usuarios v1.0.30 · Estados y avisos legibles

## Hallazgo reproducible
Los botones principales ya cumplían AA, pero existían combinaciones funcionales de texto pequeño que no llegaban a 4.5:1: kGreen sobre kSoftGreen (~3.97), kGreen sobre blanco (~4.40), kBrandDeep sobre kSoftOrange (~4.20). El branding original no se cambia.

## Corrección
- Token de presentación TalaReadableText.against: para un foreground/background concreto devuelve el color sin cambios si alcanza AA (4.5); de lo contrario oscurece exclusivamente el texto funcional hasta lograrlo.
- StatusPill y AuthNotice usan ese token. Las etiquetas de status largas admiten hasta tres líneas, con ancho máximo ligado al viewport para prevenir overflow de 320dp x1.3.
- No se alteran colores de logo, tarifas, estado del pedido, datos comerciales, session state ni API.
- Test customer_status_contrast_accessibility_test.dart: 8 pares de superficie/color, conservación de marca, 320dp x1.3 con etiqueta larga y ambos tipos de aviso.

## Gate para cerrar subcheck
Flutter analyze + test nuevo + suite completa + 44 P0 + Android security and debug build sin publicar. **Este gate cierra únicamente accesibilidad sintética del texto en StatusPill/AuthNotice**, no la auditoría de todos los contrastes, fuentes, fotos y recorridos en un dispositivo real.

## Pendiente externo
La certificación Android físico, contraste integral, pagos TEST, GPS, fotos/CDN, filtro Ameca en Kali y FCM OFF siguen abiertos. Mantener piloto Tala y no habilitar Stripe LIVE para pruebas.
