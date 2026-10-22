# TALA EATS · Ficha de Google Play (borrador es-MX, RC2)

**Estado: BORRADOR / NO PUBLICAR hasta pruebas reales.** La aplicación **Usuarios** abre inicialmente en Tala, Jalisco; otras localidades requieren disponibilidad real de comercios, cobertura y servicio. No anunciar cobertura de municipios aún no habilitados.

## Campos listos para revisar y copiar a Play Console

- **Nombre de la aplicación:** Tala Eats
- **Descripción breve** (máximo 80 caracteres):

> Pide comida y compra en comercios de Tala. Entrega o recoge fácilmente.

- **Descripción completa** (máximo 4,000 caracteres):

> **Tala Eats: tus antojos y comercios locales en un solo lugar.**
>
> Explora restaurantes y negocios disponibles cerca de ti, descubre sus productos y arma tu pedido desde el celular.
>
> **Elige lo que necesitas.** Revisa el menú o catálogo, consulta los precios y agrega productos al carrito. Puedes incluir indicaciones para cada artículo.
>
> **A tu manera.** Según la disponibilidad de cada comercio, selecciona entrega a domicilio o recoger tu pedido. Antes de confirmar, revisa el desglose de productos, cargos y entrega.
>
> **Paga de forma clara.** Cuando estén habilitados por el servicio, utiliza Stripe para el pago digital o elige efectivo. El total definitivo y el estado del pago los confirma el servidor.
>
> **Sigue tu pedido.** Consulta su estado desde la sección Pedidos y vuelve a revisarlo cuando recuperes la conexión.
>
> Tala Eats comienza en Tala, Jalisco. Los comercios, las modalidades de entrega y los métodos de pago están sujetos a disponibilidad en tu zona.
>
> **Buena comida, mejores momentos.**

**No agregar** promesas de envíos en minutos exactos, descuentos garantizados, número de restaurantes, cobertura regional, servicios financieros, notificaciones Push activas o alianzas no verificadas.

## Paquete de publicación RC2

| Campo | Valor / condición |
|---|---|
| Aplicación | Usuarios; no es Restaurante, Repartidor ni ADMIN |
| Identificador (no modificar) | `com.talaeats.app` |
| Versión en fuente | `1.0.40+51` |
| Android mínimo | API 23 (validar en AAB) |
| Objetivo Play | Android 16 / API 36 |
| Formato de publicación | **Android App Bundle (`.aab`) de release firmado con upload key**, no APK debug |
| Firma | Keystore/alias/contraseñas solo locales. Google Play App Signing administra firma para distribución |
| Compatibilidad | Probar ARM64, 16 KB memory pages, Android 16 / SDK de Stripe y Firebase en dispositivos o emuladores |
| Estado | No firmado ni subido todavía; recursos HD y validaciones pendientes |

## Recursos visuales — originales, no maquetas

- Ícono de Play: PNG `512 × 512` con logotipo original aprobado de TALA EATS (respetar colores, tipografía y marca).
- Gráfico principal: **`1024 × 500` JPEG o PNG de 24 bits sin transparencia**. Usar productos/fotos propios y el lettering real, sin logos inventados.
- Capturas: generar a partir de **una build real instalada** y flujos sin datos personales: Inicio/Buscar, ficha de negocio, carrito, checkout, seguimiento. No subir los *goldens* sintéticos de CI a Play como si fueran capturas reales.
- Antes de Play: faltan cuatro assets exactos para la app (`food_fiesta.webp`, `food_tala.webp`, `tala_eats_original_wordmark.png`, `tala_eats_wordmark_transparent.png`). La validación por hash no se desactiva.
- Crear únicamente materiales que muestren funciones reales de la versión final; no insertar promociones ficticias.

## Play Console — campos obligatorios por cerrar

- [ ] Registrar `com.talaeats.app` y elegir **Play App Signing**.
- [ ] Crear o reutilizar una **upload key** bajo resguardo; guardar respaldo cifrado. No subir `.jks`, `.p12`, JSON de servicio ni contraseñas a GitHub.
- [ ] Completar ficha es-MX y recursos oficiales originales.
- [ ] URL real pública **HTTPS** de Política de Privacidad y página de eliminación de cuenta; probar ambas con navegador externo.
- [ ] Declarar ubicación GPS, datos de registro, identificadores, notificaciones, fotos, pagos y retención reales en **Data Safety** y permisos.
- [ ] Verificar requisitos de acceso para revisión (cuenta demo segura en entorno de prueba si aplica), clasificación de contenido, público objetivo y anuncios reales.
- [ ] Confirmar `targetSdk 36` en artefacto final y compatibilidad de bibliotecas nativas con **16 KB**.
- [ ] QA en dispositivo Android real, backend Node **staging**, Stripe TEST y pruebas de pedido con tienda/repartidor. Sin cargos reales.
- [ ] Firma release local + verificación del AAB por el script; usar primero **Pruebas internas** en Play Console.
- [ ] Conservar hash SHA256, versión, commit y resultados de la pista interna antes de pedir publicación.

## Preparación local Windows (no se suben llaves)

Desde PowerShell, dentro de `tala-eats-usuarios`:

```powershell
.\ci\GENERAR-AAB-PLAY-WINDOWS.ps1 -SoloRevisar
# Al tener las cuatro imágenes originales, Firebase y entorno local listos:
.\ci\GENERAR-AAB-PLAY-WINDOWS.ps1
```

El asistente pide la clave de carga fuera del repo (o la genera con `keytool` mediante preguntas locales), pide las contraseñas ocultas y variables públicas Firebase, ejecuta `python ci/build_signed_play_bundle.py --build`, verifica estructura y firma y elimina las variables de sesión al terminar. No sube el paquete a Play.

**Archivo esperado una vez superados todos los gates:**
`tala-eats-usuarios/app/build/app/outputs/bundle/release/app-release.aab`.

Referencias oficiales:
- https://support.google.com/googleplay/android-developer/answer/9859152?hl=es-MX
- https://support.google.com/googleplay/android-developer/answer/9866151?hl=es
- https://support.google.com/googleplay/android-developer/answer/11926878?hl=es-mx
- https://developer.android.com/studio/publish/app-signing
- https://developer.android.com/guide/practices/page-sizes
