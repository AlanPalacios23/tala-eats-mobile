// Vista PRELIMINAR de precios. No interviene en pedidos ni en cobros.
// El backend FastAPI es el origen de verdad y registra valores finales.
import 'dart:math' as math;

class CheckoutPricingPolicy {
  const CheckoutPricingPolicy({required this.serviceFeeRate, required this.baseDeliveryFee,
    this.serviceFeeCap, this.deliveryIncludedKm, this.deliveryPerAdditionalKm, this.version = '1.5.2'});

  final double serviceFeeRate;
  final double baseDeliveryFee;
  final double? serviceFeeCap;
  final double? deliveryIncludedKm;
  final double? deliveryPerAdditionalKm;
  final String version;

  static CheckoutPricingPolicy? fromPaymentMethods(Map<dynamic, dynamic> response) {
    // La API puede desactivar la politica comercial y volver a legacy.
    final String version = '${response['commercial_pricing_version'] ?? ''}';
    if (version != '1.5.2' && version != '1.6.2') return null;
    final double? rate = double.tryParse('${response['service_fee_rate'] ?? ''}');
    final double? delivery = double.tryParse('${response['delivery_base_fee'] ?? ''}');
    if (rate == null || !rate.isFinite || rate < 0 || rate > 0.25) return null;
    if (delivery == null || !delivery.isFinite || delivery < 0 || delivery > 10000) return null;
    if (version == '1.6.2') {
      final double? cap = double.tryParse('${response['service_fee_cap'] ?? ''}');
      final double? km = double.tryParse('${response['delivery_included_km'] ?? ''}');
      final double? perKm = double.tryParse('${response['delivery_additional_per_km'] ?? ''}');
      if (cap == null || !cap.isFinite || cap < 0 || cap > 10000 ||
          km == null || !km.isFinite || km < 0 || km > 100 ||
          perKm == null || !perKm.isFinite || perKm < 0 || perKm > 1000) return null;
      return CheckoutPricingPolicy(serviceFeeRate: rate, baseDeliveryFee: delivery,
        serviceFeeCap: cap, deliveryIncludedKm: km, deliveryPerAdditionalKm: perKm, version: version);
    }
    return CheckoutPricingPolicy(serviceFeeRate: rate, baseDeliveryFee: delivery);
  }
}

class CheckoutPricingPreview {
  const CheckoutPricingPreview({
    required this.policy,
    required this.merchandiseSubtotal,
    required this.restaurantDeliveryFee,
    required this.deliveryMode,
    required this.tip,
    required this.hasCoupon,
    required this.plusMember,
  });

  final CheckoutPricingPolicy? policy;
  final double merchandiseSubtotal;
  final double restaurantDeliveryFee;
  final String deliveryMode;
  final double tip;
  final bool hasCoupon;
  final bool plusMember;

  bool get available => policy != null;
  bool get delivery => deliveryMode == 'delivery';
  int get _foodCents => (math.max(0.0, merchandiseSubtotal) * 100).round();
  int get _tipCents => delivery ? (math.max(0.0, tip) * 100).round() : 0;

  // Reproduce el redondeo HALF_UP al centavo del backend en importes positivos.
  int? get serviceFeeCents {
    final p = policy;
    if (p == null) return null;
    final rateParts = (p.serviceFeeRate * 10000).round();
    final int fee = ((_foodCents * rateParts) + 5000) ~/ 10000;
    if (p.serviceFeeCap == null) return fee;
    return math.min(fee, (p.serviceFeeCap! * 100).round());
  }

  double? get serviceFee => serviceFeeCents == null ? null : serviceFeeCents! / 100;
  // Referencia base: el backend agrega distancia y puede aplicar Plus.
  // No presentar este valor como cotizacion definitiva.
  double? get deliveryReference {
    final p = policy;
    if (p == null) return null;
    if (!delivery) return 0;
    if (p.version == '1.6.2') return p.baseDeliveryFee; // Monto BASE leído del servidor: nunca la cotización final.
    return math.max(p.baseDeliveryFee, math.max(0.0, restaurantDeliveryFee));
  }

  double? get estimatedReferenceTotal {
    final shipping = deliveryReference;
    final service = serviceFeeCents;
    if (shipping == null || service == null) return null;
    return (_foodCents + (shipping * 100).round() + service + _tipCents) / 100;
  }

  String get disclosure {
    if (policy == null) return 'El servidor calculará la tarifa de servicio y el envío al crear tu pedido.';
    if (hasCoupon || plusMember) {
      return 'Referencia antes de cupones y beneficios Plus. El envío real depende de la distancia; el servidor confirma el total.';
    }
    if (!delivery) return 'Pedido para recoger, sin cargo de envío. El servidor confirma los importes antes del cobro.';
    if (policy!.version == '1.6.2') {
      final p = policy!;
      final double km = p.deliveryIncludedKm ?? 0;
      final String kmLabel = km == km.roundToDouble()
          ? km.toStringAsFixed(0) : km.toStringAsFixed(1);
      return 'Referencia de envío desde ${moneyWithCents(p.baseDeliveryFee)} hasta ${kmLabel} km y ${moneyWithCents(p.deliveryPerAdditionalKm ?? 0)} por km adicional. Es referencia, no cotización definitiva; el servidor confirma el importe según GPS.';
    }
    return 'Importe estimado. El envío puede subir por distancia y los precios/promociones se verifican al confirmar el pedido.';
  }
}

String moneyWithCents(double value) => '${value < 0 ? '-' : ''}\$${value.abs().toStringAsFixed(2)}';
