import 'dart:io';
import 'package:flutter/services.dart';

/// Errores de dominio/presentación.
///
/// Las implementaciones de repositorio (locales hoy, remotas después) deben
/// traducir cualquier excepción técnica a [AppFailure]. La UI solo muestra
/// [AppFailure.message]; nunca imprime excepciones crudas.
enum FailureKind {
  offline,
  timeout,
  server,
  invalidCredentials,
  twoFactorRequired,
  twoFactorSetupRequired,
  sessionExpired,
  validation,
  conflict,
  notFound,
  permissionDenied,
  media,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure(this.kind, [this.detail]);

  final FailureKind kind;

  /// Mensaje de producto opcional (por ejemplo, validación del servidor ya
  /// traducida). Si es nulo se usa el mensaje estándar del [kind].
  final String? detail;

  bool get isConnectivity =>
      kind == FailureKind.offline || kind == FailureKind.timeout;

  bool get isRetryable =>
      isConnectivity || kind == FailureKind.server || kind == FailureKind.unknown;

  String get title {
    switch (kind) {
      case FailureKind.offline:
        return 'Sin conexión';
      case FailureKind.timeout:
        return 'La conexión está lenta';
      case FailureKind.server:
        return 'No pudimos cargar la información';
      case FailureKind.invalidCredentials:
        return 'Correo o contraseña incorrectos';
      case FailureKind.twoFactorRequired:
        return 'Verificación en dos pasos';
      case FailureKind.twoFactorSetupRequired:
        return 'Activa la verificación en dos pasos';
      case FailureKind.sessionExpired:
        return 'Tu sesión terminó';
      case FailureKind.validation:
        return 'Revisa los datos';
      case FailureKind.conflict:
        return 'Este cambio ya no aplica';
      case FailureKind.notFound:
        return 'No encontramos este elemento';
      case FailureKind.permissionDenied:
        return 'Permiso necesario';
      case FailureKind.media:
        return 'No pudimos usar esa foto';
      case FailureKind.unknown:
        return 'No pudimos completar la operación';
    }
  }

  String get message {
    final custom = detail;
    if (custom != null && custom.trim().isNotEmpty) return custom;
    switch (kind) {
      case FailureKind.offline:
        return 'Revisa tu internet. Mostramos la última información disponible.';
      case FailureKind.timeout:
        return 'La respuesta tardó demasiado. Intenta de nuevo.';
      case FailureKind.server:
        return 'El servicio no respondió como esperábamos. Intenta de nuevo en un momento.';
      case FailureKind.invalidCredentials:
        return 'Verifica tu correo y contraseña e inténtalo otra vez.';
      case FailureKind.twoFactorRequired:
        return 'Escribe el código de 6 dígitos de tu autenticador.';
      case FailureKind.twoFactorSetupRequired:
        return 'Por seguridad, las cuentas de restaurante deben activar 2FA antes de operar.';
      case FailureKind.sessionExpired:
        return 'Inicia sesión de nuevo para continuar.';
      case FailureKind.validation:
        return 'Algunos datos no son válidos. Corrígelos y vuelve a intentar.';
      case FailureKind.conflict:
        return 'Otra persona actualizó este pedido. Actualiza para ver su estado.';
      case FailureKind.notFound:
        return 'Puede que se haya eliminado. Actualiza la lista.';
      case FailureKind.permissionDenied:
        return 'Activa el permiso en los ajustes de Android para continuar.';
      case FailureKind.media:
        return 'Elige una imagen en formato JPG, PNG o WEBP.';
      case FailureKind.unknown:
        return 'No se pudo completar la solicitud. Verifica la conexión y vuelve a intentarlo.';
    }
  }

  /// Envuelve cualquier error en un [AppFailure] sin exponer detalles técnicos.
  static AppFailure from(Object error) {
    if (error is AppFailure) return error;
    if (error is TlsException) {
      return const AppFailure(FailureKind.offline,
          'No se pudo establecer una conexión HTTPS segura con Tala Eats.');
    }
    if (error is SocketException) return const AppFailure(FailureKind.offline);
    if (error is PlatformException || error is MissingPluginException) {
      return const AppFailure(FailureKind.unknown,
          'Una función local de Android no respondió. La información del negocio se consulta en el servidor. Intenta de nuevo.');
    }
    return const AppFailure(FailureKind.unknown);
  }

  @override
  String toString() => 'AppFailure($kind)';
}
