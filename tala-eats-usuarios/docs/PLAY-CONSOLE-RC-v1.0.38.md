# TALA EATS Usuarios · v1.0.38+49 · RC0 (NO PUBLICAR)

**Fecha:** 21 de octubre de 2026  
**Rama:** `release/usuarios-v1.0.38-rc0-hardening-20261021`  
**Base:** PR #50 sobre PR #49 (interfaz v1.0.36); NO sustituye automáticamente la otra rama divergente PR #39 v1.0.37.  
**App única:** `tala-eats-usuarios/app`, Android package invariable `com.talaeats.app`.

Este RC0 es una *candidata de integración*, no una versión autorizada para producción. No toca Kali, Stripe LIVE, Restaurante, Repartidor ni ADMIN; nunca se genera ni publica una build firmada en CI.

## A. Ya incluido en la rama

- [x] Interfaz bienvenida/login/registro v1.0.36 preservada, con errores API robustos y prevención de dobles confirmaciones.
- [x] Notificaciones Android solo con consentimiento y coincidencia **exacta** de `project_id` Firebase entre backend y app (si falta, no se registra FCM).
- [x] Pedidos **nuevos** restringidos a métodos habilitados por backend: efectivo / Stripe. Mercado Pago ignorado aunque aparezca en un backend antiguo. Los pedidos históricos y su estado siguen legibles; no se promete que la pasarela antigua sea operativa en Node.js.
- [x] Si no hay ninguno de los dos métodos habilitados, checkout queda bloqueado y muestra aviso explícito; nunca inventa un método.
- [x] Comando de firma AAB local de la línea v1.0.37 adaptado a este RC0: `ci/build_signed_play_bundle.py --check` y `--build`. Exige keystore upload fuera del repo, los cuatro datos públicos Firebase, SDK 36, firma release real, verificación `jarsigner`.
- [x] El **build firmado** verifica obligatoriamente las cuatro imágenes originales HD de la portada por SHA256 antes de compilar: no se pueden publicar fallbacks.
- [x] Tests de integridad de firma, identidad Firebase y Stripe/efectivo añadidos al pipeline.

## B. Bloqueos estrictos hasta producción

| Bloqueo | Estado / evidencia necesaria |
|---|---|
| Recursos gráficos originales | FALTAN cuatro binarios: `food_fiesta.webp`, `food_tala.webp`, `tala_eats_original_wordmark.png`, `tala_eats_wordmark_transparent.png`. Extraer el ZIP original provisto por dueño y subir a `tala-eats-usuarios/app/assets/landing/`, sin inventar imágenes o alterar hashes. Gate `verify_landing_assets.py` debe dar 4/4 PASS. |
| Unificar ramas | PR #39 (Play v1.0.37) y PR #49–50 (nuevo onboarding) divergen. Revisar diferencias funcionales/visuales PR #39–46 y realizar integración controlada. No mergear ambas por orden arbitrario. |
| Backend Node.js | Solo usar staging `https://api-stage-talaeats.alan-palacios-dev.com/api/v1` hasta verificar login, catálogo, checkout, `/orders/payment-methods`, webhook, seguimiento, soporte y roles con contratos reales. Las respuestas de un backend Python LIVE no demuestran paridad Node. |
| Stripe TEST | E2E de `PaymentSheet`, cancelación/reintento, webhooks con firma, inventario, pedido exactamente una vez, sin dinero ni tarjetas reales. |
| Firebase FCM | Registrar app Android `com.talaeats.app` en proyecto real, configurar backend STAGING con secretos fuera de APK y mismo Project ID; verificar entrega, opt-in, cambio de usuario, revocación, foreground/background. |
| Correo de recuperación | Demostrar recepción SMTP real en buzón QA, links HTTPS seguros y expiración; respuesta 202 de API no prueba envío. |
| Play Console | Keystore local, Play App Signing, package fijo, políticas de privacidad, eliminación de cuenta pública, Data Safety, compatibilidad API36/16KB y políticas vigentes; subir primero a pista de pruebas internas. |
| Android físico | 320/360/390/430dp y texto x1.3; teclado, back, reinicio, GPS, Wi-Fi/datos/offline, ver pedidos y seguimiento reales. |

## C. Compilación y firma (solo equipo del dueño; nunca CI)

```sh
cd tala-eats-usuarios
python ci/build_signed_play_bundle.py --check
python ci/verify_landing_assets.py
# Sólo después de configurar las variables locales de firma y Firebase:
python ci/build_signed_play_bundle.py --build
```

Variables locales de firma (NO pegar aquí ni almacenar en GitHub):
`TALAEATS_UPLOAD_KEYSTORE`, `TALAEATS_UPLOAD_STORE_PASSWORD`, `TALAEATS_UPLOAD_KEY_ALIAS`, `TALAEATS_UPLOAD_KEY_PASSWORD`.

Variables públicas Firebase compiladas en app:
`TALAEATS_FCM_API_KEY`, `TALAEATS_FCM_APP_ID`, `TALAEATS_FCM_SENDER_ID`, `TALAEATS_FCM_PROJECT_ID`.

El AAB esperado es `app/build/app/outputs/bundle/release/app-release.aab`, firmado con la upload key real, validado con `jarsigner`. El script **no** publica ni carga claves a GitHub. No copiar APK debug a Play Console.

## D. Matriz de QA E2E mínima en staging

1. Registro cliente: aceptar términos y aviso, email válido, login, recuperación por correo real.
2. Catálogo multimercado: solo comercios del mercado seleccionado, búsqueda sin productos de otro mercado, imágenes y stock.
3. Producto, notas por artículo, carrito, envío/recoger, elegibilidad GPS, tarifas obtenidas del servidor y sin inflación de propinas.
4. Efectivo habilitado: pedido `POST /orders` 1 vez, idempotencia con doble toque, establecimiento acepta/recibe, reparto completa.
5. Stripe TEST habilitado: crear PaymentIntent, PaymentSheet y webhook, estado `paid` por backend; cerrar hoja no produce cargo ficticio.
6. Backend anuncia solo Mercado Pago / ningún método: no crear ni cobrar pedido, aviso preciso.
7. Regresar de segundo plano, modo avión, reintento sin pérdida de carrito ni falsa cancelación; refresh seguimiento y PIN/driver sin información inventada.
8. Rol ajeno denegado; sesión Android cifrada; tras cerrar sesión no registrar nuevos tokens FCM.
9. Flujo Soporte Usuarios → ADMIN STAGING → respuesta al cliente; no leer tickets ajenos.

Mantener evidencias por pantalla, hash de build, SHA exacto del PR, id de run CI y resultados de servidor STAGING; sin datos personales ni medios de pago reales.

## E. Decisión de release

**GO** solo cuando los bloqueos A–D estén cerrados, un revisor confirme los contratos del backend destino, la suite CI dé PASS incluido media 4/4 y la Play Console valide el AAB. Mientras tanto **NO-GO** y PR en draft.
