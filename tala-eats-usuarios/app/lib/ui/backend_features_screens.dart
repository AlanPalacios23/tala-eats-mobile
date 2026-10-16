part of '../main.dart';

// Only customer-owned devices via /auth/devices; current session cannot be
// silently revoked. No locally invented "connected devices" or account state.
class CustomerDeviceSessionsScreen extends StatefulWidget {
  const CustomerDeviceSessionsScreen({super.key, required this.model});
  final TalaModel model;
  @override
  State<CustomerDeviceSessionsScreen> createState() => _CustomerDeviceSessionsScreenState();
}

class _CustomerDeviceSessionsScreenState extends State<CustomerDeviceSessionsScreen> {
  List<Map<String, dynamic>> devices = <Map<String, dynamic>>[];
  String error = '';
  bool loading = true;
  bool busy = false;

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() { loading = true; error = ''; });
    try {
      final rows = await widget.model.api.customerDevices();
      if (mounted) setState(() { devices = rows; loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() {
        loading = false;
        error = e.statusCode == 404
          ? 'La versión del servidor instalada aún no admite administrar sesiones.'
          : e.message;
      });
    } catch (_) {
      if (mounted) setState(() {
        loading = false; error = 'No se pudieron consultar tus sesiones.';
      });
    }
  }

  Future<bool> confirm(String title, String explanation) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(title: Text(title),
        content: Text(explanation),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar')),
        ],
      ),
    ) ?? false;
  }

  Future<void> revoke(int id) async {
    if (busy || id <= 0) return;
    if (!await confirm('Cerrar sesión del dispositivo',
        'Ese dispositivo tendrá que iniciar sesión nuevamente.')) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final outcome = await widget.model.api.revokeCustomerDevice(id);
      if (outcome['revoked'] != true) throw ApiException(502, 'El servidor no confirmó la revocación.');
      if (!mounted) return;
      if (outcome['current'] == true) {
        widget.model.logout();
        Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
        return;
      }
      await refresh();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo cerrar la sesión.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> revokeOthers() async {
    if (busy) return;
    if (!await confirm('Cerrar las demás sesiones',
        'Este teléfono permanecerá conectado; los demás deberán iniciar sesión otra vez.')) return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final result = await widget.model.api.revokeOtherCustomerDevices();
      if (result['revoked'] is! int) throw ApiException(502, 'No se confirmó el cierre.');
      await refresh();
      if (mounted) showMessage(context, 'Sesiones cerradas: ' + result['revoked'].toString());
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudieron cerrar las sesiones.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final others = devices.where((d) => d['active'] == true && d['current'] != true).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis dispositivos'),
        actions: <Widget>[IconButton(icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Actualizar', onPressed: busy ? null : refresh)]),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: <Widget>[
            const Text('Revisa los dispositivos donde has iniciado sesión.',
              style: TalaText.muted),
            const SizedBox(height: 14),
            if (error.isNotEmpty) AuthNotice(
              icon: Icons.error_outline_rounded, text: error, danger: true),
            if (loading)
              const Center(child: Padding(padding: EdgeInsets.all(24),
                child: CircularProgressIndicator()))
            else if (devices.isEmpty && error.isEmpty)
              const TalaCard(padding: EdgeInsets.all(16),
                child: Text('No hay sesiones para mostrar.', style: TalaText.muted))
            else
              for (final device in devices) ...<Widget>[
                TalaCard(padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(children: <Widget>[
                        const Icon(Icons.devices_rounded, color: kBrand),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          (device['device_label'] ?? 'Dispositivo').toString(),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                      ]),
                      const SizedBox(height: 6),
                      Text(device['current'] == true ? 'Este teléfono'
                            : (device['active'] == true ? 'Sesión activa' : 'Sesión cerrada'),
                        style: TalaText.muted),
                      if (device['platform'] != null)
                        Text('Plataforma: ' + device['platform'].toString(),
                          style: TalaText.caption),
                      if (device['active'] == true && device['current'] != true)
                        Align(alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: busy ? null :
                              () => revoke(int.tryParse(device['id'].toString()) ?? 0),
                            child: const Text('Cerrar acceso'))),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            if (!loading && others > 0)
              OutlinedButton.icon(onPressed: busy ? null : revokeOthers,
                icon: const Icon(Icons.phonelink_erase_rounded),
                label: const Text('Cerrar todas las demás')),
          ],
        ),
      ),
    );
  }
}

// V11 customer-only order changes. HTTP 404/403 must never be shown as
// successful resolution. Refund amounts/status are always provider-sourced.
class CustomerOrderAdjustmentsScreen extends StatefulWidget {
  const CustomerOrderAdjustmentsScreen({
    super.key, required this.model, required this.order,
  });
  final TalaModel model;
  final OrderEntry order;
  @override
  State<CustomerOrderAdjustmentsScreen> createState() => _CustomerOrderAdjustmentsScreenState();
}

class _CustomerOrderAdjustmentsScreenState extends State<CustomerOrderAdjustmentsScreen> {
  List<Map<String, dynamic>> changes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> refunds = <Map<String, dynamic>>[];
  bool loading = true;
  bool busy = false;
  String error = '';

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() { loading = true; error = ''; });
    try {
      final nextChanges = await widget.model.api.orderSubstitutions(widget.order.id);
      final nextRefunds = await widget.model.api.orderRefunds(widget.order.id);
      if (mounted) setState(() {
        changes = nextChanges; refunds = nextRefunds; loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() {
        loading = false;
        error = e.statusCode == 404
            ? 'Este backend todavía no dispone de cambios y reembolsos V11.'
            : e.message;
      });
    } catch (_) {
      if (mounted) setState(() {
        loading = false; error = 'No pudimos consultar los ajustes del pedido.';
      });
    }
  }

  Future<void> respond(Map<String, dynamic> row, String action) async {
    if (busy || row['status'] != 'pending') return;
    final id = int.tryParse(row['id'].toString()) ?? 0;
    if (id <= 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar decisión'),
        content: const Text('El restaurante recibirá tu decisión. Solo el servidor puede confirmar y calcular un reembolso.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar')),
        ],
      ),
    ) ?? false;
    if (!confirmed || !mounted) return;
    setState(() => busy = true);
    try {
      final answer = await widget.model.api.respondOrderSubstitution(widget.order.id, id, action);
      if (answer['status'] != 'resolved') throw ApiException(502, 'La respuesta no se confirmó.');
      await widget.model.refreshOrder(widget.order);
      await refresh();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'No se registró la respuesta.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String amount(dynamic value) {
    final n = double.tryParse(value?.toString() ?? '');
    return n == null ? 'Pendiente' : money(n);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Cambios del pedido #' + widget.order.id.toString()),
      actions: <Widget>[IconButton(
        onPressed: busy ? null : refresh,
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Actualizar')]),
    body: RefreshIndicator(onRefresh: refresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: <Widget>[
          const Text('Decide sobre faltantes y consulta reembolsos registrados por el servidor.',
            style: TalaText.muted),
          const SizedBox(height: 16),
          if (error.isNotEmpty) AuthNotice(
            icon: Icons.error_outline_rounded, text: error, danger: true),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(24),
              child: CircularProgressIndicator()))
          else if (error.isEmpty) ...<Widget>[
            const Text('Sustituciones', style: TalaText.h2),
            const SizedBox(height: 10),
            if (changes.isEmpty) const Text('No hay cambios solicitados.', style: TalaText.muted),
            for (final row in changes) ...<Widget>[
              TalaCard(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text((row['message'] ?? 'Cambio solicitado').toString(),
                      style: const TextStyle(color: kInk, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text('Estado: ' + (row['status'] ?? '').toString(), style: TalaText.muted),
                    Text('Importe original ' + amount(row['original_amount']) +
                      ' · Sustituto ' + amount(row['replacement_amount']),
                      style: TalaText.caption),
                    if (row['status'] == 'pending') ...<Widget>[
                      const SizedBox(height: 12),
                      if (row['replacement_menu_item_id'] != null)
                        FilledButton(onPressed: busy ? null : () => respond(row, 'accept'),
                          child: const Text('Aceptar reemplazo')),
                      OutlinedButton(onPressed: busy ? null : () => respond(row, 'remove_item'),
                        child: const Text('Quitar producto')),
                      TextButton(onPressed: busy ? null : () => respond(row, 'cancel_order'),
                        child: const Text('Cancelar pedido completo')),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 22),
            const Text('Reembolsos', style: TalaText.h2),
            const SizedBox(height: 10),
            if (refunds.isEmpty) const Text('No hay reembolsos registrados.', style: TalaText.muted),
            for (final row in refunds) ...<Widget>[
              TalaCard(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(amount(row['amount']) + ' · ' + (row['status'] ?? '').toString(),
                      style: const TextStyle(color: kInk, fontWeight: FontWeight.w700)),
                    Text((row['reason'] ?? 'Ajuste').toString(), style: TalaText.muted),
                    Text('Proveedor: ' + (row['provider'] ?? 'Por confirmar').toString(),
                      style: TalaText.caption),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    ),
  );
}
