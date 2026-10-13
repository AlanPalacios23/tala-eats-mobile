import 'package:flutter/material.dart';

import '../models/delivery.dart';
import '../widgets/common.dart';

/// Presentación de cada etapa: título, instrucción, CTA y feedback de éxito.
///
/// Es la única tabla de copy del flujo; la integración solo debe mapear los
/// estados del backend a [DeliveryStage] y esta UI se mantiene intacta.
class StagePresentation {
  const StagePresentation({
    required this.title,
    required this.instruction,
    required this.cta,
    required this.ctaIcon,
    required this.phase,
    this.reachedMessage,
  });

  final String title;
  final String instruction;
  final String cta;
  final IconData ctaIcon;

  /// "Recogida" o "Entrega".
  final String phase;

  /// Feedback breve al LLEGAR a esta etapa (confirmación de la acción previa).
  final String? reachedMessage;

  static StagePresentation of(DeliveryJob job) => switch (job.stage) {
        DeliveryStage.assigned => StagePresentation(
            title: 'Nuevo pedido asignado',
            instruction:
                'Recoge en ${job.restaurant}. Ganas ${money(job.earning)}.',
            cta: 'Ir al restaurante',
            ctaIcon: Icons.near_me_rounded,
            phase: 'Recogida',
          ),
        DeliveryStage.toRestaurant => StagePresentation(
            title: 'Ve al restaurante',
            instruction: job.restaurantAddress,
            cta: 'Llegué al restaurante',
            ctaIcon: Icons.storefront_rounded,
            phase: 'Recogida',
            reachedMessage: 'Ruta al restaurante iniciada',
          ),
        DeliveryStage.atRestaurant => StagePresentation(
            title: 'En el restaurante',
            instruction: 'Verifica que el pedido sea ${job.id} antes de '
                'recogerlo.',
            cta: 'Confirmar recogida',
            ctaIcon: Icons.shopping_bag_rounded,
            phase: 'Recogida',
            reachedMessage: 'Llegada registrada',
          ),
        DeliveryStage.pickedUp => StagePresentation(
            title: 'Pedido recogido',
            instruction: 'Cuando estés listo, inicia la ruta con '
                '${job.customer}.',
            cta: 'Ir con el cliente',
            ctaIcon: Icons.near_me_rounded,
            phase: 'Entrega',
            reachedMessage: 'Recogida confirmada',
          ),
        DeliveryStage.toCustomer => StagePresentation(
            title: 'En camino al cliente',
            instruction: job.customerAddress,
            cta: 'Confirmar entrega',
            ctaIcon: Icons.verified_rounded,
            phase: 'Entrega',
            reachedMessage: 'Ruta al cliente iniciada',
          ),
        DeliveryStage.delivered => const StagePresentation(
            title: 'Entrega completada',
            instruction: 'La ganancia ya se sumó a tu jornada.',
            cta: 'Listo',
            ctaIcon: Icons.check_rounded,
            phase: 'Completada',
            reachedMessage: 'Entrega completada',
          ),
      };
}
