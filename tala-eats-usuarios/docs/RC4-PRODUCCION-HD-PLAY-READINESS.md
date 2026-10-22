# TALA EATS Usuarios · RC4 v1.0.41+52 · preparación de producción

**Estado a 22 de octubre de 2026:** candidata de código, **NO-GO publicación**.
Rama apilada sobre PR #54 (RC3 → RC2 → RC1 → RC0).
Alcance: solo app Android **Usuarios**, sin modificaciones en Kali, Node,
Restaurante, Repartidor, ADMIN, Stripe LIVE ni Play Console.

## Qué quedó preparado en código

1. Paquete de aplicación Android `com.talaeats.app`, versión
   `1.0.41+52`. Script firmado local `ci/build_signed_play_bundle.py`
   (upload key fuera del repositorio), API 36, formato `.aab`, firma JAR
   verificada y SHA256 del AAB una vez construido.
2. Importación segura de cuatro recursos visuales HD **originales**
   desde ZIP aprobado: `ci/import_original_hd_assets.py`, con ruta segura,
   rechazo de duplicados/symlinks/truncados/tamaños extremos y hashes
   verificados **sin alterar o recomprimir los binarios**.
3. Verificador `ci/verify_landing_assets.py`: el pipeline no publica si
   alguno de los cuatro SHA256 es incorrecto o falta.
4. Recursos de ficha de Play en `play-store-assets/`: se reservan los
   archivos oficiales con nombres exactos y se validan tamaños/CRC de PNG
   mediante `ci/verify_play_store_media.py`; las capturas deben proceder
   de una instalación real, nunca de pantallas sintéticas de CI.
5. Reporte local `ci/release_candidate_gate.py --check` con estado del
   código y material gráfico. Nunca afirma que estén completos E2E,
   firma, plataforma o permisos solo con un script.
6. Pruebas unitarias adicionales de importación de ZIP y medios Play
   ejecutadas en GitHub Actions junto con el conjunto previo Flutter.

## Cómo entregar e integrar los cuatro originales

Necesitamos el ZIP aprobado con exactamente estos binarios:

```text
food_fiesta.webp
food_tala.webp
tala_eats_original_wordmark.png
tala_eats_wordmark_transparent.png
```

En Windows PowerShell, tras actualizar esta rama del repositorio:

```powershell
cd tala-eats-usuarios
python ci/import_original_hd_assets.py --zip "C:\\Ruta\\TalaEats-HD-ORIGINAL.zip" --check
python ci/import_original_hd_assets.py --zip "C:\\Ruta\\TalaEats-HD-ORIGINAL.zip" --install
python ci/verify_landing_assets.py
```

**El script no inventa imágenes ni se salta los SHA256 fijados.** Si
aparece `TALA_EATS_HD_BLOCKED`, detener release: revisar el ZIP
original del dueño y su procedencia; nunca cambiar un hash para forzar
que pase.

## Gráficos finales de Play Store

Crear o proporcionar desde archivos aprobados:

- `play-store-assets/icon-512.png`: ícono oficial de 512 × 512 PNG.
- `play-store-assets/feature-1024x500.png`: diseño promocional de
  1024 × 500 PNG RGB, sin transparencia.
- `play-store-assets/screenshots/*.png`: al menos dos capturas reales
  320–3840 px. Recomendación: Home, Buscar, comercio, carrito,
  checkout y seguimiento en instalación Android con datos de prueba
  y ninguna información personal real.

```powershell
python ci/verify_play_store_media.py --check
python ci/release_candidate_gate.py --check
```

Las capturas y el material de tienda no han sido falsamente generados
durante esta RC; el directorio está **preparado para recibirlos**.

## Firma de Google Play (se ejecuta solo en el ordenador del dueño)

```powershell
.\ci\GENERAR-AAB-PLAY-WINDOWS.ps1 -SoloRevisar
# Una vez añadidos los 4 originales y configurado Firebase real:
.\ci\GENERAR-AAB-PLAY-WINDOWS.ps1
```

El script solicita la upload key `.p12` y credenciales fuera de GitHub,
comprueba material de entrada y firma la release. Archivo previsto:
`app/build/app/outputs/bundle/release/app-release.aab`.
**No existe un AAB firmado todavía, porque no se han aportado los medios
originales ni la clave privada.**

## NO-GO → evidencia estricta para autorizar producción

| Requisito | Evidencia de cierre |
|---|---|
| Código Flutter y Android | `flutter analyze`, `flutter test`, QA responsive, seguridad Android, debug APK CI verde |
| Marca en la app | Los cuatro originales en Git, `verify_landing_assets.py` 4/4 PASS + inspección visual de splash/bienvenida/selector |
| Recursos Google Play | Ícono/feature originales y capturas de build real, `verify_play_store_media.py` PASS |
| Node.js STAGING | API real y rutas equivalentes, login/catálogo/pedidos/pagos/soporte, roles y base de datos en servidor de pruebas |
| Stripe TEST | PaymentSheet, webhooks con firma, rechazo/reintentos, reconciliación, estados reales, sin cobrar LIVE |
| Soporte completo | Envío y consulta de casos + respuesta auténtica desde ADMIN con seguridad y permisos verificados; la RC3 aún NO soporta respuestas en tiempo real |
| Firebase/SMTP | FCM con ID de proyecto coincidente y consentimiento; recuperación real por email QA |
| Android físico | Ubicación/entrega/recogida, offline, teclado, TalkBack, dispositivos de diferentes resoluciones; comprobar compatibilidad con páginas de memoria 16 KB |
| Privacidad y Play | Avisos legales HTTPS, eliminación de cuenta, Data Safety, audiencia y permisos, Play App Signing |
| Publicación | `.aab` RELEASE firmado y comprobado, subir primero a **pista de pruebas internas**, revisar validaciones de Play Console |

Si cualquiera de estos puntos está pendiente, conservar PR en borrador.
No confundir `source preflight PASS` o `APK debug PASS` con publicación
en producción.

Fuentes oficiales para decisiones de formato y compatibilidad:
- https://support.google.com/googleplay/android-developer/answer/11926878?hl=es-mx
- https://support.google.com/googleplay/android-developer/answer/9866151?hl=es
- https://developer.android.com/guide/practices/page-sizes
- https://developer.android.com/studio/publish/app-signing
