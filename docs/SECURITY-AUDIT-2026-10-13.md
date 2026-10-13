# Tala Eats — Segunda revisión de código Android (13/10/2026)

## Alcance y evidencia
- Repositorio privado: `AlanPalacios23/tala-eats-mobile`, Flutter 3.47.6.
- Objetivo: **Usuarios v1.0.19**, **Restaurante v0.7.6**, **Repartidor v1.2.7**.
- Base comprobada: [Android #9](https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38458314045) **PASS 3/3** (seguridad nativa, `flutter analyze`, tests y APK debug).
- Se revisaron manualmente las rutas críticas de autenticación, cliente HTTP, checkout, órdenes, retiros, estado de repartidor, almacenamiento de tokens y Android MainActivity, además de un barrido de patrones en 15 archivos críticos. Es una **revisión parcial priorizada**, no una auditoría de seguridad total ni pentest.
- Nueva validación de cambios: [Android #10](https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38467725983).
- Segunda revisión de dependencias con OSV: [workflow OSV](https://github.com/AlanPalacios23/tala-eats-mobile/actions/workflows/dependencies-osv.yml); los resultados no deben considerarse PASS hasta confirmar el escaneo. El primer intento tuvo un error de configuración de workflow, no un hallazgo en dependencias.

## Hallazgos y tratamiento

| Severidad | Hallazgo | Evidencia / resolución | Estado |
|---|---|---|---|
| Alta (fiabilidad de sesión) | Usuarios eliminaba el token cifrado por **cualquier** excepción al restaurar sesión, incluida pérdida de red | `tala-eats-usuarios/app/lib/main.dart` `TalaModel.initialize` | **Corregido en código**; token solo se invalida por 401/403; QA #10 en curso |
| Media (autenticación) | Logout podía perder el token de autorización antes de construir la solicitud asíncrona al backend | `tala-eats-usuarios/app/lib/production_api.dart` `TalaApi._request`; credencial capturada antes del primer `await` | **Corregido en código**; requiere validación E2E de revocación |
| Media (disponibilidad) | La lectura HTTP de Usuarios no imponía límite explícito al tamaño de respuesta JSON | `readBoundedUtf8Response`: 4 MiB y timeout en stream | **Corregido en código**, con tests de payload fragmentado y exceso de tamaño |
| Alta (integridad transaccional) | `placeOrder()` genera una referencia temporal nueva en cada intento; un timeout posterior a crear la orden podría originar doble petición con distinta referencia | `tala-eats-usuarios/app/lib/main.dart`; [tarea #7](https://github.com/AlanPalacios23/tala-eats-mobile/issues/7) | **Pendiente crítico**: validar idempotencia y conciliación del backend antes de cambiar contratos |
| Media (exactitud financiera) | En Repartidor, el total de pedidos del día se suma desde el subconjunto de entregas recientes; si el backend trunca el historial a 20, la cifra puede quedar incompleta | `tala-eats-repartidor/app/lib/data/driver_backend.dart` `dashboard` | Pendiente: consumir agregado canónico del servidor o etiquetar como parcial |
| Media (recursos remotos) | Restaurante distingue URLs HTTP/HTTPS de archivos locales, pero no rechaza de forma uniforme referencias de imágenes `http://`; Android bloquea el tráfico claro a nivel manifest | `tala-eats-restaurante/app/lib/data/remote/remote_repositories.dart` y `remote_api.dart` | Pendiente: normalización estricta y QA de imágenes existentes |
| Limitación de cobertura | Un PASS de tests con APIs simuladas no acredita operaciones reales de red, permisos GPS, pagos, push ni idempotencia distribuida | [seguimiento E2E #1](https://github.com/AlanPalacios23/tala-eats-mobile/issues/1) | Pendiente antes de producción |

## Controles positivos observados
- Token de Usuarios en Android Keystore con cifrado AES/GCM (MainActivity.java).
- Restaurante y Repartidor usan almacenamiento seguro de Flutter para tokens; no se observaron registros de claves privadas o secretos en la revisión focalizada.
- Android Manifest generado exige `allowBackup=false`, `usesCleartextTraffic=false` para los tres roles.
- Los tres clientes usan base HTTPS productiva por defecto; se debe comprobar TLS y configuración de Caddy/Cloudflare por separado.
- Restaurante conserva una llave de idempotencia en diario cifrado para solicitudes de retiro inciertas; el cambio no se tocó.
- Endpoints privados anónimos devuelven 401 en [sondeo read-only al backend 1.6.4](https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38456332254).

## Condiciones para los próximos dos CHECK

### CHECK A — código y seguridad
- [x] Revisión manual priorizada de rutas críticas
- [x] Control P0 nativo de manifiesto/permisos/secretos
- [x] Correcciones de restauración de sesión, snapshot token y límites HTTP publicadas
- [ ] Android CI #10 concluido PASS
- [ ] OSV dependencias con resultados obtenidos, sin hallazgos críticos/altos pendientes
- [ ] Verificar idempotencia/duplicación de pedidos y casos de reintento del servidor

### CHECK B — validación de producción
- [ ] Apps instaladas en dispositivos Android y QA de permisos, sesiones, conectividad y pantallas pequeñas
- [ ] E2E con cuentas de prueba aisladas: cliente → restaurante → repartidor → entrega
- [ ] Conciliación de tarifas y Stripe TEST; no cobros ni retiros LIVE
- [ ] Auditoría de backend, conciliación de pagos, privacidad y seguridad servidor (fuera de este repositorio)
- [ ] APK/AAB release firmado, versionado y beta cerrada en Google Play

**Estado:** ningún CHECK es todavía autorización de producción. Las APK debug #9 sí están verificadas como compilables, y los nuevos cambios requieren revalidación en #10.

## Seguridad operativa
No se ejecutaron POST/PATCH/DELETE en el backend productivo, no se alteró Kali, Stripe LIVE, configuración de Cloudflared, balances ni certificados. No se publicaron secretos en este documento.


## Resultados de herramientas independientes (13/10/2026)

| Control | Resultado confirmado | Evidencia |
|---|---|---|
| OSV dependencias Flutter | **PASS** — 31 paquetes Usuarios, 107 Restaurante y 109 Repartidor (247 apariciones, pueden solaparse), **0 vulnerabilidades conocidas reportadas** | [OSV #2](https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38467948926) |
| Semgrep revisión estática | **PASS** — 94 archivos, 165 reglas ejecutadas, **0 hallazgos reportados** | [SAST #2](https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38468644890) |
| Android control nativo, tests y APK base | **PASS 3/3** en código anterior a las correcciones de sesión | [Android #9](https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38458314045) |
| Android primeras correcciones de sesión | **FAIL en análisis** por error de sintaxis introducido durante la edición; la línea se reparó | [Android #10](https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38467725983) |
| Android código corregido | **Pendiente de confirmación**, no se declara PASS hasta que cierren los trabajos | [Android #11](https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38468448092) |

Los scans OSV/Semgrep no revisan por completo las bibliotecas nativas Gradle y no son pentests. Las pruebas de backend, idempotencia y QA físico siguen siendo requisitos abiertos. 
