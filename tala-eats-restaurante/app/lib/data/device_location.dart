// Lectura del GPS del teléfono para la ubicación del establecimiento.
//
// Paquete: geolocator (permiso de ubicación «mientras se usa la app»). Solo se
// pide al tocar «Usar mi ubicación»; nunca en segundo plano.

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/restaurant_location.dart';

enum LocationIssueKind { serviceOff, denied, deniedForever, timeout, unavailable }

class LocationIssue implements Exception {
  const LocationIssue(this.kind);

  final LocationIssueKind kind;

  String get title {
    switch (kind) {
      case LocationIssueKind.serviceOff:
        return 'La ubicación del teléfono está apagada';
      case LocationIssueKind.denied:
        return 'Necesitamos permiso de ubicación';
      case LocationIssueKind.deniedForever:
        return 'El permiso de ubicación está bloqueado';
      case LocationIssueKind.timeout:
        return 'No encontramos señal GPS';
      case LocationIssueKind.unavailable:
        return 'No pudimos leer tu ubicación';
    }
  }

  String get message {
    switch (kind) {
      case LocationIssueKind.serviceOff:
        return 'Activa la ubicación en los ajustes de Android y vuelve a intentar.';
      case LocationIssueKind.denied:
        return 'Toca «Usar mi ubicación» y elige «Permitir» para marcar tu local.';
      case LocationIssueKind.deniedForever:
        return 'Ábrelo en los ajustes de la app y permite la ubicación.';
      case LocationIssueKind.timeout:
        return 'Acércate a una ventana o a la entrada de tu local e intenta de nuevo.';
      case LocationIssueKind.unavailable:
        return 'Intenta de nuevo. También puedes guardar solo la dirección.';
    }
  }

  /// Hay una pantalla de ajustes que resuelve el problema.
  bool get canOpenSettings =>
      kind == LocationIssueKind.serviceOff ||
      kind == LocationIssueKind.deniedForever;

  @override
  String toString() => 'LocationIssue($kind)';
}

abstract class DeviceLocationProvider {
  const DeviceLocationProvider();

  /// Lanza [LocationIssue] si no hay servicio, permiso o señal.
  Future<GpsFix> currentFix();

  Future<bool> openSettings(LocationIssueKind kind);
}

class GeolocatorLocationProvider extends DeviceLocationProvider {
  const GeolocatorLocationProvider();

  @override
  Future<GpsFix> currentFix() async {
    final bool serviceOn;
    try {
      serviceOn = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      throw const LocationIssue(LocationIssueKind.unavailable);
    }
    if (!serviceOn) throw const LocationIssue(LocationIssueKind.serviceOff);

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationIssue(LocationIssueKind.deniedForever);
    }
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const LocationIssue(LocationIssueKind.denied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GpsFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } on TimeoutException {
      throw const LocationIssue(LocationIssueKind.timeout);
    } catch (_) {
      throw const LocationIssue(LocationIssueKind.unavailable);
    }
  }

  @override
  Future<bool> openSettings(LocationIssueKind kind) {
    return kind == LocationIssueKind.serviceOff
        ? Geolocator.openLocationSettings()
        : Geolocator.openAppSettings();
  }
}
