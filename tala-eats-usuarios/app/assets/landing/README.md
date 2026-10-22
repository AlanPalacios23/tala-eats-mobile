# TALA EATS Usuarios · originales gráficos HD (RC4)

**Estado real:** a 22/oct/2026, los cuatro archivos originales NO están en GitHub.
La app compilada DEBUG puede mostrar el fallback de texto/fondo. Esos
fallbacks NO son el material aprobado para Google Play ni para producción.

El original del dueño de la marca debe llegar en un ZIP local. La app reserva
estos nombres exactos:

| Archivo | Pantalla |
|---|---|
| `tala_eats_original_wordmark.png` | Splash blanco oficial |
| `food_tala.webp` | Foto B original, bienvenida |
| `tala_eats_wordmark_transparent.png` | Lettering original sobre foto B |
| `food_fiesta.webp` | Foto A original, selector de ingreso |

No intercambiar las fotos A/B, agregar logos inventados ni modificar la
tipografía, colores, transparencia o SHA256 de los originales.

## Importación segura desde el ZIP en Windows

Abrir PowerShell en `tala-eats-usuarios` y sustituir la ruta por la del ZIP
que realmente contiene los originales, aprobado por el dueño.

```powershell
python ci/import_original_hd_assets.py --zip "C:\\MisArchivos\\TalaEats-HD-ORIGINAL.zip" --check
python ci/import_original_hd_assets.py --zip "C:\\MisArchivos\\TalaEats-HD-ORIGINAL.zip" --install
python ci/verify_landing_assets.py
```

`--check` no modifica nada; `--install` **solo copia los cuatro archivos**
si **todos** cumplen sus SHA256 ya fijados en
`ci/verify_landing_assets.py`. Se rechazan ZIP incompletos, repetidos,
sustituciones, symlinks, archivos enormes y rutas no seguras. No hay
conversión, recomprensión ni cambios de bytes.

Después de comprobar visualmente las cuatro pantallas en el APK:
incorporar los cuatro binarios a una rama de PR, nunca las claves de firma,
y ejecutar GitHub Actions. La verificación de originales debe quedar
`4/4 PASS`.

## Material de la ficha de Google Play

El ícono para Google Play, la imagen promocional y las capturas de pantallas
**son recursos distintos** de los cuatro binarios integrados a la app.
Seguir `../../../play-store-assets/README.md` y ejecutar:

```powershell
python ci/verify_play_store_media.py --check
```

No utilizar capturas de CI con información simulada para afirmar que son
capturas del producto final. Deben salir de una compilación real en dispositivo.
