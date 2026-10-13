import '../../core/failures.dart';

/// Escenarios de QA para inspeccionar estados sin exponer UI de depuración.
///
/// Se activan solo al compilar con:
/// `flutter run --dart-define=TALA_QA_SCENARIO=<valor>`
///
/// - `empty`        → sin pedidos, sin movimientos ni equipo.
/// - `error`        → la primera carga de cada sección falla (error + reintentar).
/// - `offline`      → la primera carga falla por conexión (estado sin conexión).
/// - `slow`         → latencia alta para revisar skeletons.
/// - `login_error`  → el primer inicio de sesión falla por credenciales.
/// - `action_error` → la primera acción sobre un pedido/producto falla.
enum QaScenario { normal, empty, error, offline, slow, loginError, actionError }

const String _rawScenario = String.fromEnvironment('TALA_QA_SCENARIO');

QaScenario get configuredQaScenario {
  switch (_rawScenario.trim().toLowerCase()) {
    case 'empty':
      return QaScenario.empty;
    case 'error':
      return QaScenario.error;
    case 'offline':
      return QaScenario.offline;
    case 'slow':
      return QaScenario.slow;
    case 'login_error':
      return QaScenario.loginError;
    case 'action_error':
      return QaScenario.actionError;
    default:
      return QaScenario.normal;
  }
}

/// Latencias simuladas: la implementación real será asíncrona, así que la UI
/// siempre debe mostrar sus estados intermedios.
class LocalLatency {
  const LocalLatency({required this.read, required this.write});

  const LocalLatency.standard()
      : read = const Duration(milliseconds: 650),
        write = const Duration(milliseconds: 520);

  const LocalLatency.none()
      : read = Duration.zero,
        write = Duration.zero;

  const LocalLatency.slow()
      : read = const Duration(milliseconds: 3200),
        write = const Duration(milliseconds: 1600);

  final Duration read;
  final Duration write;
}

/// Inyecta fallas "una sola vez" por clave según el escenario.
class QaFaults {
  QaFaults(this.scenario);

  final QaScenario scenario;
  final Set<String> _consumed = <String>{};

  bool get isEmpty => scenario == QaScenario.empty;

  void onRead(String key) {
    if (scenario == QaScenario.error && _consumed.add('read:$key')) {
      throw const AppFailure(FailureKind.server);
    }
    if (scenario == QaScenario.offline && _consumed.add('read:$key')) {
      throw const AppFailure(FailureKind.offline);
    }
  }

  void onSignIn() {
    if (scenario == QaScenario.loginError && _consumed.add('signin')) {
      throw const AppFailure(FailureKind.invalidCredentials);
    }
  }

  void onAction(String key) {
    if (scenario == QaScenario.actionError && _consumed.add('action:$key')) {
      throw const AppFailure(FailureKind.timeout);
    }
  }
}
