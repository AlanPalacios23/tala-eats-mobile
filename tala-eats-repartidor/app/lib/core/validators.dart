/// Validaciones locales compartidas por UI y controlador.
///
/// Son validaciones de FORMATO. La verificación real (credenciales, PIN del
/// cliente) corresponde al backend y se integrará después.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _pin = RegExp(r'^\d{4}$');

  static const int minPasswordLength = 8;
  static const int pinLength = 4;

  static bool isEmail(String raw) => _email.hasMatch(raw.trim());

  static bool isPassword(String raw) => raw.length >= minPasswordLength;

  static bool isPin(String raw) => _pin.hasMatch(raw.trim());

  static String? emailError(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Ingresa tu correo.';
    return isEmail(value) ? null : 'Revisa el formato del correo.';
  }

  static String? passwordError(String? raw) {
    final value = raw ?? '';
    if (value.isEmpty) return 'Ingresa tu contraseña.';
    if (!isPassword(value)) {
      return 'Debe tener al menos $minPasswordLength caracteres.';
    }
    return null;
  }
}
