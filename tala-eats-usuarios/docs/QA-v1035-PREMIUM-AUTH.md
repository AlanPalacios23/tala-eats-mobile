# TALA EATS Usuarios v1.0.35+46 — autenticación visual premium

## Alcance
Trabajar **solo** en `tala-eats-usuarios/app` partiendo de la rama QA previa (#36 y PRs apiladas). No fusionar ni desplegar en Kali.

## Cambios autorizados 17/oct/2026
- Reemplazar mosaico confuso de paneles traslúcidos por **hero fotográfico con degradado OSCURO local** (solo detrás del título blanco), más una única superficie blanca opaca, bordes superiores 28 px, formularios neutros y botón naranja principal.
- Mostrar fotos originales sin generar marca nueva: login `login_food.png`, registro/recuperación/restablecimiento `auth_secondary.jpg`. En el hero se aplica oscurecimiento suave **solo para la tipografía**, no una cortina blanca global.
- Mantener la jerarquía: título + subtítulo blanco sobre fotografía, formulario con inputs fondo gris muy claro y bordes sutiles, CTA único, enlaces legales discretos y funcionales sin cajas extras. Adapta altura del hero cuando teclado aparece, ScrollView, tamaño de texto ampliado y 320dp.
- Eliminar el **campo OTP/2FA del LOGIN DE USUARIOS** (correo y contraseña solamente). El modelo continúa usando el endpoint de autenticación vigente y OTP vacío por contrato, **sin cambiar backend ni deshabilitar 2FA de restaurante/ADMIN**, porque `backend/app/routes/auth.py` aún exige OTP a usuarios con `two_factor_enabled`. Para cuentas antiguas con 2FA obligatorio, mostrar mensaje de soporte, no simular autenticación ni desactivar validación.
- Registro endurece validación de formato de correo. Recuperación, contraseña, 2 enlaces legales, splash, pagos y carrito siguen existentes.
- Actualizar pruebas antiguas de OTP por controles que comprueban 2 campos y bloqueo de cuenta con 2FA habilitado. Nuevas pruebas de anchura mínima 320dp y texto 1.3.

## QA / pendientes
- CI: `flutter analyze`, suite Flutter, seguridad Android, APK debug efímera + integridad hash SHA256, HEAD exacto.
- Manual: confirmar legibilidad en Android físico, abrir enlaces legales, entrada desde cuenta Usuarios normal.
- **No afirmar recuperación SMTP completada**: backend issue #68 pendiente. **No afirmar Stripe E2E**: PaymentSheet necesita QA real. No usar pagos reales ni credenciales de producción.
