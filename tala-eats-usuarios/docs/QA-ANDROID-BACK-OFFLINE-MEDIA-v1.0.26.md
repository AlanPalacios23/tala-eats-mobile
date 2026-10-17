# TALA EATS Usuarios v1.0.26 · Android Back, offline y fotografías

Alcance: Flutter Usuarios Android-first, basado en main v1.0.25. Sin cambios en endpoints, modelo económico, PSP, Kali ni aplicaciones Restaurante/Repartidor.

## Comportamiento
- Android Back dentro de la pestaña Buscar, Pedidos o Cuenta regresa a Inicio sin finalizar el shell ni pedir logout. En Inicio mantiene el comportamiento estándar de Android al salir de la raíz. Las rutas de detalle, checkout y pago tienen su propio Navigator/PopScope y no se modifican.
- Cuando la app reporta modo offline y se está ejecutando refreshAll, el botón «Reintentar» se desactiva temporalmente e indica «Reintentando…», evitando solicitudes duplicadas.
- Las portadas tienen comportamiento de respaldo preexistente y ahora cubierto por regresión: bloquea HTTP inseguro, usa icono neutral para rutas ausentes/asset no existente y cuando falla la descarga HTTPS. No inventa fotos de platos.

## QA sintética verificable
Test dedicado android_back_offline_media_test.dart: comportamiento de Back de tres pestañas, reintento offline a 320dp/x1.3 y fallbacks de recursos locales/remotos. Ejecutar con análisis, P0, tests Flutter completos, gate de secretos/manifest y APK Android debug en CI sin publicar.

## Pendiente y NO-GO
Estos tests son widget tests en Linux; no sustituyen Back predictivo de Android físico, IME y permisos reales, red inestable sobre celular, fotografías reales de comerciantes/CDN, pago TEST, FCM real ni recorrido tres roles. Ameca falla aislamiento en API productiva y FCM está OFF según auditoría previa. Mantener checklist de E2E abierto.
