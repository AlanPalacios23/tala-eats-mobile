part of '../main.dart';

/// Explicit market selection. No GPS guess or silent switch while an active
/// basket belongs to a different zone. Empty markets remain genuinely empty.
class CustomerMarketSelector extends StatelessWidget {
  const CustomerMarketSelector({super.key, required this.model});
  final TalaModel model;

  Future<void> _choose(BuildContext context) async {
    if (model.marketChanging) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('¿Dónde quieres comprar?', style: TalaText.h2),
              const SizedBox(height: 4),
              const Text('Selecciona tu localidad. Tala es el mercado piloto; '
                  'las demás zonas mostrarán negocios solo cuando estén disponibles.',
                  style: TalaText.muted),
              const SizedBox(height: 14),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final zone in TalaMarket.supported)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.location_on_outlined,
                            color: zone.code == model.marketCode ? kBrand : kMuted),
                        title: Text(zone.label,
                            style: TextStyle(color: kInk,
                                fontWeight: zone.code == model.marketCode
                                    ? FontWeight.w800 : FontWeight.w600)),
                        subtitle: Text(zone.code == TalaMarket.pilot
                            ? 'Mercado piloto'
                            : 'Sujeto a disponibilidad de comercios',
                            style: TalaText.caption),
                        trailing: zone.code == model.marketCode
                            ? const Icon(Icons.check_circle_rounded, color: kBrand)
                            : const Icon(Icons.chevron_right_rounded, color: kMuted),
                        onTap: model.marketChanging ? null : () async {
                          if (zone.code == model.marketCode) {
                            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                            return;
                          }
                          bool discard = false;
                          if (model.cart.isNotEmpty) {
                            discard = await showDialog<bool>(
                              context: sheetContext,
                              builder: (BuildContext dialog) => AlertDialog(
                                title: const Text('¿Cambiar de localidad?'),
                                content: const Text('Tienes un carrito activo. '
                                    'Para cambiar de localidad será necesario vaciarlo. '
                                    'Tus pedidos existentes no se modifican.'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.of(dialog).pop(false),
                                    child: const Text('Conservar carrito')),
                                  FilledButton(
                                    onPressed: () => Navigator.of(dialog).pop(true),
                                    child: const Text('Cambiar de zona')),
                                ],
                              ),
                            ) ?? false;
                            if (!discard) return;
                          }
                          final changed = await model.chooseMarket(
                            zone.code, discardCart: discard);
                          if (!sheetContext.mounted) return;
                          if (changed) {
                            Navigator.of(sheetContext).pop();
                          } else {
                            showMessage(sheetContext,
                              model.lastError.isNotEmpty
                                  ? model.lastError
                                  : 'La localidad no está disponible todavía.');
                          }
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: kSoftPeach,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: model.marketChanging ? null : () => _choose(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.storefront_outlined, size: 17, color: kBrandDeep),
            const SizedBox(width: 8),
            Flexible(
              child: Text('Comprar en ${TalaMarket.labelFor(model.marketCode)}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kBrandDeep, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 4),
            model.marketChanging
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.keyboard_arrow_down_rounded,
                    color: kBrandDeep, size: 18),
          ],
        ),
      ),
    ),
  );
}
