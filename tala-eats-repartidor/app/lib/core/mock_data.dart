import '../models/delivery.dart';
import '../models/driver_profile.dart';

/// DATOS LOCALES DE DISEÑO (mock).
///
/// Todo el contenido de ejemplo vive aquí para que la integración con el
/// backend real lo reemplace en un solo lugar. No contiene credenciales,
/// tokens, URLs ni endpoints.
abstract final class MockData {
  static const DriverProfile profile = DriverProfile(
    firstName: 'Alex',
    fullName: 'Alex Ramírez',
    zone: 'Tala, Jalisco',
    vehicleType: 'Motocicleta',
    plateSuffix: '82',
    verified: true,
    documents: [
      DriverDocument(
        name: 'Identificación oficial',
        status: DocumentStatus.verified,
      ),
      DriverDocument(
        name: 'Licencia de conducir',
        status: DocumentStatus.verified,
      ),
      DriverDocument(
        name: 'Tarjeta de circulación',
        status: DocumentStatus.verified,
      ),
    ],
  );

  static const DeliveryJob activeJob = DeliveryJob(
    id: 'TE-2841',
    restaurant: 'La Burguesa Tala',
    restaurantAddress: 'Av. Solidaridad 218, Tala, Jal.',
    customer: 'Mariana R.',
    customerAddress: 'Col. Centro, Tala, Jal.',
    total: 286.00,
    earning: 47.50,
    distanceKm: 4.7,
    etaMinutes: 18,
    stage: DeliveryStage.assigned,
    note: 'Entregar en recepción. No tocar el timbre.',
  );

  /// Entregas completadas en la jornada, de la más reciente a la más antigua.
  /// La hora se calcula relativa a [now] para que siempre sea coherente.
  static List<DeliveryJob> history(DateTime now) {
    DeliveryJob done(
      String id,
      String restaurant,
      String customer,
      String customerAddress,
      double total,
      double earning,
      double km,
      int minutesAgo,
    ) =>
        DeliveryJob(
          id: id,
          restaurant: restaurant,
          restaurantAddress: 'Tala, Jal.',
          customer: customer,
          customerAddress: customerAddress,
          total: total,
          earning: earning,
          distanceKm: km,
          etaMinutes: (km * 4).round(),
          stage: DeliveryStage.delivered,
          completedAt: now.subtract(Duration(minutes: minutesAgo)),
        );

    return [
      done('TE-2838', 'Tacos Don Chuy', 'Luis A.', 'El Refugio', 174, 39.50,
          3.8, 26),
      done('TE-2834', 'Pizza Centro', 'Andrea M.', 'Los Ruiseñores', 352,
          58.00, 6.1, 64),
      done('TE-2829', 'Sushi Nori', 'Carlos V.', 'La Higuera', 419, 64.00,
          7.4, 109),
      done('TE-2823', 'Mariscos El Güero', 'Fernanda L.', 'Col. Centro', 268,
          71.50, 4.2, 158),
      done('TE-2817', 'Café Portal', 'Jorge P.', 'San Antonio', 198, 52.00,
          3.5, 203),
      done('TE-2812', 'Pollos La Granja', 'Rocío D.', 'Las Moras', 455, 83.50,
          5.6, 247),
      done('TE-2806', 'Tortas Ahogadas Tala', 'Miguel S.', 'El Llano', 312,
          70.00, 4.2, 291),
    ];
  }

  /// Ganancias de lunes a domingo de la semana en curso (días ya cerrados).
  /// El día actual se sustituye por la ganancia viva de la jornada.
  static const List<double> weekEarnings = [
    512.00,
    468.50,
    395.00,
    604.50,
    548.00,
    702.00,
    455.50,
  ];

  /// Minutos conectado hoy.
  static const int onlineMinutesToday = 342;

  /// Porcentaje de aceptación.
  static const int acceptance = 96;
}
