import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/driver_backend.dart';
import '../models/delivery.dart';
import '../models/driver_profile.dart';
import '../services/location_service.dart';
import 'failures.dart';
import 'mock_data.dart';
import 'validators.dart';

enum LoadStatus { ready, loading, error }

enum ProofResult { completed, invalidPin, missingEvidence, wrongStage, failed }

const int kTabCount = 4;

/// Estado único de Tala Eats Repartidor.
///
/// [DriverController.production] consume Backend v1.6.0. El constructor normal
/// conserva datos locales solamente para tests y previews controlados.
class DriverController extends ChangeNotifier {
  DriverController({
    DateTime Function()? clock,
    Duration bootDelay = const Duration(milliseconds: 420),
    Duration authDelay = const Duration(milliseconds: 650),
    Duration refreshDelay = const Duration(milliseconds: 700),
  }) : this.withData(
          clock: clock,
          bootDelay: bootDelay,
          authDelay: authDelay,
          refreshDelay: refreshDelay,
          profile: MockData.profile,
          active: MockData.activeJob,
          history: MockData.history((clock ?? DateTime.now)()),
          weekEarnings: MockData.weekEarnings,
          onlineMinutesToday: MockData.onlineMinutesToday,
          acceptance: MockData.acceptance,
        );

  DriverController.production({
    DateTime Function()? clock,
    DriverBackend? backend,
    LocationService? location,
  })  : _clock = clock ?? DateTime.now,
        bootDelay = Duration.zero,
        authDelay = Duration.zero,
        refreshDelay = Duration.zero,
        _backend = backend ?? DriverBackend(),
        _location = location ?? LocationService(),
        _profile = const DriverProfile(
          firstName: 'Repartidor',
          fullName: 'Repartidor',
          zone: 'Tala, Jalisco',
          vehicleType: 'Motocicleta',
          plateSuffix: '—',
          verified: false,
          documents: <DriverDocument>[],
        ),
        _active = null,
        _history = <DeliveryJob>[],
        _weekEarnings = List<double>.filled(7, 0),
        _onlineMinutesToday = 0,
        _acceptance = 0;

  DriverController.withData({
    DateTime Function()? clock,
    this.bootDelay = const Duration(milliseconds: 420),
    this.authDelay = const Duration(milliseconds: 650),
    this.refreshDelay = const Duration(milliseconds: 700),
    required DriverProfile profile,
    DeliveryJob? active,
    List<DeliveryJob> history = const [],
    List<double> weekEarnings = const [0, 0, 0, 0, 0, 0, 0],
    int onlineMinutesToday = 0,
    int acceptance = 0,
  })  : assert(weekEarnings.length == 7, 'weekEarnings: lunes a domingo'),
        _backend = null,
        _location = null,
        _clock = clock ?? DateTime.now,
        _profile = profile,
        _active = active,
        _history = List<DeliveryJob>.of(history),
        _weekEarnings = List<double>.of(weekEarnings),
        _onlineMinutesToday = onlineMinutesToday,
        _acceptance = acceptance {
    for (final job in _history) {
      _creditedDeliveries.add(job.id);
      _todayEarnings += job.earning;
      _todayDeliveries += 1;
      _todayKm += job.distanceKm;
      _todayOrdersTotal += job.total;
    }
  }

  final DateTime Function() _clock;
  final Duration bootDelay;
  final Duration authDelay;
  final Duration refreshDelay;
  final DriverBackend? _backend;
  final LocationService? _location;

  bool get isProduction => _backend != null;
  DriverBackend? get connectBackend => _backend;

  DriverBackend get _productionBackend {
    final backend = _backend;
    if (backend == null) {
      throw StateError('Backend de produccion no disponible.');
    }
    return backend;
  }

  LocationService get _productionLocation {
    final location = _location;
    if (location == null) {
      throw StateError('Servicio de ubicacion de produccion no disponible.');
    }
    return location;
  }

  bool _booting = true;
  bool _signedIn = false;
  bool _authenticating = false;
  bool _applying = false;
  bool _online = false;
  bool _actionBusy = false;
  int _tabIndex = 0;

  double _todayEarnings = 0;
  int _todayDeliveries = 0;
  double _todayKm = 0;
  double _todayOrdersTotal = 0;
  int _onlineMinutesToday;
  int _acceptance;

  DriverProfile _profile;
  DeliveryJob? _active;
  final List<DeliveryJob> _history;
  LoadStatus _historyStatus = LoadStatus.ready;
  final List<double> _weekEarnings;

  FailureKind? _authFailure;
  String? _lastErrorMessage;
  String? _locationIssue;

  final Set<String> _creditedDeliveries = <String>{};
  final Map<String, String> _uploadedProofUrls = <String, String>{};
  final Set<Timer> _timers = <Timer>{};
  Timer? _pollTimer;
  Timer? _gpsHeartbeatTimer;
  bool _gpsHeartbeatBusy = false;
  WebSocket? _orderSocket;
  StreamSubscription<dynamic>? _socketSubscription;
  int? _socketOrderId;
  bool _hydrating = false;
  bool _disposed = false;

  bool get booting => _booting;
  bool get signedIn => _signedIn;
  bool get authenticating => _authenticating;
  bool get applying => _applying;
  bool get online => _online;
  bool get actionBusy => _actionBusy;
  int get tabIndex => _tabIndex;

  double get todayEarnings => _todayEarnings;
  int get todayDeliveries => _todayDeliveries;
  double get todayKm => _todayKm;
  double get todayOrdersTotal => _todayOrdersTotal;
  bool get todayOrdersTotalComplete => !isProduction || _history.length >= _todayDeliveries;
  int get onlineMinutesToday => _onlineMinutesToday;
  int get acceptance => _acceptance;
  double get averagePerDelivery =>
      _todayDeliveries == 0 ? 0 : _todayEarnings / _todayDeliveries;

  DriverProfile get profile => _profile;
  DeliveryJob? get active => _active;
  List<DeliveryJob> get history => List<DeliveryJob>.unmodifiable(_history);
  LoadStatus get historyStatus => _historyStatus;
  FailureKind? get authFailure => _authFailure;
  bool get requiresOtp => _authFailure == FailureKind.twoFactorRequired;
  String? get lastErrorMessage => _lastErrorMessage;
  String? get locationIssue => _locationIssue;

  int get todayIndex => _clock().weekday - 1;
  List<double?> get weekEarnings => List<double?>.unmodifiable([
        for (var i = 0; i < 7; i++)
          if (i < todayIndex)
            _weekEarnings[i]
          else if (i == todayIndex)
            _todayEarnings
          else
            null,
      ]);
  double get weekTotal =>
      weekEarnings.fold<double>(0, (sum, value) => sum + (value ?? 0));
  bool get deliveryInProgress => _active?.stage.inProgress ?? false;
  bool get logoutLocked {
    final active = _active;
    return deliveryInProgress ||
        (isProduction && active != null && active.stage != DeliveryStage.delivered);
  }
  DateTime now() => _clock();

  Future<void> bootstrap() async {
    if (!_booting) {
      return;
    }
    if (!isProduction) {
      await _wait(bootDelay);
      if (_disposed || !_booting) {
        return;
      }
      _booting = false;
      notifyListeners();
      return;
    }

    try {
      final restored = await _productionBackend.restoreSession();
      if (restored) {
        _signedIn = true;
        await _hydrateDashboard(silent: true);
        _startPolling();
        if (_online) {
          unawaited(_startLocationTracking());
        }
      }
    } on AppFailure catch (error) {
      _lastErrorMessage = _messageFor(error);
      if (error.kind == FailureKind.sessionExpired) {
        _signedIn = false;
      }
    } finally {
      _booting = false;
      notifyListeners();
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
    String otp = '',
  }) async {
    if (_signedIn) {
      return true;
    }
    if (_authenticating) {
      return false;
    }
    if (!Validators.isEmail(email) || !Validators.isPassword(password)) {
      return false;
    }
    _authenticating = true;
    _authFailure = null;
    _lastErrorMessage = null;
    notifyListeners();

    if (!isProduction) {
      await _wait(authDelay);
      if (_disposed) {
        return false;
      }
      _authenticating = false;
      _signedIn = true;
      notifyListeners();
      return true;
    }

    try {
      await _productionBackend.signIn(email: email, password: password, otp: otp);
      _signedIn = true;
      await _hydrateDashboard(silent: true);
      _startPolling();
      if (_online) {
        unawaited(_startLocationTracking());
      }
      return true;
    } on AppFailure catch (error) {
      _authFailure = error.kind;
      _lastErrorMessage = _messageFor(error);
      return false;
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }

  Future<bool> requestPasswordRecovery(String email) async {
    if (!Validators.isEmail(email)) {
      return false;
    }
    if (!isProduction) {
      return true;
    }
    try {
      await _productionBackend.requestPasswordRecovery(email);
      return true;
    } on AppFailure catch (error) {
      _lastErrorMessage = _messageFor(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitDriverApplication({
    required bool existingAccount,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String vehicle,
    String otp = '',
  }) async {
    if (_applying) return false;
    if (!Validators.isEmail(email) || !Validators.isPassword(password)) {
      return false;
    }
    if (!existingAccount && name.trim().length < 2) return false;
    if (phone.trim().length < 7 || vehicle.trim().isEmpty) return false;

    _applying = true;
    _authFailure = null;
    _lastErrorMessage = null;
    notifyListeners();

    if (!isProduction) {
      await _wait(authDelay);
      _applying = false;
      notifyListeners();
      return true;
    }

    try {
      await _productionBackend.submitDriverApplication(
        existingAccount: existingAccount,
        name: name,
        email: email,
        password: password,
        phone: phone,
        vehicle: vehicle,
        otp: otp,
      );
      return true;
    } on AppFailure catch (error) {
      _authFailure = error.kind;
      _lastErrorMessage = _messageFor(error);
      return false;
    } finally {
      _applying = false;
      notifyListeners();
    }
  }

  bool logout() {
    if (deliveryInProgress) {
      return false;
    }
    _signedIn = false;
    _online = false;
    _tabIndex = 0;
    notifyListeners();
    return true;
  }

  Future<bool> logoutAsync() async {
    if (logoutLocked) {
      _lastErrorMessage = 'Finaliza la entrega asignada antes de cerrar sesión.';
      notifyListeners();
      return false;
    }
    if (!isProduction) {
      return logout();
    }
    _actionBusy = true;
    notifyListeners();
    try {
      await _stopRealtime();
      _stopGpsHeartbeat();
      await _productionLocation.stop();
      if (_online) {
        // A verified driver must not stay online after sign-out.
        await _productionBackend.setAvailability(false);
      }
      await _productionBackend.logout();
      _signedIn = false;
      _online = false;
      _tabIndex = 0;
      _active = null;
      _history.clear();
      _lastErrorMessage = null;
      return true;
    } on AppFailure catch (error) {
      _lastErrorMessage = _messageFor(error);
      return false;
    } finally {
      _actionBusy = false;
      notifyListeners();
    }
  }

  bool setOnline(bool value) {
    if (!value && deliveryInProgress) {
      return false;
    }
    if (_online == value) {
      return true;
    }
    _online = value;
    notifyListeners();
    return true;
  }

  Future<bool> setOnlineAsync(bool value) async {
    if (!isProduction) {
      return setOnline(value);
    }
    if (_actionBusy) {
      return false;
    }
    if (!value && deliveryInProgress) {
      return false;
    }
    if (value && !_profile.verified) {
      _lastErrorMessage =
          'Tu cuenta de repartidor debe estar verificada antes de conectarte.';
      notifyListeners();
      return false;
    }
    if (_online == value) {
      return true;
    }
    _actionBusy = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      if (value) {
        // RC9.5 requires ONLINE approval before it will accept a GPS write.
        // A position obtained first is kept local until the server accepts
        // availability. If location/readiness fails, revoke ONLINE.
        final location = await _productionLocation.ensureCurrent();
        await _productionBackend.setAvailability(true);
        try {
          await _productionBackend.updateLocation(location.lat, location.lng);
          if (!await _productionBackend.hasConfirmedLiveGpsPresence()) {
            throw const AppFailure(
              FailureKind.server,
              'Tu conexión no tiene GPS vigente. Verifica permisos y vuelve a intentarlo.',
            );
          }
        } on AppFailure {
          try {
            await _productionBackend.setAvailability(false);
          } catch (_) {
            // Redis GPS expires by TTL, and the server fail-closes dispatch.
          }
          rethrow;
        }
        _online = true;
        await _hydrateDashboard(silent: true);
        await _startLocationTracking();
        if (!_online) {
          throw const AppFailure(FailureKind.permissionDenied,
              'No fue posible mantener la ubicación del repartidor.');
        }
        _startPolling();
      } else {
        // The server must confirm OFFLINE before clearing the local state.
        await _productionBackend.setAvailability(false);
        _online = false;
        _stopGpsHeartbeat();
        await _productionLocation.stop();
        _locationIssue = null;
      }
      return true;
    } on AppFailure catch (error) {
      _lastErrorMessage = _messageFor(error);
      if (error.kind == FailureKind.permissionDenied) {
        _locationIssue = _lastErrorMessage;
      }
      return false;
    } finally {
      _actionBusy = false;
      notifyListeners();
    }
  }

  void setTab(int value) {
    if (value < 0 || value >= kTabCount || _tabIndex == value) {
      return;
    }
    _tabIndex = value;
    notifyListeners();
  }

  bool assign(DeliveryJob job) {
    if (!_signedIn || !_online) {
      return false;
    }
    if (_active != null) {
      return false;
    }
    if (job.stage != DeliveryStage.assigned) {
      return false;
    }
    if (_creditedDeliveries.contains(job.id)) {
      return false;
    }
    _active = job;
    notifyListeners();
    return true;
  }

  bool dismissCompleted() {
    if (_active?.stage != DeliveryStage.delivered) {
      return false;
    }
    _active = null;
    notifyListeners();
    return true;
  }

  Future<bool> dismissCompletedAsync() async {
    if (!dismissCompleted()) {
      return false;
    }
    if (isProduction) {
      await _hydrateDashboard(silent: true);
    }
    return true;
  }

  bool beginRoute() {
    if (!_online) {
      return false;
    }
    return _advance(from: DeliveryStage.assigned, to: DeliveryStage.toRestaurant);
  }

  Future<bool> beginRouteAsync() async {
    final ok = beginRoute();
    final job = _active;
    if (ok && isProduction && job != null) {
      await _productionBackend.saveVisualStage(job, DeliveryStage.toRestaurant);
    }
    return ok;
  }

  bool arrivedRestaurant() => _advance(
        from: DeliveryStage.toRestaurant,
        to: DeliveryStage.atRestaurant,
      );

  Future<bool> arrivedRestaurantAsync() async {
    final ok = arrivedRestaurant();
    final job = _active;
    if (ok && isProduction && job != null) {
      await _productionBackend.saveVisualStage(job, DeliveryStage.atRestaurant);
    }
    return ok;
  }

  bool confirmPickup() => _advance(
        from: DeliveryStage.atRestaurant,
        to: DeliveryStage.pickedUp,
      );

  Future<bool> confirmPickupAsync() async {
    if (!isProduction) {
      return confirmPickup();
    }
    final job = _active;
    if (job == null || job.stage != DeliveryStage.atRestaurant || _actionBusy) {
      return false;
    }
    return _serverTransition(job, 'picked_up', DeliveryStage.pickedUp);
  }

  bool beginCustomerRoute() => _advance(
        from: DeliveryStage.pickedUp,
        to: DeliveryStage.toCustomer,
      );

  Future<bool> beginCustomerRouteAsync() async {
    if (!isProduction) {
      return beginCustomerRoute();
    }
    final job = _active;
    if (job == null || job.stage != DeliveryStage.pickedUp || _actionBusy) {
      return false;
    }
    return _serverTransition(job, 'on_the_way', DeliveryStage.toCustomer);
  }

  Future<bool> _serverTransition(
    DeliveryJob job,
    String status,
    DeliveryStage expected,
  ) async {
    _actionBusy = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final updated = await _productionBackend.updateOrderStatus(job, status);
      _active = updated.copyWith(stage: expected);
      await _productionBackend.clearVisualStage(job);
      await _syncSocket();
      return true;
    } on AppFailure catch (error) {
      _lastErrorMessage = _messageFor(error);
      if (error.kind == FailureKind.sessionExpired) {
        await _expireSession();
      }
      return false;
    } finally {
      _actionBusy = false;
      notifyListeners();
    }
  }

  bool completeDelivery() {
    final job = _active;
    if (job == null || job.stage != DeliveryStage.toCustomer) {
      return false;
    }
    final done = job.copyWith(stage: DeliveryStage.delivered, completedAt: _clock());
    _active = done;
    _creditLocal(done);
    notifyListeners();
    return true;
  }

  ProofResult submitProof({required String pin, required bool evidenceAttached}) {
    if (_active?.stage != DeliveryStage.toCustomer) {
      return ProofResult.wrongStage;
    }
    if (!Validators.isPin(pin)) {
      return ProofResult.invalidPin;
    }
    if (!evidenceAttached) {
      return ProofResult.missingEvidence;
    }
    return completeDelivery() ? ProofResult.completed : ProofResult.wrongStage;
  }

  Future<ProofResult> submitProofAsync({
    required String pin,
    required String evidencePath,
  }) async {
    final job = _active;
    if (job == null || job.stage != DeliveryStage.toCustomer) {
      return ProofResult.wrongStage;
    }
    if (!Validators.isPin(pin)) {
      return ProofResult.invalidPin;
    }
    if (evidencePath.trim().isEmpty) {
      return ProofResult.missingEvidence;
    }
    if (!isProduction) {
      return submitProof(pin: pin, evidenceAttached: true);
    }
    if (_actionBusy) {
      return ProofResult.failed;
    }
    _actionBusy = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final proofKey = '${job.id}|$evidencePath';
      final proofUrl = _uploadedProofUrls[proofKey] ??
          await _productionBackend.uploadProof(evidencePath);
      _uploadedProofUrls[proofKey] = proofUrl;
      final location = _productionLocation.last;
      final done = await _productionBackend.completeDelivery(
        job: job,
        pin: pin,
        proofUrl: proofUrl,
        lat: location?.lat,
        lng: location?.lng,
      );
      _active = done;
      _uploadedProofUrls.removeWhere((key, _) => key.startsWith('${job.id}|'));
      _creditLocal(done);
      await _syncSocket();
      unawaited(_hydrateDashboardPreservingCompleted(done));
      return ProofResult.completed;
    } on AppFailure catch (error) {
      _lastErrorMessage = _messageFor(error);
      if (error.kind == FailureKind.validation &&
          error.message.toLowerCase().contains('pin')) {
        return ProofResult.invalidPin;
      }
      if (error.kind == FailureKind.sessionExpired) {
        await _expireSession();
      }
      return ProofResult.failed;
    } finally {
      _actionBusy = false;
      notifyListeners();
    }
  }

  void _creditLocal(DeliveryJob done) {
    if (_creditedDeliveries.add(done.id)) {
      _todayEarnings += done.earning;
      _todayDeliveries += 1;
      _todayKm += done.distanceKm;
      _todayOrdersTotal += done.total;
      _history.removeWhere((item) => item.id == done.id);
      _history.insert(0, done);
      _weekEarnings[todayIndex] = _todayEarnings;
    }
  }

  Future<void> refreshHistory() async {
    if (_historyStatus == LoadStatus.loading) {
      return;
    }
    _historyStatus = LoadStatus.loading;
    notifyListeners();
    if (!isProduction) {
      await _wait(refreshDelay);
      if (_disposed) {
        return;
      }
      _historyStatus = LoadStatus.ready;
      notifyListeners();
      return;
    }
    try {
      await _hydrateDashboard(silent: true);
      _historyStatus = LoadStatus.ready;
    } on AppFailure catch (error) {
      _historyStatus = LoadStatus.error;
      _lastErrorMessage = _messageFor(error);
    }
    notifyListeners();
  }

  void setHistoryStatus(LoadStatus status) {
    if (_historyStatus == status) {
      return;
    }
    _historyStatus = status;
    notifyListeners();
  }

  Future<void> _hydrateDashboard({bool silent = false}) async {
    if (!isProduction || _hydrating || !_signedIn) {
      return;
    }
    _hydrating = true;
    try {
      final data = await _productionBackend.dashboard();
      _profile = data.profile;
      _online = data.online;
      _todayEarnings = data.todayEarnings;
      _todayDeliveries = data.todayDeliveries;
      _todayKm = data.todayKm;
      _todayOrdersTotal = data.todayOrdersTotal;
      _acceptance = data.acceptance;
      for (var i = 0; i < 7; i++) {
        _weekEarnings[i] = data.weekEarnings[i];
      }
      _history
        ..clear()
        ..addAll(data.history);
      for (final job in _history) {
        _creditedDeliveries.add(job.id);
      }
      if (_active?.stage != DeliveryStage.delivered) {
        _active = data.active;
      }
      _lastErrorMessage = null;
      await _syncSocket();
    } on AppFailure catch (error) {
      _lastErrorMessage = _messageFor(error);
      if (error.kind == FailureKind.sessionExpired) {
        await _expireSession();
      }
      if (!silent) {
        rethrow;
      }
    } finally {
      _hydrating = false;
      notifyListeners();
    }
  }

  Future<void> _hydrateDashboardPreservingCompleted(DeliveryJob done) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (_disposed || !_signedIn) {
      return;
    }
    final saved = _active;
    await _hydrateDashboard(silent: true);
    if (saved?.stage == DeliveryStage.delivered && _active == null) {
      _active = done;
      notifyListeners();
    }
  }

  void _startPolling() {
    if (!isProduction || !_signedIn) {
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_signedIn && (_online || _active != null)) {
        unawaited(_hydrateDashboard(silent: true));
      }
    });
  }

  Future<void> _startLocationTracking() async {
    if (!isProduction || !_online) {
      return;
    }
    try {
      await _productionLocation.start((location) async {
        if (!_signedIn || !_online || _disposed) {
          return;
        }
        try {
          await _productionBackend.updateLocation(location.lat, location.lng);
          if (_locationIssue != null) {
            _locationIssue = null;
            notifyListeners();
          }
        } on AppFailure catch (error) {
          _locationIssue = _messageFor(error);
          notifyListeners();
        }
      });
      _startGpsHeartbeat();
    } on AppFailure catch (error) {
      _stopGpsHeartbeat();
      _locationIssue = _messageFor(error);
      if (_active == null && _online) {
        try {
          await _productionBackend.setAvailability(false);
          _online = false;
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  // GPS Redis location has a 120s TTL. A stationary driver may not trigger
  // position-stream updates, so renew current GPS every 40 seconds.
  void _startGpsHeartbeat() {
    _gpsHeartbeatTimer?.cancel();
    _gpsHeartbeatTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      unawaited(_refreshGpsHeartbeat());
    });
  }

  void _stopGpsHeartbeat() {
    _gpsHeartbeatTimer?.cancel();
    _gpsHeartbeatTimer = null;
  }

  Future<void> _refreshGpsHeartbeat() async {
    if (_gpsHeartbeatBusy || !_signedIn || !_online || _disposed ||
        !isProduction) {
      return;
    }
    _gpsHeartbeatBusy = true;
    try {
      final location = await _productionLocation.ensureCurrent();
      if (!_signedIn || !_online || _disposed) return;
      await _productionBackend.updateLocation(location.lat, location.lng);
      if (!await _productionBackend.hasConfirmedLiveGpsPresence()) {
        throw const AppFailure(FailureKind.server,
            'No se confirmó el GPS del repartidor. Intentando reconectar.');
      }
      if (_locationIssue != null) {
        _locationIssue = null;
        notifyListeners();
      }
    } on AppFailure catch (error) {
      _locationIssue = _messageFor(error);
      notifyListeners();
    } finally {
      _gpsHeartbeatBusy = false;
    }
  }

  Future<void> _syncSocket() async {
    if (!isProduction) {
      return;
    }
    final job = _active;
    if (job == null || job.stage == DeliveryStage.delivered) {
      await _closeSocket();
      return;
    }
    final id = job.serverId;
    if (id == null) {
      await _closeSocket();
      return;
    }
    if (_socketOrderId == id && _orderSocket != null) {
      return;
    }
    await _closeSocket();
    try {
      // This socket is retained by the controller and closed in _closeSocket().
      // ignore: close_sinks
      final socket = await _productionBackend.connectOrderSocket(job);
      _orderSocket = socket;
      _socketOrderId = id;
      _socketSubscription = socket.listen(
        (_) => unawaited(_hydrateDashboard(silent: true)),
        onError: (_) => unawaited(_closeSocket()),
        onDone: () => unawaited(_closeSocket()),
        cancelOnError: true,
      );
    } on AppFailure {
      // Polling remains the production fallback if WS is temporarily unavailable.
    }
  }

  Future<void> _closeSocket() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    try {
      await _orderSocket?.close();
    } catch (_) {}
    _orderSocket = null;
    _socketOrderId = null;
  }

  Future<void> _stopRealtime() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _closeSocket();
  }

  Future<void> _expireSession() async {
    _stopGpsHeartbeat();
    await _stopRealtime();
    await _location?.stop();
    await _backend?.api.session.clear();
    _signedIn = false;
    _online = false;
    _active = null;
  }

  bool _advance({required DeliveryStage from, required DeliveryStage to}) {
    final job = _active;
    if (job == null || job.stage != from) {
      return false;
    }
    _active = job.copyWith(stage: to);
    notifyListeners();
    return true;
  }

  String _messageFor(AppFailure error) {
    if (error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    return switch (error.kind) {
      FailureKind.offline => 'Sin conexión con Tala Eats. Revisa tu internet.',
      FailureKind.timeout => 'El servidor tardó demasiado. Intenta de nuevo.',
      FailureKind.invalidCredentials => 'Correo o contraseña incorrectos.',
      FailureKind.twoFactorRequired => 'Ingresa el código de verificación de tu cuenta.',
      FailureKind.sessionExpired => 'Tu sesión expiró. Inicia sesión otra vez.',
      FailureKind.permissionDenied => 'No tienes permiso para realizar esta acción.',
      FailureKind.notFound => 'No encontramos este recurso.',
      FailureKind.conflict => 'El estado cambió en el servidor. Actualiza e intenta de nuevo.',
      FailureKind.validation => 'Revisa los datos e intenta de nuevo.',
      FailureKind.media => 'La foto no pudo procesarse. Usa JPG, PNG o WEBP.',
      FailureKind.server => 'Tala Eats no está disponible por el momento.',
      FailureKind.unknown => 'No fue posible completar la operación.',
    };
  }

  Future<void> _wait(Duration duration) {
    final completer = Completer<void>();
    late final Timer timer;
    timer = Timer(duration, () {
      _timers.remove(timer);
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    _timers.add(timer);
    return completer.future;
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _stopGpsHeartbeat();
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    unawaited(_closeSocket());
    unawaited(_location?.dispose() ?? Future<void>.value());
    _backend?.close();
    super.dispose();
  }
}
