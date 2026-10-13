part of '../main.dart';

// ---------------------------------------------------------------------------
// Legal documents. Text is unchanged from v1.0.8; only typography/layout.
// ---------------------------------------------------------------------------

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y Condiciones')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
        children: const <Widget>[
          LegalDocumentHeader(title: 'Términos y Condiciones de Uso', updated: 'Última actualización: 7 de octubre de 2026'),
          LegalSection(title: '1. Uso de Tala Eats', body: 'Tala Eats permite consultar comercios participantes, seleccionar productos, realizar pedidos y dar seguimiento a su estado. Debes proporcionar información verdadera, mantener segura tu cuenta y utilizar el servicio únicamente para fines lícitos.'),
          LegalSection(title: '2. Pedidos y disponibilidad', body: 'Los productos, horarios, existencias, zonas de cobertura, tiempos estimados y condiciones de entrega dependen de la disponibilidad informada por cada comercio y de la operación de Tala Eats. El pedido queda sujeto a confirmación del sistema y del comercio correspondiente.'),
          LegalSection(title: '3. Precios, cargos y pagos', body: 'Antes de confirmar un pedido se mostrará el importe aplicable, incluyendo productos, entrega, propina y cargos o descuentos vigentes. Los pagos electrónicos se procesan mediante proveedores externos autorizados. Tala Eats no debe considerar un pago aprobado hasta recibir confirmación del servidor y del proveedor de pago.'),
          LegalSection(title: '4. Cancelaciones y reembolsos', body: 'Las posibilidades de cancelar, modificar o reembolsar un pedido dependen del estado del pedido, de la preparación realizada y de las políticas vigentes mostradas al usuario. Cuando corresponda, los reembolsos se tramitarán por el medio y plazo aplicable.'),
          LegalSection(title: '5. Entrega y recogida', body: 'Debes proporcionar una dirección y ubicación correctas cuando solicites entrega. Para pedidos de recogida, eres responsable de acudir al comercio indicado. Los tiempos mostrados son estimados y pueden variar por demanda, tráfico, clima, operación del comercio u otras circunstancias.'),
          LegalSection(title: '6. Promociones y beneficios', body: 'Cupones, puntos, recompensas y promociones pueden tener vigencia, disponibilidad, límites y condiciones específicas. Su aplicación final será la que valide el servidor de Tala Eats al procesar el pedido.'),
          LegalSection(title: '7. Conducta y seguridad', body: 'No está permitido intentar vulnerar el servicio, usar cuentas ajenas, realizar pedidos fraudulentos, abusar de promociones ni utilizar Tala Eats de forma que afecte a comercios, repartidores, usuarios o a la plataforma.'),
          LegalSection(title: '8. Disponibilidad del servicio', body: 'Tala Eats puede realizar mantenimiento, corregir errores, suspender temporalmente funciones o modificar características cuando sea necesario para seguridad, operación o cumplimiento. Se procurará informar los cambios relevantes cuando corresponda.'),
          LegalSection(title: '9. Soporte', body: 'Si tienes un problema con tu cuenta, pedido o pago, utiliza los canales de soporte disponibles en la aplicación. Conserva la información del pedido para facilitar la atención.'),
        ],
      ),
    );
  }
}

class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key, required this.supportEmail});
  final String supportEmail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aviso de Privacidad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
        children: <Widget>[
          const LegalDocumentHeader(title: 'Aviso de Privacidad', updated: 'Última actualización: 7 de octubre de 2026'),
          const LegalSection(title: 'Datos que podemos tratar', body: 'Según las funciones que utilices, Tala Eats puede tratar datos de cuenta y contacto, direcciones y ubicación para entrega, información de pedidos, preferencias, comunicaciones de soporte, datos técnicos de seguridad y referencias necesarias para procesar pagos mediante proveedores externos.'),
          const LegalSection(title: 'Finalidades principales', body: 'Los datos se utilizan para crear y administrar tu cuenta, autenticarte, procesar y entregar pedidos, calcular cobertura y tarifas, atender soporte, prevenir fraude, proteger la seguridad del servicio, generar comprobaciones operativas y cumplir obligaciones aplicables.'),
          const LegalSection(title: 'Proveedores y comercios', body: 'La información estrictamente necesaria puede compartirse con comercios, repartidores, proveedores de pago, infraestructura, mensajería o servicios técnicos que participen en la operación del pedido o de la plataforma, conforme a sus funciones y a la normativa aplicable.'),
          const LegalSection(title: 'Ubicación', body: 'Cuando solicites entrega, Tala Eats puede utilizar la dirección o ubicación que autorices para validar cobertura, calcular tarifas y facilitar la entrega. Puedes administrar tus direcciones desde la aplicación y los permisos de ubicación desde Android.'),
          const LegalSection(title: 'Seguridad y conservación', body: 'Tala Eats aplica medidas técnicas y organizativas para proteger la información. La sesión móvil se almacena mediante mecanismos seguros del dispositivo. La información se conserva durante el tiempo necesario para las finalidades descritas y para obligaciones legales, de seguridad, prevención de fraude o resolución de disputas.'),
          const LegalSection(title: 'Tus decisiones y derechos', body: 'Desde la sección Privacidad puedes administrar preferencias disponibles y solicitar acceso o exportación de tus datos y, cuando proceda, la eliminación de tu cuenta. Algunas obligaciones legales o de seguridad pueden requerir conservar determinada información durante un periodo adicional.'),
          LegalSection(title: 'Contacto', body: 'Para solicitudes relacionadas con privacidad o soporte puedes utilizar la sección Ayuda y soporte o escribir a $supportEmail.'),
        ],
      ),
    );
  }
}

class LegalDocumentHeader extends StatelessWidget {
  const LegalDocumentHeader({super.key, required this.title, required this.updated});

  final String title;
  final String updated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: kSoftOrange, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.description_outlined, color: kBrandDeep),
          ),
          const SizedBox(height: 14),
          Text(title, style: TalaText.h1),
          const SizedBox(height: 6),
          Text(updated, style: TalaText.caption),
        ],
      ),
    );
  }
}

class LegalSection extends StatelessWidget {
  const LegalSection({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TalaText.title),
          const SizedBox(height: 6),
          Text(body, style: TalaText.body.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}
