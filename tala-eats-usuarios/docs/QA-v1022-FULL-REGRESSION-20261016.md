# TALA EATS Usuarios v1.0.22 — auditoría ampliada de pruebas (16/10/2026)

## Objetivo
Validar el código Android de Usuarios, detectar regresiones funcionales antes de distribuir APK y **distinguir evidencia real de mocks**. No implica que la APK esté probada físicamente, que exista Firebase operativo, que el backend vigente incluya el PR de mercados ni que los pagos TEST/LIVE estén certificados.

## Cobertura automatizada
| Función | Prueba | Límite |
| --- | --- | --- |
| Login/restauración y revocación | `priority_p0_network_resilience_test.dart` / `backend_customer_contracts_test.dart` | Mock, no login real |
| Carrito/checkout/idempotencia | `order_submission_guard_test.dart`, `priority_p0_order_contract_test.dart` | No crea pedido externo |
| Tarifas/comercial | `checkout_pricing` y pruebas existentes | Solo vista: backend manda importe final |
| Mercados/Tala piloto | `customer_markets_contract_test.dart`, `customer_model_full_integration_test.dart` | Requiere contrato PR backend #65 |
| Carrera de cambio de mercado / menú | `customer_model_full_integration_test.dart` | Mock temporizado sin red LIVE |
| Direcciones | `backend_customer_contracts_test.dart` + `customer_model_full_integration_test.dart` | PATCH simulado, no edición real |
| Segurid./reembolsos cliente | `customer_ui_full_integration_widget_test.dart` | Datos mock sin operaciones financieras |
| UI y accesibilidad | `customer_ui_full_integration_widget_test.dart` | 320,360,390,430dp y texto ampliado |
| FCM opt-in | `customer_native_push_contract_test.dart` | No demuestra entrega FCM |
| Seguridad Android | `ci/security_android_gate.py --role usuarios` | Solo manifest y patrones de secretos |
| Compilación Android | `flutter build apk --debug --no-pub` | APK efímera, no firmada release ni distribuida |
| API exterior SOLO GET | `ci/live_readonly_contract_probe.py` | Puede ser bloqueada por WAF; sin credenciales |
 
## Protecciones ante regresiones
1. Ningún menú de restaurante antiguo puede volver a entrar en búsqueda tras cambiar de localidad o recargar catálogo.
2. Un comercio cerrado, inexistente o cantidad inválida no debe destruir carrito válido ni apuntar a otro restaurante.
3. Un `refreshAll` antiguo no debe reemplazar el catálogo de la localidad recién elegida.
4. Ante fallo de la API al cambiar de mercado, carrito y preferencia deben mantenerse.
5. Backend sin aislamiento `market_code` debe detectarse; no mostrar comerciantes de otra ciudad por fallback.
6. Billetera, pagos, subsidios y liquidaciones sólo se muestran según datos del servidor: no se simulan como pagados.

## Restricciones
- Sin crear cuentas, pedidos o checkout; sin POST/PUT/PATCH/DELETE en Kali. Script de sondeo solo usa GET públicos.
- HTTP 403/404/WAF en pruebas externas se documenta como **sin certificar**, no como éxito.
- Firma release, prueba en Android físico, GPS real, recuperación tras crash/kill, FCM real y sandbox PSP exigen entorno/dispositivos habilitados.
- Esta PR solo afecta TALA EATS Usuarios + workflow QA. No modifica backend, otras apps, .env, servidor Kali ni Stripe LIVE.

## Resultados verificados
Pendiente de la nueva ejecución GitHub Actions y diagnóstico de endpoints. Referencia de versión previa v1.0.22 PASS: https://github.com/AlanPalacios23/tala-eats-mobile/actions/runs/38949037311
