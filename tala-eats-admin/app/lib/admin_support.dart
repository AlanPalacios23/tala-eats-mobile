import 'package:flutter/material.dart';
import 'admin_api.dart';

/// Bandeja basada en tickets enviados por Tala Eats Usuarios.
/// No crea un sistema de soporte paralelo.
class AdminSupportPanel extends StatefulWidget {
  const AdminSupportPanel({super.key, required this.tickets, required this.busy,
    required this.onRespond, this.error});
  final List<Map<String, dynamic>> tickets;
  final bool busy;
  final String? error;
  final Future<bool> Function(int id, String status, String reply) onRespond;

  @override
  State<AdminSupportPanel> createState() => _AdminSupportPanelState();
}

class _AdminSupportPanelState extends State<AdminSupportPanel> {
  String filter = 'pending';

  Future<void> _resolve(Map<String, dynamic> ticket) async {
    final id = (ticket['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    final response = TextEditingController();
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Responder ticket #$id'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Cliente: ${ticket['customer_name'] ?? '—'}\n'
              'Pedido: ${ticket['order_id'] ?? 'Sin pedido'}'),
            const SizedBox(height: 12),
            TextField(
              controller: response,
              minLines: 3, maxLines: 6, maxLength: 3000,
              decoration: const InputDecoration(
                labelText: 'Respuesta que verá el cliente',
                hintText: 'Describe cómo podemos ayudar…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Al enviar, el ticket se cerrará y el cliente recibirá '
                'la respuesta en Ayuda y en Notificaciones.',
                style: TextStyle(fontSize: 12)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (response.text.trim().length < 10) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Escribe al menos 10 caracteres.')));
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Enviar respuesta'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      final ok = await widget.onRespond(id, 'resolved', response.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Respuesta enviada y ticket resuelto.'
          : widget.error ?? 'No se pudo responder al cliente.'),
      ));
    } finally {
      response.dispose();
    }
  }

  Future<void> _take(Map<String, dynamic> ticket) async {
    final id = (ticket['id'] as num?)?.toInt() ?? 0;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Tomar ticket #$id'),
        content: const Text('¿Cambiar su estado a En atención?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final ok = await widget.onRespond(id, 'in_progress', '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Ticket marcado En atención.'
          : widget.error ?? 'No se pudo actualizar.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.tickets.where((ticket) {
      final status = ticket['status']?.toString() ?? '';
      if (filter == 'pending') return status != 'resolved';
      if (filter == 'resolved') return status == 'resolved';
      return true;
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Aquí llegan las solicitudes enviadas desde la app Usuarios.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 4, children: [
        ChoiceChip(label: const Text('Pendientes'), selected: filter == 'pending',
            onSelected: (_) => setState(() => filter = 'pending')),
        ChoiceChip(label: const Text('Resueltos'), selected: filter == 'resolved',
            onSelected: (_) => setState(() => filter = 'resolved')),
        ChoiceChip(label: const Text('Todos'), selected: filter == 'all',
            onSelected: (_) => setState(() => filter = 'all')),
      ]),
      const SizedBox(height: 13),
      if (!kAdminWritesEnabled)
        const _MutedInfo('Modo de consulta. La respuesta y el cambio de estado '
          'solo se habilitan en compilaciones autorizadas para staging.'),
      if (visible.isEmpty)
        const _MutedInfo('No se encontraron tickets con este filtro.'),
      ...visible.map((ticket) {
        final id = ticket['id'] ?? '—';
        final status = ticket['status']?.toString() ?? 'open';
        final resolved = status == 'resolved';
        final reply = ticket['admin_reply']?.toString() ?? '';
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9EBF0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Ticket #$id',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              Chip(label: Text(resolved ? 'Resuelto'
                : status == 'in_progress' ? 'En atención' : 'Abierto')),
            ]),
            Text('${ticket['customer_name'] ?? 'Cliente'} · '
              '${ticket['customer_email'] ?? ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 5),
            Text('Pedido: ${ticket['order_id'] ?? 'No asociado'} · '
                '${ticket['category'] ?? 'general'}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 10),
            SelectableText(ticket['message']?.toString() ?? '',
              style: const TextStyle(fontSize: 14, height: 1.35)),
            if (reply.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('Respuesta enviada', style: TextStyle(
                fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              SelectableText(reply),
            ],
            if (!resolved && kAdminWritesEnabled) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 7, runSpacing: 7, children: [
                if (status == 'open') OutlinedButton.icon(
                  onPressed: widget.busy ? null : () => _take(ticket),
                  icon: const Icon(Icons.pending_actions_outlined),
                  label: const Text('Tomar'),
                ),
                FilledButton.icon(
                  onPressed: widget.busy ? null : () => _resolve(ticket),
                  icon: const Icon(Icons.reply_rounded),
                  label: const Text('Responder'),
                ),
              ]),
            ],
          ]),
        );
      }),
    ]);
  }
}

class _MutedInfo extends StatelessWidget {
  const _MutedInfo(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(message, style: const TextStyle(color: Colors.black54)),
  );
}
