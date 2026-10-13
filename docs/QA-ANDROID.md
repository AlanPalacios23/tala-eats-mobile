# Tala Eats · QA Android (sin Windows)
 
**Alcance:** APKs **debug** generadas en GitHub Actions. No son versiones firmadas para distribución ni autorización para operar transacciones financieras reales.

## Descarga e instalación
1. Entra a **GitHub → tala-eats-mobile → Actions** y abre la ejecución cuyo trabajo de la app esté **success**.
2. En **Artifacts**, descarga `TalaEats-<rol>-debug-<número>`. El archivo descargado es un ZIP que contiene `app-debug.apk`.
3. Descarga el ZIP a Android, descomprímelo e instala la APK. Android puede requerir autorizar la instalación de APKs de esa fuente.
4. Guarda el número de ejecución, versión y dispositivo Android para cada prueba. Si se cambió firma o package ID, puede ser necesaria desinstalación; respalda antes los datos de prueba.

## Gates obligatorios antes de compartir una APK
- [ ] `flutter pub get` PASS
- [ ] `flutter analyze` PASS
- [ ] `flutter test` PASS
- [ ] `flutter build apk --debug` PASS
- [ ] Artefacto APK asociado al trabajo exitoso, no a uno fallido

## Pruebas manuales con cuentas de test

**Usuarios**
- [ ] Login, registro, recuperación, cerrar sesión
- [ ] Listado y menú desde API
- [ ] Carrito, tarifas vigentes (7 % con tope y envío por distancia) y total definitivo que devuelve el backend
- [ ] Permisos de GPS, dirección y estados sin red
- [ ] Checkout de prueba: **no realizar un cobro LIVE sin plan aprobado**

**Restaurante**
- [ ] Login, registro, recuperación y MFA si corresponde
- [ ] Alta de tienda, ubicación y horarios
- [ ] Productos, fotos y existencia
- [ ] Pedidos: aceptar, preparar y entregar, con estados reales
- [ ] Pantallas de saldos y retiros: verificar que no se muestren saldos inventados; no transferir dinero real
- [ ] Stripe Connect onboarding con modo/cuenta apropiada, sin credenciales en capturas o logs

**Repartidor**
- [ ] Registro, login y perfil
- [ ] GPS, permisos y reanudación en segundo plano
- [ ] Oferta de pedido, aceptación y navegación
- [ ] Estados recogida/entrega, evidencia de foto si aplica
- [ ] Historial, saldo, retiros y errores de conexión; evitar retiros reales

## Evidencia por prueba
Anotar: aplicación y versión, ID de ejecución GitHub, versión Android, pasos de reproducción, resultado esperado vs. observado, screenshot sin datos personales, red (Wi-Fi/datos), y hora.

## Seguridad
No incluir en commits, artifacts ni screenshots claves de firma, tokens, secretos de Stripe, credenciales reales, códigos 2FA ni datos bancarios. QA se hace con identidades de prueba. El backend Kali productivo **no se modifica ni se despliega** desde este repositorio.

## Criterio de salida
Una APK de prueba está **compilada** al pasar CI; solo es **candidata a producción** cuando pasa QA en un dispositivo real, pruebas de integración con API, revisión de seguridad, firma release y validación de distribución.
