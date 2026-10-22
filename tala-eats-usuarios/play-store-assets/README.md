# Tala Eats Usuarios · material HD de Google Play (RC4)

Esta carpeta es el destino de los **gráficos originales de la ficha de
Google Play**. No confundir con `app/assets/landing/`, que contiene el
splash, dos fotografías oficiales y el lettering que verá el cliente al
abrir la aplicación.

## Archivos requeridos antes de publicar

| Nombre obligatorio | Formato / calidad |
|---|---|
| `icon-512.png` | PNG real 512 × 512 px, ícono original aprobado |
| `feature-1024x500.png` | PNG RGB 1024 × 500 px, sin transparencia, fotografía/identidad aprobada |
| `screenshots/01-home.png` | Captura PNG auténtica de la app instalada |
| `screenshots/02-buscar.png` | Captura PNG auténtica de la app instalada |
| `screenshots/03-comercio.png` | Recomendado, negocio real y datos autorizados |
| `screenshots/04-carrito.png` | Recomendado, precios reales de ambiente de demostración |
| `screenshots/05-checkout.png` | Recomendado, no mostrar credenciales ni datos de pago |
| `screenshots/06-pedidos.png` | Recomendado, identificadores ficticios de ambiente de pruebas |

Las capturas deben medir entre 320 y 3840 px por eje y respetar las
proporciones de Google Play; preferir **1080 × 1920 px** si se obtienen
de dispositivos reales con un flujo compatible. El validador acepta
2–8 capturas. No publicar los «goldens» sintéticos del pipeline como
si fueran pantallas reales de producción.

Usar exclusivamente logotipo, fotografías y UI verificados de Tala Eats.
No inventar promociones, restaurantes, tiempos de entrega ni reseñas.

## Validación local

```powershell
cd tala-eats-usuarios
python ci/verify_landing_assets.py
python ci/verify_play_store_media.py --check
```

El validador de medios Play comprueba que los PNG sean íntegros (estructura
y CRC), tamaño, color RGB del feature sin alpha y cantidad/relación de
capturas. No sustituye inspección humana del material, requisitos vigentes
de Play Console ni pruebas con un APK real.

**Archivos originales aún pendientes:** ninguno de los anteriores fue
generado ni agregado automáticamente. Se deben aportar y aprobar antes
de la publicación. No guardar upload key, contraseñas, JSON de servicio
Firebase, token o claves de Stripe en esta carpeta.
