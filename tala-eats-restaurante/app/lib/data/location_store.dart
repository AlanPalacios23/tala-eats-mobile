// Guardado de la ubicación del establecimiento (v0.5.15).
//
// PUNTO ÚNICO DE CONEXIÓN CON EL BACKEND
// --------------------------------------
// El restaurante confirmó que el backend ya tiene campos de ubicación, pero
// sus nombres exactos aún no están en el contrato del frontend. Para no
// romper `PATCH /owner/restaurant` con campos desconocidos, esta versión
// usa [LocalRestaurantLocationStore]: guarda en el teléfono y marca la
// ubicación como «pendiente de enviar».
//
// Para conectar: completar [LocationServerFields] con los nombres reales y
// cambiar `AppServices.production` para usar [RemoteRestaurantLocationStore].
// Ver RESTAURANTE/INTEGRACION-UBICACION-v0.5.15.md.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/failures.dart';
import '../models/restaurant_location.dart';
import 'remote/remote_api.dart';

abstract class RestaurantLocationStore {
  const RestaurantLocationStore();

  /// `true` cuando guardar envía la ubicación al backend.
  bool get sendsToServer;

  Future<RestaurantLocation?> load(int restaurantId);

  /// Devuelve la ubicación guardada; `syncedToServer` indica si el backend
  /// la confirmó (la versión local conserva el valor recibido, que la
  /// pantalla siempre crea en `false`).
  Future<RestaurantLocation> save(int restaurantId, RestaurantLocation value);
}

/// Guarda en el teléfono (SharedPreferences). No hace llamadas de red.
class LocalRestaurantLocationStore extends RestaurantLocationStore {
  const LocalRestaurantLocationStore();

  static String _key(int restaurantId) =>
      'tala.restaurant.location.v1.$restaurantId';

  @override
  bool get sendsToServer => false;

  @override
  Future<RestaurantLocation?> load(int restaurantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(restaurantId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return RestaurantLocation.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RestaurantLocation> save(
    int restaurantId,
    RestaurantLocation value,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ok = await prefs.setString(
        _key(restaurantId),
        jsonEncode(value.toJson()),
      );
      if (!ok) throw const AppFailure(FailureKind.unknown);
      return value;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// Nombres de los campos del backend. Se completan cuando el backend los
/// confirme; ninguno se adivina en esta versión.
class LocationServerFields {
  const LocationServerFields({
    required this.path,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.neighborhood,
    this.city,
    this.postalCode,
    this.references,
  });

  /// Ruta relativa a la base de la API, p. ej. `/owner/restaurant`.
  final String path;

  /// Campo de dirección. Si el backend no separa colonia/ciudad/CP, se envía
  /// la dirección completa en una línea.
  final String address;
  final String latitude;
  final String longitude;
  final String? neighborhood;
  final String? city;
  final String? postalCode;
  final String? references;
}

/// El backend es la fuente de verdad. La caché local sólo conserva el desglose
/// de dirección para formularios y nunca autoriza un estado "sincronizado".
class RemoteRestaurantLocationStore extends RestaurantLocationStore {
  const RemoteRestaurantLocationStore(this.api, this.fields, this.cache);

  final RemoteApi api;
  final LocationServerFields fields;
  final LocalRestaurantLocationStore cache;

  @override
  bool get sendsToServer => true;

  double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

  @override
  Future<RestaurantLocation?> load(int restaurantId) async {
    final cached = await cache.load(restaurantId);
    try {
      final raw = await api.get(fields.path);
      if (raw is! Map) return cached?.copyWith(syncedToServer: false);
      final data = Map<String, dynamic>.from(raw);
      if (data['id'] != restaurantId) {
        throw const AppFailure(FailureKind.permissionDenied,
            'No coincide el restaurante autorizado.');
      }
      final address = (data[fields.address] ?? '').toString().trim();
      final lat = _num(data[fields.latitude]);
      final lng = _num(data[fields.longitude]);
      if (address.isEmpty) return cached?.copyWith(syncedToServer: false);
      if (cached != null && cached.singleLine == address &&
          cached.latitude == lat && cached.longitude == lng) {
        return cached.copyWith(syncedToServer: true);
      }
      // El backend no divide domicilio en colonia/municipio/código postal.
      // Se muestra la dirección real sin presentar un desglose inventado.
      return RestaurantLocation(
        street: address, neighborhood: '', city: '', postalCode: '',
        latitude: lat, longitude: lng, syncedToServer: true,
      );
    } on AppFailure catch (error) {
      if (error.kind == FailureKind.permissionDenied ||
          error.kind == FailureKind.sessionExpired) rethrow;
      return cached?.copyWith(syncedToServer: false);
    } catch (_) {
      return cached?.copyWith(syncedToServer: false);
    }
  }

  @override
  Future<RestaurantLocation> save(int restaurantId, RestaurantLocation value) async {
    if (restaurantId <= 0 || !value.isComplete) {
      throw const AppFailure(FailureKind.validation,
          'Completa la dirección antes de guardar.');
    }
    final body = <String, dynamic>{fields.address: value.singleLine};
    // Un GPS parcial nunca se envía. Sin GPS conservamos el existente del servidor.
    if (value.hasCoordinates) {
      body[fields.latitude] = value.latitude;
      body[fields.longitude] = value.longitude;
    }
    final raw = await api.patch(fields.path, body: body);
    if (raw is! Map) {
      throw const AppFailure(FailureKind.server, 'Ubicación no confirmada.');
    }
    final response = Map<String, dynamic>.from(raw);
    final lat = _num(response[fields.latitude]);
    final lng = _num(response[fields.longitude]);
    if (response['id'] != restaurantId ||
        (response[fields.address] ?? '').toString().trim() != value.singleLine ||
        (value.hasCoordinates && (lat != value.latitude || lng != value.longitude))) {
      // Con backend v1.6.2 los campos nuevos pueden ignorarse: fail closed.
      throw const AppFailure(FailureKind.server,
          'El servidor todavía no confirmó dirección y GPS. No se sincronizó.');
    }
    final confirmed = RestaurantLocation(
      street: value.street, neighborhood: value.neighborhood,
      city: value.city, postalCode: value.postalCode,
      references: value.references,
      latitude: lat, longitude: lng,
      accuracyMeters: value.accuracyMeters, syncedToServer: true,
    );
    await cache.save(restaurantId, confirmed);
    return confirmed;
  }
}
