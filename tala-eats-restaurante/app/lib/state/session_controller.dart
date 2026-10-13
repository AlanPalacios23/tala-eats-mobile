import 'package:flutter/foundation.dart';

import '../core/failures.dart';
import '../data/app_services.dart';
import '../models/entities.dart';

enum SessionStatus {
  booting,
  welcome,
  signedOut,
  pendingApproval,
  securitySetup,
  signedIn,
}

class SessionController extends ChangeNotifier {
  SessionController(this.services);

  final AppServices services;

  SessionStatus status = SessionStatus.booting;
  UserSession? user;
  UserSession? _pendingUser;
  OnboardingApplication? onboardingApplication;
  TwoFactorSetup? twoFactorSetup;
  AppFailure? securityFailure;
  bool securityLoading = false;
  bool approvalRefreshing = false;
  bool _disposed = false;

  Future<void> bootstrap() async {
    try {
      final setup = await services.onboarding.isSetupComplete();
      final restored = await services.auth.restoreSession();
      if (restored != null) {
        final failure = await _routeUser(restored);
        if (failure != null) {
          status = setup ? SessionStatus.signedOut : SessionStatus.welcome;
        }
      } else {
        status = setup ? SessionStatus.signedOut : SessionStatus.welcome;
      }
    } catch (_) {
      status = SessionStatus.signedOut;
    }
    _notify();
  }

  Future<AppFailure?> signIn(
    String email,
    String password, {
    String otp = '',
  }) async {
    try {
      final session = await services.auth.signIn(
        email: email,
        password: password,
        otp: otp,
      );
      final failure = await _routeUser(session);
      _notify();
      return failure;
    } catch (error) {
      return AppFailure.from(error);
    }
  }

  Future<AppFailure?> _routeUser(UserSession session) async {
    user = session;
    if (session.role == 'owner') {
      status = SessionStatus.signedIn;
      return null;
    }
    if (session.role == 'restaurant') {
      if (!session.twoFactorEnabled) {
        status = SessionStatus.securitySetup;
        return null;
      }
      try {
        await services.onboarding.syncPendingProductIfNeeded();
      } catch (_) {
        // El panel puede abrir aunque falle la sincronización del borrador; el
        // menú puede reintentarse manualmente sin bloquear la sesión.
      }
      status = SessionStatus.signedIn;
      onboardingApplication = null;
      return null;
    }

    final application = await services.onboarding.latestApplication();
    onboardingApplication = application;
    if (application != null &&
        <String>{'pending', 'needs_info', 'approved', 'rejected', 'suspended'}
            .contains(application.status)) {
      status = SessionStatus.pendingApproval;
      return null;
    }

    user = null;
    status = SessionStatus.signedOut;
    return const AppFailure(
      FailureKind.permissionDenied,
      'Esta cuenta todavía no tiene un restaurante asociado. Usa “Crear mi restaurante”.',
    );
  }

  Future<AppFailure?> createRestaurant(OnboardingDraft draft) async {
    try {
      _pendingUser = await services.onboarding.createRestaurant(draft);
      onboardingApplication = await services.onboarding.latestApplication();
      return null;
    } catch (error) {
      return AppFailure.from(error);
    }
  }

  /// Se llama desde la confirmación del onboarding. En producción no abre el
  /// panel todavía: muestra el estado de revisión hasta aprobación ADMIN.
  void enterPanel() {
    final pending = _pendingUser;
    if (pending == null) return;
    _pendingUser = null;
    user = pending;
    if (pending.role == 'owner') {
      status = SessionStatus.signedIn;
    } else if (pending.role == 'restaurant') {
      status = pending.twoFactorEnabled
          ? SessionStatus.signedIn
          : SessionStatus.securitySetup;
    } else {
      status = SessionStatus.pendingApproval;
    }
    _notify();
  }

  Future<AppFailure?> refreshApproval() async {
    if (approvalRefreshing) return null;
    approvalRefreshing = true;
    _notify();
    try {
      final current = await services.auth.restoreSession();
      if (current == null) {
        status = SessionStatus.signedOut;
        return const AppFailure(FailureKind.sessionExpired);
      }
      return await _routeUser(current);
    } catch (error) {
      return AppFailure.from(error);
    } finally {
      approvalRefreshing = false;
      _notify();
    }
  }

  Future<AppFailure?> loadTwoFactorSetup() async {
    if (securityLoading || twoFactorSetup != null) return null;
    securityLoading = true;
    securityFailure = null;
    _notify();
    try {
      twoFactorSetup = await services.auth.beginTwoFactorSetup();
      return null;
    } catch (error) {
      final failure = AppFailure.from(error);
      securityFailure = failure;
      return failure;
    } finally {
      securityLoading = false;
      _notify();
    }
  }

  Future<AppFailure?> confirmTwoFactor(String code) async {
    if (securityLoading) return null;
    securityLoading = true;
    securityFailure = null;
    _notify();
    try {
      final session = await services.auth.confirmTwoFactor(code);
      user = session;
      await services.onboarding.syncPendingProductIfNeeded();
      status = SessionStatus.signedIn;
      twoFactorSetup = null;
      return null;
    } catch (error) {
      final failure = AppFailure.from(error);
      securityFailure = failure;
      return failure;
    } finally {
      securityLoading = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    try {
      await services.auth.signOut();
    } catch (_) {}
    user = null;
    onboardingApplication = null;
    twoFactorSetup = null;
    status = SessionStatus.signedOut;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
