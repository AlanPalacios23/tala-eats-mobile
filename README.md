# TALA EATS — apps móviles Flutter

Repositorio **privado** para las aplicaciones Android/iOS de **Usuarios**, **Restaurante** y **Repartidor**.

| Aplicación | Directorio | Versión inicial |
|---|---|---|
| Usuarios | `tala-eats-usuarios/app/` | `1.0.19` |
| Restaurante | `tala-eats-restaurante/app/` | `0.7.6` |
| Repartidor | `tala-eats-repartidor/app/` | `1.2.7` |

## Compilación automática

En **Actions** ejecuta el flujo **TALA EATS · Android CI & APK**. Cada cambio en `main` verifica las tres apps en Ubuntu + Flutter 3.47.6, ejecuta `flutter pub get`, análisis estático, pruebas y genera una APK **debug** descargable cuando todo pasa. Si falla, descarga el artefacto `diagnostico` correspondiente para ver los logs; no se marcará como aprobada una APK que no haya superado los pasos.

La importación inicial desde partes compactadas la realiza el mismo flujo en un commit adicional. Este diseño permite que los archivos fuente se mantengan legibles/editables en el repositorio, en vez de depender de scripts `.cmd` de Windows.

**Seguridad:** no incluir `.env`, claves de firma, credenciales de Stripe, TOTP, contraseñas ni tokens. Los builds debug no están listos para Google Play. Este CI no modifica el backend de Kali ni el servidor de producción.

**Estado:** código preparado desde nuestros ZIP de Biblioteca; un resultado PASS solo existe cuando GitHub Actions lo confirma.