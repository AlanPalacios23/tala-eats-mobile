# TALA EATS Usuarios — Fase 2: intento de compra cifrado tras cierre forzoso

**Alcance:** código candidato de la app Usuarios. No supone que el backend
`GET /orders/by-reference/{client_reference}` esté ya instalado en Kali.

## Garantía ofrecida por la rama

- Una compra lógica tiene un cuerpo JSON congelado y una
  `client_reference` aleatoria. El journal de cuenta se **escribe de forma
  síncrona** en almacenamiento cifrado AES-256/GCM AndroidKeyStore
  **ANTES** de emitir `POST /orders`, con AAD ligado a `userId`.
- Si falla AndroidKeyStore, el cifrado, el `commit()` en disco o la lectura
  de journal, se bloquea el pedido (fail closed). No hay fallback a texto
  claro ni generación de otra referencia.
- El proceso puede cerrarse y abrirse otra vez: otro
  `OrderSubmissionGuard` para el mismo `userId` lee el intento y
  reintenta exclusivamente el **mismo JSON y la misma referencia**.
  Si el usuario cambió carrito/dirección, devuelve 409 sin POST.
- En arranque, login y registro, se consulta de forma autenticada
  `GET /orders/by-reference/{client_reference}`. Un resultado
  `200` con `user_id` y referencia idénticos resuelve el journal y
  recupera el pedido sin crear compra; `404` lo conserva porque
  todavía puede haber procesamiento asincrónico del lado servidor.
- Las cuentas usan keys cifradas separadas `pending_order_v1_<uid>`.
  Cerrar sesión invalida la sesión en memoria pero NO destruye
  evidencia de un POST ambiguo perteneciente a esa cuenta.
- No reintenta automáticamente un POST al recuperar login. Únicamente
  un nuevo intento de compra del usuario con el payload idéntico
  puede activar reintento de la compra original.

## Límite operativo

La app no garantiza un resultado si el almacenamiento nativo está
corrupto o la clave Keystore se pierde: bloqueará nuevas compras
relacionadas hasta soporte. Si el backend REAL aún no tiene la ruta
de búsqueda (PR backend #64 está en GitHub, no certificada en Kali),
la lectura puede devolver 404; la referencia permanece cifrada.

CI ejecuta Flutter analyze, pruebas de doble toque, reintento, proceso
reiniciado, error de escritura, aislamiento entre usuarios, recuperación
404/200, y compilación Android *debug efímera* sin distribuir APK.

**No cerrar F2.07 principal** sin Stripe TEST/MP sandbox, APK física,
probado en Android real bajo kills forzosos, conectividad real con Kali,
y confirmación de GET por referencia en el despliegue autorizado.
**Nunca activar pagos LIVE con este resultado.**
