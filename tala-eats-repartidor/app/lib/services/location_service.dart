import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../core/failures.dart';

class DriverLocation {
  const DriverLocation(this.lat, this.lng);
  final double lat;
  final double lng;
}

class LocationService {
  StreamSubscription<Position>? _subscription;
  DriverLocation? _last;

  DriverLocation? get last => _last;

  Future<DriverLocation> ensureCurrent() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppFailure(
        FailureKind.permissionDenied,
        'Activa la ubicación del teléfono para conectarte.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const AppFailure(
        FailureKind.permissionDenied,
        'Tala Eats necesita tu ubicación mientras realizas entregas.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return _remember(position);
  }

  Future<void> start(Future<void> Function(DriverLocation location) onLocation) async {
    await stop();
    final initial = await ensureCurrent();
    await onLocation(initial);
    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
            intervalDuration: Duration(seconds: 8),
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: 'Tala Eats · Repartidor en línea',
              notificationText: 'Ubicación activa mientras recibes o realizas entregas.',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          );
    _subscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) {
      final current = _remember(position);
      unawaited(onLocation(current));
    });
  }

  DriverLocation _remember(Position position) {
    final value = DriverLocation(position.latitude, position.longitude);
    _last = value;
    return value;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() => stop();
}
