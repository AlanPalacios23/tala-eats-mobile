import 'dart:io';

import '../core/failures.dart';
import '../models/delivery.dart';
import '../models/driver_profile.dart';
import 'remote_api.dart';

class DriverDashboardData {
  const DriverDashboardData({
    required this.profile,
    required this.online,
    required this.active,
    required this.history,
    required this.todayEarnings,
    required this.todayDeliveries,
    required this.todayKm,
    required this.todayOrdersTotal,
    required this.acceptance,
    required this.weekEarnings,
  });

  final DriverProfile profile;
  final bool online;
  final DeliveryJob? active;
  final List<DeliveryJob> history;
  final double todayEarnings;
  final int todayDeliveries;
  final double todayKm;
  final double todayOrdersTotal;
  final int acceptance;
  final List<double> weekEarnings;
}

class DriverBackend {
  DriverBackend({RemoteApi? api}) : api = api ?? RemoteApi();

  final RemoteApi api;
  List<DriverDocument>? _cachedDocuments;

  Future<bool> hasSession() async {
    final token = await api.session.accessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> signIn({
    required String email,
    required String password,
    String otp = '',
  }) async {
    final raw = await api.post(
      '/auth/login',
      auth: false,
      body: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': password,
        if (otp.trim().isNotEmpty) 'otp': otp.trim(),
      },
    );
    final map = _map(raw);
    final user = _map(map['user']);
    final role = '${user['role'] ?? ''}'.trim().toLowerCase();
    final token = '${map['access_token'] ?? ''}';
    if (token.isEmpty || token == 'cookie') {
      throw const AppFailure(FailureKind.sessionExpired);
    }
    if (role != 'driver') {
      if (role == 'customer') {
        await api.session.saveTokens(
          accessToken: token,
          deviceToken: '${map['device_token'] ?? ''}',
        );
        try {
          final rows = _list(await api.get('/operations/onboarding/mine'));
          Map<String, dynamic>? latest;
          for (final item in rows) {
            if (item is Map && '${item['entity_type'] ?? ''}' == 'driver') {
              latest = Map<String, dynamic>.from(item);
              break;
            }
          }
          final status = '${latest?['status'] ?? ''}'.trim().toLowerCase();
          if (status == 'pending') {
            throw const AppFailure(
              FailureKind.permissionDenied,
              'Tu solicitud de repartidor sigue pendiente de aprobación.',
            );
          }
          if (status == 'needs_info') {
            throw const AppFailure(
              FailureKind.permissionDenied,
              'Tu solicitud necesita información adicional. Contacta a soporte de Tala Eats.',
            );
          }
          if (status == 'rejected' || status == 'suspended') {
            throw const AppFailure(
              FailureKind.permissionDenied,
              'Tu solicitud de repartidor no está activa. Contacta a soporte de Tala Eats.',
            );
          }
        } finally {
          await api.session.clear();
        }
      }
      throw const AppFailure(
        FailureKind.permissionDenied,
        'Esta cuenta todavía no tiene acceso como repartidor.',
      );
    }
    await api.session.saveTokens(
      accessToken: token,
      deviceToken: '${map['device_token'] ?? ''}',
    );
  }

  Future<bool> restoreSession() async {
    if (!await hasSession()) return false;
    try {
      final raw = await api.get('/auth/me');
      final user = _map(raw);
      if ('${user['role'] ?? ''}' != 'driver') {
        await api.session.clear();
        return false;
      }
      return true;
    } on AppFailure catch (error) {
      if (error.kind == FailureKind.sessionExpired ||
          error.kind == FailureKind.permissionDenied) {
        await api.session.clear();
        return false;
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } on AppFailure catch (error) {
      if (error.kind != FailureKind.sessionExpired &&
          error.kind != FailureKind.offline &&
          error.kind != FailureKind.timeout) {
        rethrow;
      }
    } finally {
      await api.session.clear();
    }
  }

  Future<void> requestPasswordRecovery(String email) async {
    await api.post(
      '/auth/password/forgot',
      auth: false,
      body: <String, dynamic>{'email': email.trim().toLowerCase()},
    );
  }

  /// Crea o reutiliza una cuenta general de Tala Eats y envía la solicitud
  /// oficial de incorporación como repartidor. El backend mantiene la cuenta
  /// como `customer` hasta que ADMIN aprueba el onboarding; en ese momento el
  /// rol cambia a `driver` y la misma contraseña sirve para entrar a esta app.
  Future<String> submitDriverApplication({
    required bool existingAccount,
    required String name,
    required String email,
    required String password,
    required String phone,
    required String vehicle,
    String otp = '',
  }) async {
    dynamic raw;
    if (existingAccount) {
      raw = await api.post(
        '/auth/login',
        auth: false,
        body: <String, dynamic>{
          'email': email.trim().toLowerCase(),
          'password': password,
          if (otp.trim().isNotEmpty) 'otp': otp.trim(),
        },
      );
    } else {
      raw = await api.post(
        '/auth/register',
        auth: false,
        body: <String, dynamic>{
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
    }

    final map = _map(raw);
    final user = _map(map['user']);
    final role = '${user['role'] ?? ''}'.trim().toLowerCase();
    if (role == 'driver') {
      throw const AppFailure(
        FailureKind.conflict,
        'Tu cuenta ya está aprobada como repartidor. Regresa e inicia sesión.',
      );
    }
    if (role != 'customer') {
      throw const AppFailure(
        FailureKind.permissionDenied,
        'Esta cuenta no puede solicitar acceso como repartidor.',
      );
    }

    final token = '${map['access_token'] ?? ''}';
    if (token.isEmpty || token == 'cookie') {
      throw const AppFailure(FailureKind.sessionExpired);
    }
    await api.session.saveTokens(
      accessToken: token,
      deviceToken: '${map['device_token'] ?? ''}',
    );

    try {
      if (phone.trim().isNotEmpty) {
        await api.patch(
          '/auth/me',
          body: <String, dynamic>{'phone': phone.trim()},
        );
      }
      final onboarding = _map(await api.post(
        '/operations/onboarding',
        body: <String, dynamic>{
          'entity_type': 'driver',
          'business_name': '',
          'tax_id': '',
          'vehicle': vehicle.trim(),
          'payout_account_ref': '',
          'documents': const <String>[],
        },
      ));
      return '${onboarding['status'] ?? 'pending'}';
    } finally {
      // La cuenta queda creada en servidor, pero no conservamos una sesión de
      // cliente dentro de la app de Repartidor. Tras aprobación iniciará sesión
      // de forma normal como `driver`.
      await api.session.clear();
    }
  }

  Future<DriverDashboardData> dashboard() async {
    final raw = _map(await api.get('/driver/dashboard'));
    final user = _map(raw['user']);
    final profileRaw = _map(raw['profile']);
    final recentRaw = _list(raw['recent']);
    final today = _map(raw['today']);

    final documents = await _documents(profileRaw);
    final fullName = _text(user['name'], fallback: 'Repartidor');
    final vehicle = _text(profileRaw['vehicle'], fallback: 'Motocicleta');
    final plate = _text(profileRaw['plate']);
    final profile = DriverProfile(
      firstName: fullName.trim().split(RegExp(r'\s+')).first,
      fullName: fullName,
      zone: 'Tala, Jalisco',
      vehicleType: vehicle,
      plateSuffix: plate.isEmpty
          ? '—'
          : plate.substring(plate.length > 2 ? plate.length - 2 : 0),
      verified: _bool(profileRaw['is_verified']),
      documents: documents,
    );

    final activeRaw = raw['active'];
    final active = activeRaw is Map
        ? await _dashboardDelivery(Map<String, dynamic>.from(activeRaw))
        : null;
    final recent = <DeliveryJob>[];
    for (final item in recentRaw) {
      if (item is Map) {
        recent.add(await _dashboardDelivery(Map<String, dynamic>.from(item)));
      }
    }
    final now = DateTime.now();
    final history = recent
        .where((job) => job.completedAt != null &&
            _sameLocalDay(job.completedAt!.toLocal(), now))
        .toList();

    // El dashboard no expone el GMV de hoy. Se calcula de los 20 recientes;
    // para la jornada normal esto coincide y sigue estrictamente separado de
    // la ganancia del repartidor.
    final todayOrdersTotal = history
        .where((job) =>
            job.completedAt != null &&
            _sameLocalDay(job.completedAt!.toLocal(), now))
        .fold<double>(0, (sum, job) => sum + job.total);

    return DriverDashboardData(
      profile: profile,
      online: _bool(profileRaw['is_online']),
      active: active,
      history: history,
      todayEarnings: _double(today['earnings']),
      todayDeliveries: _int(today['deliveries']),
      todayKm: _double(today['distance_km']),
      todayOrdersTotal: todayOrdersTotal,
      acceptance: _int(raw['acceptance_rate'], fallback: 100),
      weekEarnings: _currentWeek(_list(raw['last_7_days'])),
    );
  }

  /// RC9.5 LIVE: the authenticated driver inspects only their own status.
  /// Do not interpret ready_for_dispatch=false as a GPS failure: commercial
  /// dispatch has a separate release switch.
  Future<bool> hasConfirmedLiveGpsPresence() async {
    final raw = _map(await api.get('/driver/presence-readiness'));
    return raw['presence_enabled'] == true &&
        raw['admin_verified'] == true &&
        raw['online'] == true &&
        raw['fresh_gps'] == true;
  }

  Future<void> setAvailability(bool online) async {
    await api.patch(
      '/driver/availability',
      body: <String, dynamic>{'is_online': online},
    );
  }

  Future<void> updateLocation(double lat, double lng) async {
    await api.patch(
      '/driver/location',
      body: <String, dynamic>{'lat': lat, 'lng': lng},
    );
  }

  Future<DeliveryJob> updateOrderStatus(
    DeliveryJob job,
    String status,
  ) async {
    final id = _orderId(job);
    final raw = await api.patch(
      '/driver/orders/$id/status',
      body: <String, dynamic>{'status': status},
    );
    return _operationalDelivery(_map(raw), fallback: job);
  }

  Future<String> uploadProof(String filePath) => api.uploadDeliveryProof(filePath);

  Future<DeliveryJob> completeDelivery({
    required DeliveryJob job,
    required String pin,
    required String proofUrl,
    double? lat,
    double? lng,
  }) async {
    final id = _orderId(job);
    final raw = await api.post(
      '/driver/orders/$id/complete',
      body: <String, dynamic>{
        'pin': pin,
        'photo_url': proofUrl,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    final mapped = _operationalDelivery(_map(raw), fallback: job);
    await api.session.clearRouteStage(id);
    return mapped.copyWith(
      stage: DeliveryStage.delivered,
      completedAt: mapped.completedAt ?? DateTime.now(),
    );
  }

  Future<WebSocket> connectOrderSocket(DeliveryJob job) =>
      api.connectOrderSocket(_orderId(job));

  Future<void> saveVisualStage(DeliveryJob job, DeliveryStage stage) async {
    final id = _orderId(job);
    await api.session.saveRouteStage(id, stage.name);
  }

  Future<void> clearVisualStage(DeliveryJob job) async {
    await api.session.clearRouteStage(_orderId(job));
  }

  int _orderId(DeliveryJob job) {
    if (job.serverId != null) return job.serverId!;
    final digits = job.id.replaceAll(RegExp(r'\D'), '');
    final parsed = int.tryParse(digits);
    if (parsed == null) throw const AppFailure(FailureKind.validation);
    return parsed;
  }

  Future<DeliveryJob> _dashboardDelivery(Map<String, dynamic> raw) async {
    final restaurant = _map(raw['restaurant']);
    final customer = _map(raw['customer']);
    final serverId = _int(raw['id']);
    final status = '${raw['status'] ?? ''}';
    final stage = await _stageFor(serverId, status);
    return DeliveryJob(
      serverId: serverId,
      id: _text(raw['code'], fallback: 'TE-${serverId.toString().padLeft(4, '0')}'),
      restaurant: _text(restaurant['name'], fallback: 'Restaurante'),
      restaurantAddress: _text(restaurant['address'], fallback: 'Tala, Jalisco'),
      restaurantLat: _nullableDouble(restaurant['lat']),
      restaurantLng: _nullableDouble(restaurant['lng']),
      customer: _text(customer['name'], fallback: 'Cliente'),
      customerAddress: _text(customer['address'], fallback: 'Tala, Jalisco'),
      customerPhone: _text(customer['phone']).isEmpty ? null : _text(customer['phone']),
      customerLat: _nullableDouble(customer['lat']),
      customerLng: _nullableDouble(customer['lng']),
      total: _double(raw['total']),
      earning: _double(raw['earning']),
      distanceKm: _double(raw['distance_km']),
      etaMinutes: _int(raw['eta_minutes']),
      stage: stage,
      note: _text(raw['note']).isEmpty ? null : _text(raw['note']),
      completedAt: _date(raw['delivered_at']),
    );
  }

  DeliveryJob _operationalDelivery(
    Map<String, dynamic> raw, {
    required DeliveryJob fallback,
  }) {
    final status = '${raw['status'] ?? ''}';
    final stage = switch (status) {
      'picked_up' => DeliveryStage.pickedUp,
      'on_the_way' => DeliveryStage.toCustomer,
      'delivered' => DeliveryStage.delivered,
      _ => fallback.stage,
    };
    return DeliveryJob(
      serverId: _int(raw['id'], fallback: fallback.serverId ?? 0),
      id: fallback.id,
      restaurant: fallback.restaurant,
      restaurantAddress: fallback.restaurantAddress,
      restaurantLat: fallback.restaurantLat,
      restaurantLng: fallback.restaurantLng,
      customer: fallback.customer,
      customerAddress: _text(raw['address'], fallback: fallback.customerAddress),
      customerPhone: fallback.customerPhone,
      customerLat: _nullableDouble(raw['delivery_lat']) ?? fallback.customerLat,
      customerLng: _nullableDouble(raw['delivery_lng']) ?? fallback.customerLng,
      total: _double(raw['total'], fallback: fallback.total),
      earning: _double(raw['driver_earning'], fallback: fallback.earning) +
          _double(raw['tip']),
      distanceKm: _double(raw['distance_km'], fallback: fallback.distanceKm),
      etaMinutes: _int(raw['estimated_minutes'], fallback: fallback.etaMinutes),
      stage: stage,
      note: _text(raw['notes'], fallback: fallback.note ?? '').isEmpty
          ? fallback.note
          : _text(raw['notes']),
      completedAt: _date(raw['delivered_at']) ?? fallback.completedAt,
    );
  }

  Future<DeliveryStage> _stageFor(int orderId, String status) async {
    if (status == 'delivered') return DeliveryStage.delivered;
    if (status == 'on_the_way') return DeliveryStage.toCustomer;
    if (status == 'picked_up') return DeliveryStage.pickedUp;
    if (status != 'assigned') return DeliveryStage.assigned;
    final saved = await api.session.routeStage(orderId);
    return switch (saved) {
      'toRestaurant' => DeliveryStage.toRestaurant,
      'atRestaurant' => DeliveryStage.atRestaurant,
      _ => DeliveryStage.assigned,
    };
  }

  Future<List<DriverDocument>> _documents(Map<String, dynamic> profile) async {
    final cached = _cachedDocuments;
    if (cached != null) return cached;
    try {
      final applications = _list(await api.get('/operations/onboarding/mine'));
      Map<String, dynamic>? driver;
      for (final row in applications) {
        if (row is Map && '${row['entity_type'] ?? ''}' == 'driver') {
          driver = Map<String, dynamic>.from(row);
          break;
        }
      }
      final status = '${driver?['status'] ?? ''}'.toLowerCase();
      final mapped = switch (status) {
        'approved' => DocumentStatus.verified,
        'pending' || 'needs_info' => DocumentStatus.pending,
        'rejected' || 'suspended' => DocumentStatus.expired,
        _ => _bool(profile['is_verified'])
            ? DocumentStatus.verified
            : DocumentStatus.pending,
      };
      final result = <DriverDocument>[
        DriverDocument(name: 'Identificación y expediente', status: mapped),
        DriverDocument(name: 'Licencia de conducir', status: mapped),
        DriverDocument(name: 'Vehículo y circulación', status: mapped),
      ];
      _cachedDocuments = result;
      return result;
    } on AppFailure {
      final status = _bool(profile['is_verified'])
          ? DocumentStatus.verified
          : DocumentStatus.pending;
      final result = <DriverDocument>[
        DriverDocument(name: 'Expediente de repartidor', status: status),
      ];
      _cachedDocuments = result;
      return result;
    }
  }

  List<double> _currentWeek(List<dynamic> rows) {
    final result = List<double>.filled(7, 0);
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    for (final row in rows) {
      if (row is! Map) continue;
      final dateText = '${row['date'] ?? ''}';
      final date = DateTime.tryParse(dateText);
      if (date == null) continue;
      final localDate = DateTime(date.year, date.month, date.day);
      final offset = localDate.difference(monday).inDays;
      if (offset >= 0 && offset < 7) {
        result[offset] = _double(row['earnings']);
      }
    }
    return result;
  }

  static bool _sameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic> _list(dynamic value) => value is List ? value : const [];

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value == null ? '' : '$value'.trim();
    return text.isEmpty ? fallback : text;
  }

  static bool _bool(dynamic value) => value == true || value == 1 || value == 'true';

  static int _int(dynamic value, {int fallback = 0}) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

  static double _double(dynamic value, {double fallback = 0}) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  static DateTime? _date(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return null;
    return DateTime.tryParse('$value')?.toLocal();
  }

  void close() => api.close();
}
