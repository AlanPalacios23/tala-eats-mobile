# QA — Tala Eats Usuarios Android v1.0.12

## Correcciones v1.0.12
- Auth responsive: el CTA de registro usa Wrap y no fuerza overflow horizontal.
- PasswordRequirements: encabezado flexible con Expanded/Flexible.
- Tests de checkout desplazan el ListView hasta la sección Pago antes de validar métodos.
- Se conservan Efectivo, Mercado Pago y Stripe/Google Pay/Apple Pay según contrato del backend.
- `flutter analyze` y `flutter test` deben ejecutarse en el gate local antes del APK.

## Gate requerido
`dart format` → `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk` → ADB install.
