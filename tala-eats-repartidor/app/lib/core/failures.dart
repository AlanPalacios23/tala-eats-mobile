enum FailureKind {
  offline,
  timeout,
  invalidCredentials,
  twoFactorRequired,
  sessionExpired,
  permissionDenied,
  notFound,
  conflict,
  validation,
  media,
  server,
  unknown,
}

class AppFailure implements Exception {
  const AppFailure(this.kind, [this.message = '']);

  final FailureKind kind;
  final String message;

  static AppFailure from(Object error) {
    if (error is AppFailure) return error;
    return const AppFailure(FailureKind.unknown);
  }

  @override
  String toString() => 'AppFailure(${kind.name}, $message)';
}
