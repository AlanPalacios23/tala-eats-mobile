/// Secuencia de estados de una entrega (sin cambios de negocio vs v0.2.0).
///
/// `assigned → toRestaurant → atRestaurant → pickedUp → toCustomer → delivered`
enum DeliveryStage {
  assigned,
  toRestaurant,
  atRestaurant,
  pickedUp,
  toCustomer,
  delivered,
}

/// Número de pasos que recorre la barra de progreso (assigned = 0).
const int kDeliverySteps = 5;

class DeliveryJob {
  const DeliveryJob({
    required this.id,
    this.serverId,
    required this.restaurant,
    required this.restaurantAddress,
    this.restaurantLat,
    this.restaurantLng,
    required this.customer,
    required this.customerAddress,
    this.customerPhone,
    this.customerLat,
    this.customerLng,
    required this.total,
    required this.earning,
    required this.distanceKm,
    required this.etaMinutes,
    required this.stage,
    this.note,
    this.completedAt,
  });

  /// Identificador visible del pedido (p. ej. `TE-2841`).
  final String id;
  final int? serverId;
  final String restaurant;
  final String restaurantAddress;
  final double? restaurantLat;
  final double? restaurantLng;
  final String customer;
  final String customerAddress;
  final String? customerPhone;
  final double? customerLat;
  final double? customerLng;

  /// Total del pedido pagado por el cliente. NO es ganancia del repartidor.
  final double total;

  /// Ganancia del repartidor por esta entrega.
  final double earning;
  final double distanceKm;
  final int etaMinutes;
  final DeliveryStage stage;

  /// Indicaciones del cliente para la entrega.
  final String? note;

  /// Momento en que se completó (solo entregas finalizadas).
  final DateTime? completedAt;

  DeliveryJob copyWith({DeliveryStage? stage, DateTime? completedAt}) =>
      DeliveryJob(
        id: id,
        serverId: serverId,
        restaurant: restaurant,
        restaurantAddress: restaurantAddress,
        restaurantLat: restaurantLat,
        restaurantLng: restaurantLng,
        customer: customer,
        customerAddress: customerAddress,
        customerPhone: customerPhone,
        customerLat: customerLat,
        customerLng: customerLng,
        total: total,
        earning: earning,
        distanceKm: distanceKm,
        etaMinutes: etaMinutes,
        stage: stage ?? this.stage,
        note: note,
        completedAt: completedAt ?? this.completedAt,
      );
}

extension DeliveryStageX on DeliveryStage {
  /// Etiqueta corta del estado (se conserva el copy de v0.2.0).
  String get label => switch (this) {
        DeliveryStage.assigned => 'Pedido asignado',
        DeliveryStage.toRestaurant => 'Ve al restaurante',
        DeliveryStage.atRestaurant => 'En el restaurante',
        DeliveryStage.pickedUp => 'Pedido recogido',
        DeliveryStage.toCustomer => 'En camino al cliente',
        DeliveryStage.delivered => 'Entregado',
      };

  /// Posición en la secuencia: 0 (asignado) … 5 (entregado).
  int get step => switch (this) {
        DeliveryStage.assigned => 0,
        DeliveryStage.toRestaurant => 1,
        DeliveryStage.atRestaurant => 2,
        DeliveryStage.pickedUp => 3,
        DeliveryStage.toCustomer => 4,
        DeliveryStage.delivered => 5,
      };

  /// La ruta ya empezó y aún no termina (bloquea desconexión y cierre de sesión).
  bool get inProgress =>
      this != DeliveryStage.assigned && this != DeliveryStage.delivered;

  /// Fase de recogida (restaurante) vs fase de entrega (cliente).
  bool get isPickupPhase => step <= 2;
}
