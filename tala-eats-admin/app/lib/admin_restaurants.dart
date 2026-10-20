import 'package:flutter/material.dart';
import 'admin_api.dart';

/// Operaciones mínimas: consulta, suspensión y archivado seguro de comercios.
class AdminRestaurantsPanel extends StatefulWidget {
  const AdminRestaurantsPanel({super.key, required this.restaurants,
      required this.busy, required this.onAction, this.error});
  final List<Map<String, dynamic>> restaurants;
  final bool busy;
  final String? error;
  final Future<bool> Function(int id, String action,
      String confirmName, String reason) onAction;

  @override
  State<AdminRestaurantsPanel> createState() => _AdminRestaurantsPanelState();
}

class _AdminRestaurantsPanelState extends State<AdminRestaurantsPanel> {
  String filter = 'inactive';

  Future<void> _suspend(Map<String, dynamic> shop) async {
    final id = (shop['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Suspender restaurante'),
        content: Text('¿Suspender ${shop['name']}? El comercio dejará '
            'de recibir nuevos pedidos. No se cancelan los pedidos existentes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Suspender')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await widget.onAction(id, 'suspend', '', '');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Restaurante suspendido.'
          : widget.error ?? 'No se pudo suspender.'),
    ));
  }

  Future<void> _archive(Map<String, dynamic> shop) async {
    final id = (shop['id'] as num?)?.toInt() ?? 0;
    final name = shop['name']?.toString() ?? '';
    if (id <= 0 || name.isEmpty || shop['can_archive'] != true) return;
    final typed = TextEditingController();
    final reason = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Archivar restaurante inactivo'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Se ocultará "$name" del catálogo y se bloqueará '
                  'la operación de su cuenta de comercio. '
                  'Los pedidos y registros contables permanecerán intactos.'),
              const SizedBox(height: 14),
              Text('Escribe exactamente "$name" para confirmar.',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 7),
              TextField(controller: typed,
                decoration: const InputDecoration(
                  labelText: 'Nombre del restaurante', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(controller: reason, maxLength: 300, maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo (mín. 10 caracteres)',
                  border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (typed.text != name || reason.text.trim().length < 10) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
                    content: Text('Confirma el nombre exacto y agrega un motivo.')));
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Archivar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final ok = await widget.onAction(id, 'archive', name, reason.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Restaurante archivado. Historial conservado.'
            : widget.error ?? 'No se pudo archivar.'),
      ));
    } finally {
      typed.dispose();
      reason.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.restaurants.where((shop) {
      final archived = shop['verification_status'] == 'archived';
      if (filter == 'inactive') return shop['is_open'] == false && !archived;
      if (filter == 'archived') return archived;
      return true;
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Gestiona comercios sin borrar pedidos, reseñas ni movimientos.',
        style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 5, children: [
        ChoiceChip(label: const Text('Inactivos'), selected: filter == 'inactive',
          onSelected: (_) => setState(() => filter = 'inactive')),
        ChoiceChip(label: const Text('Todos'), selected: filter == 'all',
          onSelected: (_) => setState(() => filter = 'all')),
        ChoiceChip(label: const Text('Archivados'), selected: filter == 'archived',
          onSelected: (_) => setState(() => filter = 'archived')),
      ]),
      if (!kAdminWritesEnabled) const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Modo consulta. Suspensión y archivo requieren '
          'un build habilitado expresamente para staging.',
          style: TextStyle(color: Colors.black54)),
      ),
      if (visible.isEmpty) const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No hay restaurantes con este filtro.')),
      ...visible.map((shop) {
        final name = shop['name']?.toString() ?? 'Restaurante';
        final archived = shop['verification_status'] == 'archived';
        final open = shop['is_open'] == true;
        final activeOrders = shop['active_orders'] ?? 0;
        final canArchive = shop['can_archive'] == true;
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9EBF0)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.storefront_outlined, color: Color(0xFFF56A21)),
              const SizedBox(width: 9),
              Expanded(child: Text(name, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800))),
              Chip(label: Text(archived ? 'Archivado' : open ? 'Abierto' : 'Cerrado')),
            ]),
            Text('ID #${shop['id']} · ${shop['market_code'] ?? '—'} · '
                'Propietario #${shop['owner_id'] ?? '—'}',
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 7),
            Text('Pedidos sin finalizar: $activeOrders',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (shop['last_order_at'] != null) Text(
              'Último pedido: ${shop['last_order_at']}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (!canArchive && !open && !archived && activeOrders != 0)
              const Padding(padding: EdgeInsets.only(top: 5),
                child: Text('No se permite archivar mientras existan pedidos pendientes.',
                    style: TextStyle(color: Color(0xFFB95421), fontSize: 12))),
            if (kAdminWritesEnabled && !archived) ...[
              const SizedBox(height: 11),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (open) OutlinedButton.icon(
                  onPressed: widget.busy ? null : () => _suspend(shop),
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Suspender'),
                ),
                if (canArchive) FilledButton.tonalIcon(
                  onPressed: widget.busy ? null : () => _archive(shop),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Archivar'),
                ),
              ]),
            ],
          ]),
        );
      }),
    ]);
  }
}
