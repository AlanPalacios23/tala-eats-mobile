# TALA EATS Usuarios · v1.0.33+44 · tres pantallas originales

Los cuatro recursos se incluyen en el paquete de este cambio, pero **no
están todavía en la rama**. Extraer el ZIP v1.0.33 en la raíz del repositorio
sin renombrar archivos, validar con el gate y confirmar en un commit de GitHub.

## Recursos obligatorios
- `tala_eats_original_wordmark.png`: logotipo y eslogan de la pantalla splash blanca, conservando la identidad ya aprobada.
- `food_tala.webp`: **imagen B**, mesa verde con comida, se muestra SOLAMENTE en bienvenida.
- `tala_eats_wordmark_transparent.png`: lettering naranja-rosa recortado SIN fondo blanco, sombras ni tarjeta; se superpone sobre la imagen B.
- `food_fiesta.webp`: **imagen A**, fondo colorido, se muestra SOLO en selector de ingreso.

## Flujo validable
Splash con entrada y salida animadas -> Bienvenida fija imagen B,
título alineado a la izquierda y CTA Liquid Glass -> Selector imagen A,
sin texto central, con botones Google, celular y correo.

El botón **correo** abre la autenticación real ya integrada.
Los botones de Google y celular ofrecen mensaje no habilitado y acción
para continuar por correo. Habilitar OAuth/OIDC y verificación telefónica
requiere contrato real, configuración de proveedor y pruebas de seguridad.

## QA
`python3 tala-eats-usuarios/ci/verify_landing_assets.py`
debe decir `4/4 PASS`. Si falta una imagen no se debe fusionar
ni preparar AAB. El login no debe falsificar autenticación.
