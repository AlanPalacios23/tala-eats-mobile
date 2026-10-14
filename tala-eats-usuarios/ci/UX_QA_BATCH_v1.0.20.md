# TALA EATS Usuarios v1.0.20 — lote UI pendiente de QA

**Estado:** fuentes guardadas en rama `feature/usuarios-v1020-chat-repartidor-ui`. PR #11 en borrador. **No se ha ejecutado `flutter pub get`, `flutter analyze`, `flutter test` ni compilado APK para este lote reciente**, a petición del propietario para ahorrar minutos de GitHub Actions.

## Integración y propósito

1. Inicio: lista de comercios auténticos, acceso compacto a pedido activo; excluye pagos digitales pendientes.
2. Buscar: explorar sin texto, filtros Todos/Abiertos/Entrega/Recoger/Favoritos, búsqueda acento-insensible, estados vacíos/conexión.
3. Restaurante: fotografía de negocio, estado actual, menú actualizado deslizando, categorías, precio/stock siempre sujetos al servidor.
4. Producto: imagen real o fallback identificado, indicaciones libres (160 caracteres), cantidad 1-99, bloqueo de doble tap, prevenir agregar ficha obsoleta.
5. Carrito: notas distintas del mismo producto en líneas separadas; no reemplazar carrito al intentar agregar desde comercio cerrado.
6. Pago: separar métodos habilitados, mostrar importes de referencia y no cobro definitivo antes de servidor, requerir dirección con GPS válido para entrega, manejar incertidumbre de confirmación sin animar a repetir un pedido.
7. Pedidos: separar pendientes de pago, en curso y anteriores; mensaje de no preparación antes de pago; estado de pago accesible.
8. Seguimiento: mapa OSM con origen de datos en `/v11/orders/{id}/live`, marcador de driver real y destino, nunca GPS ficticio, sin geocodificar coordenadas inventadas. Polling solo mientras app en foreground; pantalla sin conductor muestra estado de espera. Copia «Actualización periódica», no «GPS en tiempo real garantizado».
9. Cuenta: acceso a Mis pedidos y versión de app actual; insignia accesible en barra inferior.
10. Chat: previsualización de chat privado tras asignación, envío desactivado hasta backend autorizado, sin reutilizar chat general restaurante/cliente.

## Gate manual cuando se acuerde cerrar lote

- Ejecutar **manualmente** `Tala Eats | Usuarios QA y APK (solo manual)` en rama feature o `Tala Eats | APK Android (solo manual)`, opción `usuarios`. No activar el trigger push/PR. Verificar que el checkout de Actions usa la rama feature y no main.
- Validar `flutter pub get`, `flutter analyze --no-fatal-infos`, `flutter test`, `flutter build apk --debug`; no publicar APK de producción ni firmar con secretos.
- Revisar tests nuevos: `driver_chat_ui_test.dart`, `discovery_refinement_test.dart`, `product_detail_polish_test.dart`, `live_delivery_map_test.dart`, `general_ux_polish_test.dart`, y `widget_smoke_test.dart`.
- Probar Android 320/360/390/430dp, fuente 1.0x y 1.3x, Reduce Motion, TalkBack, teclado abierto/cerrado y SafeAreas.
- Confirmar navegación: Inicio → Buscar → Restaurante → Producto → Carrito → Checkout → confirmación → seguimiento; regresar sin perder carrito o notas.
- GPS: sin coordenadas, sin driver asignado, GPS inválido/caducado, pago pendiente, pedido cancelado/finalizado, reasignación y app foreground/background; mapa no muestra ruta ficticia ni revela posición después de terminar.
- Comprobar acceso a tiles HTTPS, atribución y uso aceptable del proveedor de mapas. Seleccionar proveedor de teselas apropiado para crecimiento, con caché y términos compatibles.
- Simular fallo de conectividad antes y después de envío de pedido, verificar Idempotency-key/client_reference del servidor antes de reintentos manuales; nunca hacer pruebas de pedido en Stripe LIVE.
- Verificar que ningún cambio toca producción Kali, Stripe, backends, contenedores, DNS ni aplicaciones Restaurante/Repartidor.

**No fusionar PR #11 hasta tests PASS y revisión de seguridad/precios/seguimiento**. Contrato futuro GPS fresco del backend: issue [#22](https://github.com/AlanPalacios23/AlanPalacios23-tala-eats-backend/issues/22). Chat privado: issue #10 de repo mobile.
