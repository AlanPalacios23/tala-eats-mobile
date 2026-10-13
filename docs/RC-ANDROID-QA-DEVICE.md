# TALA EATS — Pruebas en Android físico (RC debug)

**Objetivo:** validar las tres aplicaciones contra servicios de Tala Eats de manera **no destructiva** antes de autorizar un piloto.

> Las compilaciones actuales son **APK debug**, NO builds release firmadas para Play Store. El backend está en Stripe LIVE. No usar tarjetas, cuentas bancarias, transferencias o pagos reales para ensayos. Para E2E transaccional se necesita staging aislado con Stripe TEST y cuentas de QA autorizadas.

## Antes de instalar
1. Confirma que el run de GitHub Actions esté en verde: **P0 Seguridad**, **Análisis estático**, **Tests**, **Build APK** y **Artifact upload**, todos success para cada rol.
2. Descarga cada artefacto `TalaEats-<rol>-debug-<run>`, descomprímelo y abre `app-debug.apk` en un teléfono Android.
3. Si Android indica «App no instalada», puede tratarse de una **firma debug distinta entre runs de GitHub**. Respalda los datos no sensibles de QA y desinstala la APK anterior del mismo rol antes de instalar la nueva; no hagas esto con usuarios de producción.
4. No se modifica Kali ni se incluyen claves de release; anota versión de Android, marca, modelo, hora, red (Wi-Fi/4G/5G), compilación GitHub y el paquete.

## A. Usuarios — pruebas no transaccionales
- [ ] Arranque en frío, inicio de sesión de cuenta QA y salida segura
- [ ] Registro/recuperación sin revelar si existe un correo de terceros
- [ ] Catálogo de 5 comercios actuales (si permanece ese dato en backend), búsqueda, menús, fotos y disponibilidad
- [ ] Cambiar permisos de ubicación (permitir/denegar) y verificar mensajes de error
- [ ] Carrito: aumentar/restar cantidades y cambiar de restaurante sin mezcla de productos
- [ ] Checkout: confirmar **referencia** de envío; no pulsar botón de pago/confirmación en LIVE
- [ ] Wi-Fi → modo avión → datos: no perder la sesión segura por falta de red
- [ ] Volver atrás, tamaño de texto grande y navegación con teclado

## B. Restaurante — pruebas no transaccionales
- [ ] Registro/login autorizado de QA; 2FA si aplica, cerrar sesión y restaurarla
- [ ] Perfil de tienda, dirección textual y GPS, horario y opciones «recoger/entrega» según backend
- [ ] Crear un producto de QA **solo** en restaurante autorizado para ensayos y comprobar que aparece en Usuarios; eliminarlo después
- [ ] Foto válida JPG/PNG y archivo inválido rechazado sin bloquear la interfaz
- [ ] Menú, disponibilidad y errores de red; verificar que cantidades no pasan a negativas
- [ ] Pedidos/KDS: vistas y estados existentes en lectura; no cambiar pedidos reales
- [ ] Stripe Connect y retiros: inspección de estado solamente; no asociar cuentas bancarias reales ni iniciar retiros

## C. Repartidor — pruebas no transaccionales
- [ ] Login de QA, aprobación por rol, cierre de sesión
- [ ] Permisos de GPS exacto/aproximado/denegado y notificaciones si hay permiso
- [ ] Estado de disponibilidad; activar online solo en entorno sin asignaciones de clientes reales
- [ ] Dashboard, historial, ganancias y vista de evidencias existentes (siempre anonimizadas)
- [ ] Cámara/galería: denegación de permisos y recuperación
- [ ] Modo avión durante navegación; reintentos, batería y restauración desde segundo plano
- [ ] No aceptar, recoger ni completar pedidos reales hasta disponer de staging

## D. Flujo completo (solo staging aislado)
- [ ] Cliente: compra de prueba con totales **autoritativos del backend**, efectivo simulado o Stripe TEST
- [ ] Restaurante: recibe pedido una sola vez, acepta, prepara y marca listo
- [ ] Repartidor: recibe asignación única, recoge, aporta PIN/evidencia y completa
- [ ] Las 3 apps muestran mismo ID, estados, importe, propina y trazabilidad
- [ ] Timeout después de crear orden + reintento conserva referencia: **no crea duplicados**
- [ ] Cancelación, refund TEST, conciliación de outbox/webhooks y ledger sin doble saldo
- [ ] Verificar roles y seguridad entre cuentas: nunca se ven pedidos/datos de otros usuarios

## Criterio para dar PASS real
- **CI PASS** para exactamente el commit instalado, sin avisos críticos
- **Pruebas en dispositivo PASS**, con capturas anonimizadas y reporte de errores
- **E2E staging PASS** incluido fallo de red + idempotencia + pagos TEST
- **Revisión release** de permisos, claves/firma, política de privacidad, Google Play y rollback

## Reporte de incidencia
Aplicación/versión/build GitHub:
Dispositivo/Android:
Red y hora:
Acción/resultado esperado:
Resultado real:
Captura/video sin datos privados:
Severidad: P0 / P1 / P2
