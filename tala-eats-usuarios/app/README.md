# Tala Eats Usuarios Android v1.0.12

Frontend Cliente producción/no-demo. Package: `com.talaeats.app`.

Pagos soportados por contrato servidor:
- Efectivo
- Mercado Pago
- Stripe PaymentSheet (tarjeta + Google Pay en Android; Apple Pay preparado para iOS)

Dependencia Stripe fijada: `flutter_stripe: 14.1.0`.

Build config:
`--dart-define=TALAEATS_API_BASE_URL=https://talaeats.alan-palacios-dev.com/api/v1`

El script USB ejecuta format, scaffold Android compatible con Stripe, pub get, analyze, tests, build e instalación ADB.
