# Tala Eats Usuarios · RC3 v1.0.40+51 · experiencia de entrada y soporte

Estado: **rama de desarrollo, NO PUBLICAR**. Base PR #53 → #52 → #51 → #50 → #49. Se conservan Stripe/efectivo controlados por backend, package `com.talaeats.app`, firma local pendiente y el gate de cuatro fotos/wordmarks originales HD.

## Incluido en la RC3

- Splash oficial blanco con lettering original y un indicador real **indeterminado** de preparación; sin porcentajes ficticios. Se conserva la transición actual y Reduce Motion.
- Pantalla fotográfica de métodos de acceso: correo electrónico y acción directa **Crear cuenta**, sin inventar Google OAuth ni SMS.
- Registro e inicio de sesión progresivos: teclados `next/done` y estado accesible «Validando…» durante llamadas API; respetar doble-submit guard existente.
- Soporte reformulado como **bandeja visual tipo chat**, no como WhatsApp falso: `GET /platform/support` consulta casos del usuario; cada burbuja es su mensaje almacenado y muestra referencia real de ticket + estado. `POST /platform/support` crea una solicitud con categoría, pedido opcional y texto de 5–3000 caracteres; solo se agrega al historial tras confirmación del servidor.
- Categorías: General, Pedido, Pago, Cuenta, Reembolso y Otro. El historial contextual desde pedido muestra solo las solicitudes asociadas a ese pedido.
- Pantalla con carga, error, refrescar, preguntas frecuentes, borrador conservado en fallos, y aviso explícito del límite de comunicación.

## Importante: alcance real del soporte

El backend Python estudiado expone `GET /platform/support` y `POST /platform/support`, modelo `SupportPublic` con `id, order_id, category, message, status, created_at`. **No se ha probado que el backend Node desplegado ofrezca estos mismos contratos**. Por tanto, la interfaz debe operar solo cuando Node STAGING responda correctamente y mostrar error honesto si no.

**Este no es aún un chat bidireccional entre cliente y agente.** Las respuestas de agentes, adjuntos y tiempo real requieren contratos nuevos verificados con backend y ADMIN. No simular `typing…`, respuesta automática de bot ni burbujas de soporte no persistidas.

### Contrato para completar chat real en la próxima integración backend + ADMIN

1. `GET /platform/support`: listado paginado de los casos del **cliente autenticado**, estado real y orden asociado.
2. `POST /platform/support`: creación idempotente de caso con category, optional order_id y primera entrada.
3. `GET /platform/support/{ticket_id}/messages`: mensajes paginados, `id, sender_role, body, created_at, attachment` sujeto a permisos. Sin acceso a tickets de otros usuarios.
4. `POST /platform/support/{ticket_id}/messages`: validar titularidad de ticket, longitud y permisos. Evitar duplicados en reintentos con `client_message_id`.
5. ADMIN: asignar ticket, responder, cambiar estado, consultar historial y auditar modificaciones. Repartidor/Restaurante sin acceso cruzado.
6. Notificaciones opcionales bajo consentimiento, SSE/WebSocket o polling con backoff para mensajes nuevos, reconexión y errores sin pérdidas.
7. Auditoría, retención/privacidad, límites de tamaño, controles anti-spam, datos sensibles y URL privada para futuros adjuntos.

### Matriz QA

- [x] Tests Flutter falsos para GET real modelado, POST aceptado, error 503 sin burbuja ni pérdida de borrador, contexto de pedido y exclusión de mensajes de agentes ficticios.
- [x] Test Flutter de accesibilidad de splash en 320 dp y entrada directa a Crear cuenta.
- [ ] Ejecutar CI completo, Android debug y pruebas en teléfono con foco, teclado y TalkBack.
- [ ] Contrato GET/POST con backend Node STAGING y posterior ADMIN (sin mutar producción).
- [ ] Integración chat verdadero con respuestas del agente requiere los endpoints arriba.
- [ ] Play AAB firmado local: pendiente upload key y cuatro medios HD originales; NO pasar a pista interna hasta validarlo.

## Siguientes pantallas a armonizar

En el siguiente incremento: Home y Buscar (skeletons y estados vacíos), fichas de restaurante y productos, carrito y pedidos/seguimiento, direcciones y perfil. Mantener la versión actual limpia: comercios reales del backend, sin banners, restaurantes inventados, estadísticas falsas, descuentos o tracking ficticio.

## Criterio GO

Todas las pruebas y funciones reales + APIs de Node STAGING comprobadas + soporte ADMIN operativo + imágenes HD originales + 16 KB/SDK 36 + AAB firmado y validado por Play Console. Mientras tanto **NO-GO**.
