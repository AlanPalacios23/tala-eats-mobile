// Ubicación del establecimiento (v0.5.15).
//
// La dirección la escribe el restaurante; las coordenadas vienen del GPS del
// teléfono cuando el restaurante toca «Usar mi ubicación». La app no calcula
// distancias ni costos de envío: eso lo hace el backend con estos datos.

class RestaurantLocation {
  const RestaurantLocation({
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.postalCode,
    this.references = '',
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.syncedToServer = false,
  });

  factory RestaurantLocation.fromJson(Map<String, dynamic> json) {
    double? number(Object? value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return RestaurantLocation(
      street: '${json['street'] ?? ''}'.trim(),
      neighborhood: '${json['neighborhood'] ?? ''}'.trim(),
      city: '${json['city'] ?? ''}'.trim(),
      postalCode: '${json['postal_code'] ?? ''}'.trim(),
      references: '${json['references'] ?? ''}'.trim(),
      latitude: number(json['latitude']),
      longitude: number(json['longitude']),
      accuracyMeters: number(json['accuracy_m']),
      syncedToServer: json['synced'] == true,
    );
  }

  /// Calle y número exterior/interior.
  final String street;
  final String neighborhood;
  final String city;
  final String postalCode;

  /// Indicaciones para el repartidor (entre calles, color de fachada…).
  final String references;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;

  /// `true` solo cuando el backend confirmó que la recibió.
  final bool syncedToServer;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isComplete =>
      street.isNotEmpty &&
      neighborhood.isNotEmpty &&
      city.isNotEmpty &&
      postalCode.length == 5;

  /// «Av. Juárez 184, Centro, Tala, 45300»
  String get singleLine => <String>[
        street,
        neighborhood,
        city,
        postalCode,
      ].where((part) => part.isNotEmpty).join(', ');

  /// «20.65441, -103.70122»
  String? get coordinatesLabel => hasCoordinates
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'street': street,
        'neighborhood': neighborhood,
        'city': city,
        'postal_code': postalCode,
        'references': references,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyMeters,
        'synced': syncedToServer,
      };

  RestaurantLocation copyWith({bool? syncedToServer}) => RestaurantLocation(
        street: street,
        neighborhood: neighborhood,
        city: city,
        postalCode: postalCode,
        references: references,
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracyMeters,
        syncedToServer: syncedToServer ?? this.syncedToServer,
      );
}

/// Punto GPS leído del teléfono.
class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}
