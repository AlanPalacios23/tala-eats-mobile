# TALA EATS Usuarios v1.0.21 — mercados regionales, integración defensiva

## Diseño

El selector está en Home y solo consulta catálogos filtrados por `market_code` mediante peticiones paginadas (`limit=100`, `offset` incremental). Se comprueba que **cada** comercio devuelto tenga el código solicitado; si el backend anterior ignora el parámetro, una respuesta mezclada genera error y se evita mostrar comercios ajenos al mercado. La app no trae el catálogo completo de todos los mercados para filtrarlo localmente.

Códigos: `TALA-JAL`, `CUISILLOS-JAL`, `AMECA-JAL`, `AHUALULCO-JAL`, `TEQUILA-JAL`, `AMATITAN-JAL`. **Tala es piloto**; estar en la lista no implica servicio ya disponible.

Los cambios de zona son manuales y se guardan en preferencias Android del dispositivo. Si hay carrito, se solicita consentimiento antes de vaciarlo. No se modifican pedidos existentes. El backend decide si la dirección GPS está dentro del radio de entrega; elegir un mercado no habilita una entrega.

## Dependencias y límites

- Backend PR #65 (`feature/local-market-catalog-filter-20261016`) **todavía sin fusionar**, y ningún cambio se implementa en Kali.
- Los endpoints legacy pueden ignorar `market_code` sin error HTTP; QA prueba la detección de respuestas cruzadas.
- Si el mercado legítimamente no tiene comercios, mostrar lista vacía y no pasar a Tala.
- GPS de localidad **no integrado todavía**: no hacer detección por proximidad a un restaurante ni geofences aproximados sin cartografía verificada; la elección manual prevalece.
- FCM/push nativo requiere proyecto Firebase Android y backend configurado; se tratará separadamente. Las notificaciones del buzón siguen conectadas al backend.
- Validación E2E: Android real, cuentas sintéticas, filtros completos, carrito y checkout, backend con PR #65 desplegada en staging; no afectar LIVE.

## Seguridad/QA

`flutter analyze --no-fatal-infos`, `flutter test` y `flutter build apk --debug` en CI. Tests cubren múltiples páginas, mercados vacíos, filtros ignorados, códigos inválidos y duplicados. La compilación no se publica ni incluye firma release.
