part of '../main.dart';

// ---------------------------------------------------------------------------
// Cuenta y sub-pantallas. Every action calls the same TalaModel / API method
// as v1.0.8. Removed: duplicated balance cards, technical copy, dark panels
// and buttons without a function.
// ---------------------------------------------------------------------------

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.model});

  final TalaModel model;

  Future<void> _confirmLogout(BuildContext context) async {
    final bool confirm = await showDialog<bool>(
          context: context,
          barrierColor: kScrim,
          builder: (BuildContext dialogContext) => AlertDialog(
            backgroundColor: kSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('¿Cerrar sesión?', style: TalaText.h2),
            content: const Text('Podrás volver a entrar con tu correo y contraseña.', style: TalaText.body),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
              FilledButton(style: kCompactFilled, onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Cerrar sesión')),
            ],
          ),
        ) ??
        false;
    if (confirm) model.logout();
  }

  @override
  Widget build(BuildContext context) {
    final String address = model.addresses.isEmpty ? 'Agrega una dirección' : model.addresses[model.selectedAddress.clamp(0, model.addresses.length - 1).toInt()].label;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
        children: <Widget>[
          const Text('Cuenta', style: TalaText.display),
          const SizedBox(height: 18),
          Reveal(
            child: TalaCard(
              shadow: true,
              padding: const EdgeInsets.all(16),
              onTap: () => Navigator.of(context).push(premiumRoute(EditProfileScreen(model: model))),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: <Color>[Color(0xFFFF8A54), kBrandDeep])),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: ProfileAvatar(model: model, radius: 28),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(model.userName.trim().isEmpty ? 'Tu perfil' : model.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.h2.copyWith(fontSize: 19)),
                        const SizedBox(height: 2),
                        Text(model.userEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TalaText.muted),
                        const SizedBox(height: 6),
                        const Text('Editar perfil', style: TextStyle(color: kBrandDeep, fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: kSubtle),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Reveal(index: 1, child: TalaClubAccountCard(model: model)),
          const SizedBox(height: 26),
          Reveal(
            index: 2,
            child: TalaGroup(
              title: 'Tu cuenta',
              children: <Widget>[
                AccountLink(
                  icon: Icons.favorite_border_rounded,
                  title: 'Favoritos',
                  subtitle: model.favorites.isEmpty ? null : '${model.favorites.length} guardados',
                  onTap: () => Navigator.of(context).push(premiumRoute(FavoritesScreen(model: model))),
                ),
                AccountLink(
                  icon: Icons.local_offer_outlined,
                  title: 'Promociones y cupones',
                  onTap: () => Navigator.of(context).push(premiumRoute(PromoCenterScreen(model: model))),
                ),
                AccountLink(
                  icon: Icons.location_on_outlined,
                  title: 'Direcciones',
                  subtitle: address,
                  onTap: () => Navigator.of(context).push(premiumRoute(AddressesScreen(model: model))),
                ),
                AccountLink(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notificaciones',
                  trailing: model.unreadNotifications > 0 ? TalaCountChip(label: '${model.unreadNotifications} nuevas') : null,
                  onTap: () => Navigator.of(context).push(premiumRoute(NotificationsScreen(model: model))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Reveal(
            index: 3,
            child: TalaGroup(
              title: 'Seguridad y privacidad',
              children: <Widget>[
                AccountLink(icon: Icons.shield_outlined, title: 'Seguridad', onTap: () => Navigator.of(context).push(premiumRoute(SecurityScreen(model: model)))),
                AccountLink(icon: Icons.privacy_tip_outlined, title: 'Privacidad', onTap: () => Navigator.of(context).push(premiumRoute(PrivacyScreen(model: model)))),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Reveal(
            index: 4,
            child: TalaGroup(
              title: 'Ayuda',
              children: <Widget>[
                AccountLink(icon: Icons.support_agent_rounded, title: 'Ayuda y soporte', onTap: () => Navigator.of(context).push(premiumRoute(SupportScreen(model: model)))),
                AccountLink(icon: Icons.description_outlined, title: 'Términos y condiciones', onTap: () => Navigator.of(context).push(premiumRoute(const TermsAndConditionsScreen()))),
                AccountLink(
                  icon: Icons.policy_outlined,
                  title: 'Aviso de privacidad',
                  onTap: () => Navigator.of(context).push(premiumRoute(PrivacyNoticeScreen(supportEmail: model.supportEmail))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: kDanger),
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 16),
          const Text('Tala Eats · v1.0.12', textAlign: TextAlign.center, style: TalaText.caption),
        ],
      ),
    );
  }
}

/// The single place where saldo, puntos and nivel are summarized.
class TalaClubAccountCard extends StatelessWidget {
  const TalaClubAccountCard({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tala Club. Saldo ${money(model.wallet)}, ${model.points} puntos, nivel ${model.loyaltyTier}',
      excludeSemantics: true,
      child: Pressable(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x33E9470F), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: Material(
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            color: kBrand,
            child: InkWell(
              onTap: () => Navigator.of(context).push(premiumRoute(WalletScreen(model: model))),
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFF7A3D), kBrand, kBrandDeep]),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(15)),
                        child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Text('Tala Club', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                                  child: Text(model.loyaltyTier.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.8)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${money(model.wallet)} de saldo · ${model.points} puntos', style: const TextStyle(color: Color(0xFFFFE6DA), fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.model});

  final TalaModel model;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController name = TextEditingController(text: widget.model.userName);
  late final TextEditingController phone = TextEditingController(text: widget.model.userPhone);
  bool saving = false;
  bool pickingPhoto = false;
  String error = '';

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> choosePhoto() async {
    setState(() {
      pickingPhoto = true;
      error = '';
    });
    final bool ok = await widget.model.pickProfilePhoto();
    if (!mounted) return;
    if (ok) HapticFeedback.lightImpact();
    setState(() {
      pickingPhoto = false;
      if (!ok && widget.model.lastError.isNotEmpty) error = widget.model.lastError;
    });
  }

  Future<void> removePhoto() async {
    await widget.model.removeLocalProfilePhoto();
    if (mounted) setState(() {});
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    if (name.text.trim().length < 2) {
      setState(() => error = 'Escribe un nombre válido.');
      return;
    }
    setState(() {
      saving = true;
      error = '';
    });
    final bool ok = await widget.model.updateProfile(name.text, phone.text);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        saving = false;
        error = widget.model.lastError;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    showMessage(context, 'Perfil actualizado.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: kShadowSoft),
                  child: AnimatedSwitcher(
                    duration: TalaMotion.of(context, TalaMotion.reveal),
                    child: KeyedSubtree(
                      key: ValueKey<String>(widget.model.userLocalAvatarPath),
                      child: ProfileAvatar(model: widget.model, radius: 54),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Tooltip(
                    message: 'Cambiar foto',
                    child: Material(
                      color: kBrand,
                      shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: pickingPhoto ? null : choosePhoto,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: pickingPhoto
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 21),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: <Widget>[
              TextButton.icon(
                onPressed: pickingPhoto ? null : choosePhoto,
                icon: const Icon(Icons.photo_library_outlined, size: 19),
                label: const Text('Elegir foto de perfil'),
              ),
              if (widget.model.userLocalAvatarPath.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: kMuted),
                  onPressed: removePhoto,
                  child: const Text('Quitar foto'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.telephoneNumber],
            onSubmitted: (_) {
              if (!saving) save();
            },
            decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          if (error.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            AuthNotice(icon: Icons.error_outline_rounded, text: error, danger: true),
          ],
          const SizedBox(height: 22),
          FilledButton(onPressed: saving ? null : save, child: BusyLabel(busy: saving, label: 'Guardar cambios')),
        ],
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        final List<Restaurant> restaurants = model.restaurants.where((Restaurant restaurant) => model.favorites.contains(restaurant.id)).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Favoritos')),
          body: restaurants.isEmpty
              ? StatusView(
                  icon: Icons.favorite_border_rounded,
                  title: 'Aún no tienes favoritos',
                  body: 'Toca el corazón de un comercio para guardarlo aquí.',
                  actionLabel: 'Explorar restaurantes',
                  onAction: () {
                    model.setTab(0);
                    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  itemCount: restaurants.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Restaurant restaurant = restaurants[index];
                    final String tag = 'favorite-restaurant-${restaurant.id}';
                    return Reveal(
                      index: index,
                      child: RestaurantCard(
                        model: model,
                        restaurant: restaurant,
                        heroTag: tag,
                        onTap: () => Navigator.of(context).push(premiumRoute(RestaurantScreen(model: model, restaurant: restaurant, heroTag: tag))),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key, required this.model});

  final TalaModel model;

  Future<void> _confirmDelete(BuildContext context, int index) async {
    final AddressEntry entry = model.addresses[index];
    final bool confirm = await showDialog<bool>(
          context: context,
          barrierColor: kScrim,
          builder: (BuildContext dialogContext) => AlertDialog(
            backgroundColor: kSurface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('¿Eliminar dirección?', style: TalaText.h2),
            content: Text('“${entry.label}” dejará de aparecer en tus direcciones.', style: TalaText.body),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
              FilledButton(
                style: kCompactFilled.copyWith(backgroundColor: const WidgetStatePropertyAll<Color>(kDanger)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    final bool ok = await model.removeAddressRemote(index);
    if (!ok && context.mounted) showMessage(context, model.lastError);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Direcciones'),
            actions: <Widget>[
              IconButton(tooltip: 'Agregar dirección', onPressed: () => showAddAddressSheet(context, model), icon: const Icon(Icons.add_location_alt_outlined)),
              const SizedBox(width: 4),
            ],
          ),
          body: model.addresses.isEmpty
              ? StatusView(
                  icon: Icons.location_off_outlined,
                  title: 'Aún no tienes direcciones',
                  body: 'Agrega dónde quieres recibir tus pedidos.',
                  actionLabel: 'Agregar dirección',
                  onAction: () => showAddAddressSheet(context, model),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: <Widget>[
                    const Text('Elige dónde quieres recibir tus pedidos.', style: TalaText.muted),
                    const SizedBox(height: 14),
                    for (int index = 0; index < model.addresses.length; index++)
                      Reveal(
                        index: index,
                        child: AddressPremiumCard(
                          address: model.addresses[index],
                          selected: model.selectedAddress == index,
                          canDelete: model.addresses.length > 1,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            model.setAddress(index);
                          },
                          onDelete: () => _confirmDelete(context, index),
                        ),
                      ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => showAddAddressSheet(context, model),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Agregar otra dirección'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class AddressPremiumCard extends StatelessWidget {
  const AddressPremiumCard({super.key, required this.address, required this.selected, required this.canDelete, required this.onTap, required this.onDelete});

  final AddressEntry address;
  final bool selected;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Duration d = TalaMotion.of(context, TalaMotion.select);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        child: Pressable(
          child: AnimatedContainer(
            duration: d,
            curve: TalaMotion.ease,
            decoration: BoxDecoration(
              color: selected ? kSoftPeach : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? kBrand : kLine, width: selected ? 1.6 : 1),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                  child: Row(
                    children: <Widget>[
                      AnimatedSwitcher(
                        duration: d,
                        child: Icon(
                          selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                          key: ValueKey<bool>(selected),
                          color: selected ? kBrand : kSubtle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(address.label, style: TalaText.title.copyWith(fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(address.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: TalaText.muted),
                          ],
                        ),
                      ),
                      if (canDelete)
                        IconButton(tooltip: 'Eliminar dirección', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, color: kMuted))
                      else
                        const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showAddAddressSheet(BuildContext context, TalaModel model) {
  final TextEditingController label = TextEditingController();
  final TextEditingController address = TextEditingController();
  bool saving = false;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: kScrim,
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheet) {
          Future<void> submit() async {
            if (label.text.trim().isEmpty || address.text.trim().isEmpty) {
              showMessage(sheetContext, 'Completa nombre y dirección.');
              return;
            }
            setSheet(() => saving = true);
            bool ok = await model.addAddressRemote(label.text, address.text);
            if (!ok && model.lastError.contains('coordenadas')) {
              if (!sheetContext.mounted) return;
              final bool useCurrent = await showDialog<bool>(
                    context: sheetContext,
                    barrierColor: kScrim,
                    builder: (BuildContext dialogContext) => AlertDialog(
                      backgroundColor: kSurface,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: const Text('Usar tu ubicación actual', style: TalaText.h2),
                      content: const Text(
                        'No encontramos esa dirección en el mapa. Si estás en ella ahora mismo, podemos usar la ubicación de tu teléfono.',
                        style: TalaText.body,
                      ),
                      actions: <Widget>[
                        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
                        FilledButton(style: kCompactFilled, onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Usar ubicación')),
                      ],
                    ),
                  ) ??
                  false;
              if (useCurrent) {
                final Map<String, double>? coords = await NativeBridge.currentLocation();
                if (coords != null) ok = await model.addAddressRemote(label.text, address.text, deviceLat: coords['lat'], deviceLng: coords['lng']);
              }
            }
            if (!sheetContext.mounted) return;
            setSheet(() => saving = false);
            if (!ok) {
              showMessage(sheetContext, model.lastError.isEmpty ? 'No pudimos guardar la dirección.' : model.lastError);
              return;
            }
            HapticFeedback.mediumImpact();
            Navigator.of(sheetContext).pop();
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: const BoxDecoration(color: kSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: kLineStrong, borderRadius: BorderRadius.circular(99)))),
                    const SizedBox(height: 18),
                    const Text('Nueva dirección', style: TalaText.h1),
                    const SizedBox(height: 4),
                    const Text('Ponle un nombre fácil de reconocer.', style: TalaText.muted),
                    const SizedBox(height: 18),
                    TextField(
                      controller: label,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Casa, Trabajo…', prefixIcon: Icon(Icons.label_outline_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: address,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!saving) submit();
                      },
                      decoration: const InputDecoration(labelText: 'Dirección', hintText: 'Calle, número, colonia…', prefixIcon: Icon(Icons.location_on_outlined)),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: saving ? null : submit, child: BusyLabel(busy: saving, label: 'Guardar dirección')),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        final double progress = (model.points / 500).clamp(0.0, 1.0).toDouble();
        return Scaffold(
          appBar: AppBar(title: const Text('Tala Club')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: <Widget>[
              Reveal(child: PremiumWalletHero(model: model)),
              const SizedBox(height: 14),
              Reveal(
                index: 1,
                child: RewardProgressCard(
                  points: model.points,
                  progress: progress,
                  onRedeem: () async {
                    final bool ok = await model.redeemReward();
                    if (!context.mounted) return;
                    HapticFeedback.mediumImpact();
                    showMessage(context, ok ? 'Recompensa canjeada. Tu saldo ya se actualizó.' : (model.lastError.isEmpty ? 'Esta recompensa no está disponible.' : model.lastError));
                  },
                ),
              ),
              const SizedBox(height: 26),
              const TalaSectionHeader(title: 'Movimientos'),
              const SizedBox(height: 10),
              if (model.walletTransactions.isEmpty)
                const StatusView(icon: Icons.receipt_long_outlined, title: 'Sin movimientos', body: 'Tus movimientos de saldo y puntos aparecerán aquí.', compact: true)
              else
                TalaGroup(
                  children: <Widget>[
                    for (final Map<String, dynamic> txn in model.walletTransactions)
                      PremiumMovementTile(
                        icon: _walletIcon((txn['kind'] ?? '').toString()),
                        title: (txn['description'] ?? 'Movimiento').toString(),
                        subtitle: _shortDate((txn['created_at'] ?? '').toString()),
                        amount: _signedMoney(txn['amount']),
                        positive: (double.tryParse(txn['amount']?.toString() ?? '0') ?? 0) >= 0,
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class PremiumWalletHero extends StatelessWidget {
  const PremiumWalletHero({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFF7A3D), kBrand, Color(0xFFD43D0B)]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x33E9470F), blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(right: -30, top: -40, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  const Text('TALA CLUB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 11)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99)),
                    child: Text('Nivel ${model.loyaltyTier}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text('Saldo disponible', style: TextStyle(color: Color(0xFFFFE6DA), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(money(model.wallet), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.2, height: 1.05)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _HeroChip(icon: Icons.stars_rounded, label: '${model.points} puntos'),
                  if (model.plusMember) const _HeroChip(icon: Icons.verified_rounded, label: 'Membresía activa'),
                  if (model.referralCode.isNotEmpty)
                    _HeroChip(
                      icon: Icons.content_copy_rounded,
                      label: 'Código ${model.referralCode}',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: model.referralCode));
                        HapticFeedback.selectionClick();
                        showMessage(context, 'Código copiado.');
                      },
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class RewardProgressCard extends StatefulWidget {
  const RewardProgressCard({super.key, required this.points, required this.progress, required this.onRedeem});

  final int points;
  final double progress;
  final Future<void> Function() onRedeem;

  @override
  State<RewardProgressCard> createState() => _RewardProgressCardState();
}

class _RewardProgressCardState extends State<RewardProgressCard> {
  bool busy = false;

  Future<void> _redeem() async {
    setState(() => busy = true);
    await widget.onRedeem();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final int points = widget.points;
    final bool ready = points >= 500;
    return TalaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: kSoftOrange, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.card_giftcard_rounded, color: kBrand),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('\$50 MXN de saldo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kInk)),
                    SizedBox(height: 2),
                    Text('Canjeable por 500 puntos', style: TalaText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: widget.progress),
            duration: TalaMotion.of(context, const Duration(milliseconds: 700)),
            curve: TalaMotion.ease,
            builder: (BuildContext context, double value, Widget? child) => ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: kSunken, color: ready ? kGreen : kBrand),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Text('$points / 500 pts', style: TalaText.caption),
              const Spacer(),
              Text(
                ready ? 'Premio disponible' : 'Te faltan ${500 - points} pts',
                style: TextStyle(color: ready ? kGreen : kBrandDeep, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : _redeem,
            icon: const Icon(Icons.redeem_rounded),
            label: BusyLabel(busy: busy, label: 'Canjear recompensa'),
          ),
        ],
      ),
    );
  }
}

class PremiumMovementTile extends StatelessWidget {
  const PremiumMovementTile({super.key, required this.icon, required this.title, required this.subtitle, required this.amount, required this.positive});

  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: (positive ? kGreen : kBrand).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 18, color: positive ? kGreen : kBrandDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kInk, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) Text(subtitle, style: TalaText.caption),
              ],
            ),
          ),
          Text(amount, style: TextStyle(color: positive ? kGreen : kInk, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

IconData _walletIcon(String kind) {
  if (kind.contains('refund')) return Icons.undo_rounded;
  if (kind.contains('reward') || kind.contains('points')) return Icons.stars_rounded;
  if (kind.contains('payment')) return Icons.shopping_bag_outlined;
  if (kind.contains('gift')) return Icons.card_giftcard_rounded;
  return Icons.account_balance_wallet_outlined;
}

String _shortDate(String raw) {
  final DateTime? dt = DateTime.tryParse(raw)?.toLocal();
  if (dt == null) return '';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

String _signedMoney(dynamic value) {
  final double amount = double.tryParse(value?.toString() ?? '0') ?? 0;
  return '${amount >= 0 ? '+' : ''}${money(amount)}';
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.model});

  final TalaModel model;

  IconData _icon(String kind) {
    if (kind.contains('payment')) return Icons.payments_outlined;
    if (kind.contains('delivery')) return Icons.two_wheeler_rounded;
    if (kind.contains('security')) return Icons.shield_outlined;
    if (kind.contains('wallet')) return Icons.account_balance_wallet_outlined;
    return Icons.notifications_active_outlined;
  }

  String _relativeTime(String raw) {
    final DateTime? dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final Duration d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Ahora';
    if (d.inMinutes < 60) return 'Hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'Hace ${d.inHours} h';
    return 'Hace ${d.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notificaciones'),
            actions: <Widget>[
              if (model.unreadNotifications > 0) TextButton(onPressed: model.markAllNotificationsRead, child: const Text('Marcar todo leído')),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            color: kBrand,
            backgroundColor: Colors.white,
            onRefresh: model.refreshAll,
            child: model.notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const <Widget>[
                      SizedBox(height: 80),
                      StatusView(icon: Icons.notifications_none_rounded, title: 'Sin notificaciones', body: 'Aquí verás avisos de tus pedidos, pagos y cuenta.'),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    itemCount: model.notifications.length,
                    itemBuilder: (BuildContext context, int index) {
                      final NotificationEntry n = model.notifications[index];
                      return Reveal(
                        index: index,
                        child: PremiumNotificationCard(
                          icon: _icon(n.kind),
                          accent: n.isRead ? kMuted : kBrand,
                          title: n.title,
                          body: n.message,
                          time: _relativeTime(n.createdAt),
                          unread: !n.isRead,
                          onTap: () => model.markNotificationRead(n),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class PremiumNotificationCard extends StatelessWidget {
  const PremiumNotificationCard({super.key, required this.icon, required this.accent, required this.title, required this.body, required this.time, required this.unread, required this.onTap});

  final IconData icon;
  final Color accent;
  final String title;
  final String body;
  final String time;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      color: unread ? kSoftPeach : Colors.white,
      borderColor: unread ? const Color(0xFFFFDCCB) : kLine,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: unread ? Colors.white : accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text(title, style: TextStyle(color: kInk, fontWeight: unread ? FontWeight.w800 : FontWeight.w600, fontSize: 15))),
                    if (time.isNotEmpty) Text(time, style: TalaText.caption.copyWith(fontSize: 11)),
                    if (unread) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle)),
                    ],
                  ],
                ),
                if (body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(body, style: TalaText.muted),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: <Widget>[
          const TalaCard(
            padding: EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                CircleAvatar(backgroundColor: kSoftGreen, child: Icon(Icons.verified_user_rounded, color: kGreen)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Tu sesión está protegida', style: TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Se guarda cifrada en este teléfono. Cierra sesión si vas a prestarlo.', style: TalaText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TalaGroup(
            children: <Widget>[
              AccountLink(
                icon: Icons.lock_reset_rounded,
                title: 'Cambiar contraseña',
                subtitle: 'Te enviaremos un enlace a tu correo',
                onTap: () => Navigator.of(context).push(premiumRoute(ChangePasswordScreen(model: model))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, required this.model});

  final TalaModel model;

  Future<void> _export(BuildContext context) async {
    try {
      await model.api.post('/v9/privacy', <String, dynamic>{'request_type': 'export'});
      if (context.mounted) showMessage(context, 'Solicitud de exportación registrada.');
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Privacidad')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: <Widget>[
              const Text('Decide cómo se usan tus preferencias en Tala Eats.', style: TalaText.muted),
              const SizedBox(height: 16),
              TalaGroup(
                title: 'Preferencias',
                children: <Widget>[
                  PrivacyToggleTile(icon: Icons.auto_awesome_outlined, title: 'Experiencia personalizada', subtitle: 'Usar tus favoritos y pedidos para recomendarte mejor.', value: model.personalizedExperience, onChanged: model.setPersonalizedExperience),
                  PrivacyToggleTile(icon: Icons.analytics_outlined, title: 'Analítica de producto', subtitle: 'Ayudar a mejorar el rendimiento de la app.', value: model.analytics, onChanged: model.setAnalytics),
                  PrivacyToggleTile(icon: Icons.campaign_outlined, title: 'Comunicaciones', subtitle: 'Promociones y novedades de Tala Eats.', value: model.marketing, onChanged: model.setMarketing),
                ],
              ),
              const SizedBox(height: 22),
              TalaGroup(
                title: 'Tus datos',
                children: <Widget>[
                  PrivacyActionCard(icon: Icons.download_outlined, title: 'Descargar mis datos', subtitle: 'Solicita una copia de tu información.', onTap: () => _export(context)),
                  PrivacyActionCard(icon: Icons.delete_outline_rounded, title: 'Eliminar mi cuenta', subtitle: 'Te pediremos confirmación.', danger: true, onTap: () => showDeleteAccountDialog(context, model)),
                ],
              ),
              const SizedBox(height: 16),
              const QuietNote(icon: Icons.lock_outline_rounded, text: 'Tus preferencias se guardan en tu cuenta de Tala Eats.'),
            ],
          ),
        );
      },
    );
  }
}

/// Switch row for grouped settings.
class NotificationPreferenceTile extends StatelessWidget {
  const NotificationPreferenceTile({super.key, required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    void toggle(bool next) {
      HapticFeedback.selectionClick();
      onChanged(next);
    }

    return Semantics(
      toggled: value,
      child: InkWell(
        onTap: () => toggle(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: kSoftPeach, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: kBrandDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: const TextStyle(color: kInk, fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TalaText.caption.copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: toggle),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyToggleTile extends StatelessWidget {
  const PrivacyToggleTile({super.key, required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => NotificationPreferenceTile(icon: icon, title: title, subtitle: subtitle, value: value, onChanged: onChanged);
}

class PrivacyActionCard extends StatelessWidget {
  const PrivacyActionCard({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap, this.danger = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => AccountLink(icon: icon, title: title, subtitle: subtitle, onTap: onTap, danger: danger);
}

void showDeleteAccountDialog(BuildContext context, TalaModel model) {
  bool sending = false;
  showDialog<void>(
    context: context,
    barrierColor: kScrim,
    builder: (BuildContext dialogContext) => StatefulBuilder(
      builder: (BuildContext innerContext, StateSetter setState) => AlertDialog(
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.warning_amber_rounded, color: kDanger, size: 34),
        title: const Text('Solicitar eliminación', style: TalaText.h2),
        content: const Text(
          'Registraremos tu solicitud para eliminar tu cuenta. Algunas obligaciones legales o de seguridad pueden requerir conservar cierta información por un tiempo.',
          style: TalaText.body,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
          FilledButton(
            style: kCompactFilled.copyWith(backgroundColor: const WidgetStatePropertyAll<Color>(kDanger)),
            onPressed: sending
                ? null
                : () async {
                    setState(() => sending = true);
                    try {
                      await model.api.post('/v9/privacy', <String, dynamic>{'request_type': 'delete'});
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        if (context.mounted) showMessage(context, 'Solicitud de eliminación registrada.');
                      }
                    } on ApiException catch (e) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        if (context.mounted) showMessage(context, e.message);
                      }
                    }
                  },
            child: BusyLabel(busy: sending, label: 'Enviar solicitud'),
          ),
        ],
      ),
    ),
  );
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.model, this.orderId});

  final TalaModel model;
  final int? orderId;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController message = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> send() async {
    FocusScope.of(context).unfocus();
    if (message.text.trim().isEmpty) {
      showMessage(context, 'Escribe un mensaje para soporte.');
      return;
    }
    setState(() => sending = true);
    final bool ok = await widget.model.createSupportTicket(message.text, orderId: widget.orderId, category: 'customer_app');
    if (!mounted) return;
    setState(() => sending = false);
    if (!ok) {
      showMessage(context, widget.model.lastError.isEmpty ? 'Escribe al menos unas palabras para poder ayudarte.' : widget.model.lastError);
      return;
    }
    HapticFeedback.mediumImpact();
    showMessage(context, 'Mensaje enviado. Soporte te responderá pronto.');
    message.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y soporte')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: <Widget>[
          if (widget.orderId != null) ...<Widget>[
            Align(alignment: Alignment.centerLeft, child: StatusPill(label: 'Sobre el pedido #${widget.orderId}', color: kBrandDeep, background: kSoftOrange, dot: false)),
            const SizedBox(height: 14),
          ],
          const Text('Preguntas frecuentes', style: TalaText.h2),
          const SizedBox(height: 10),
          const TalaGroup(
            children: <Widget>[
              SupportFaq(title: '¿Cómo sigo mi pedido?', body: 'En Pedidos abre tu pedido en curso y toca “Seguir pedido” para ver su avance y al repartidor asignado.'),
              SupportFaq(title: '¿Cómo cancelo un pedido?', body: 'Puedes cancelarlo desde el detalle del pedido mientras está recibido, confirmado o en preparación. Después, escríbenos y te ayudamos.'),
              SupportFaq(title: '¿Qué pasa si hubo un problema con el pago?', body: 'Si elegiste efectivo, el cobro ocurre al entregar o recoger. Si elegiste un pago en línea, Tala Eats solo lo marca como pagado cuando el proveedor lo confirma desde el servidor. Si ves algo raro, cuéntanos aquí abajo.'),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Escríbenos', style: TalaText.h2),
          const SizedBox(height: 4),
          const Text('Cuéntanos qué pasó y te responderemos lo antes posible.', style: TalaText.muted),
          const SizedBox(height: 12),
          TextField(
            controller: message,
            minLines: 4,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Escribe tu mensaje…', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: sending ? null : send,
            icon: const Icon(Icons.send_rounded, size: 18),
            label: BusyLabel(busy: sending, label: 'Enviar mensaje'),
          ),
          if (widget.model.supportEmail.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            QuietNote(icon: Icons.mail_outline_rounded, text: 'También puedes escribirnos a ${widget.model.supportEmail}'),
          ],
        ],
      ),
    );
  }
}

class SupportFaq extends StatelessWidget {
  const SupportFaq({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: kBrand,
        collapsedIconColor: kMuted,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(title, style: const TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 15)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[Text(body, style: TalaText.body)],
      ),
    );
  }
}

class PromoCenterScreen extends StatelessWidget {
  const PromoCenterScreen({super.key, required this.model});

  final TalaModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (BuildContext context, Widget? child) {
        final List<Map<String, dynamic>> activeCoupons = model.coupons.where((Map<String, dynamic> c) => c['active'] == true).toList();
        final List<Map<String, dynamic>> activePromos = model.promotions.where((Map<String, dynamic> p) => p['active'] == true).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Promociones')),
          body: RefreshIndicator(
            color: kBrand,
            backgroundColor: Colors.white,
            onRefresh: model.refreshAll,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: <Widget>[
                if (activeCoupons.isEmpty && activePromos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: StatusView(icon: Icons.local_offer_outlined, title: 'Sin promociones activas', body: 'Cuando haya una promoción vigente la verás aquí.'),
                  ),
                if (activeCoupons.isNotEmpty) ...<Widget>[
                  TalaSectionHeader(title: 'Cupones', trailing: TalaCountChip(label: '${activeCoupons.length}')),
                  const SizedBox(height: 12),
                  for (int i = 0; i < activeCoupons.length; i++)
                    Reveal(
                      index: i,
                      child: _CouponCard(
                        code: (activeCoupons[i]['code'] ?? '').toString(),
                        title: (activeCoupons[i]['description'] ?? 'Cupón Tala Eats').toString(),
                        minOrder: double.tryParse(activeCoupons[i]['min_order']?.toString() ?? '0') ?? 0,
                        applied: model.coupon.isNotEmpty && model.coupon == (activeCoupons[i]['code'] ?? '').toString(),
                        onUse: () {
                          final String code = (activeCoupons[i]['code'] ?? '').toString();
                          HapticFeedback.selectionClick();
                          model.setCoupon(code);
                          showMessage(context, 'Cupón $code listo para tu próximo pago.');
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                if (activePromos.isNotEmpty) ...<Widget>[
                  TalaSectionHeader(title: 'Promociones', trailing: TalaCountChip(label: '${activePromos.length}')),
                  const SizedBox(height: 12),
                  for (int i = 0; i < activePromos.length; i++)
                    Reveal(
                      index: activeCoupons.length + i,
                      child: PromoOfferCard(
                        icon: Icons.local_offer_outlined,
                        title: (activePromos[i]['title'] ?? 'Promoción').toString(),
                        subtitle: (activePromos[i]['description'] ?? '').toString(),
                        code: _percentLabel(activePromos[i]['discount_percent']),
                        accent: kGreen,
                        onTap: () => showMessage(context, 'Se aplica automáticamente si tu pedido cumple las condiciones.'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

String _percentLabel(dynamic raw) {
  final double value = double.tryParse(raw?.toString() ?? '') ?? 0;
  if (value <= 0) return '';
  return value == value.roundToDouble() ? '${value.toInt()}%' : '${value.toStringAsFixed(1)}%';
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.code, required this.title, required this.minOrder, required this.applied, required this.onUse});

  final String code;
  final String title;
  final double minOrder;
  final bool applied;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      borderColor: applied ? kGreen : kLine,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: kSoftOrange, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.confirmation_number_outlined, color: kBrandDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: kSunken, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLineStrong)),
                      child: Text(code, style: const TextStyle(color: kInk, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.2)),
                    ),
                    if (minOrder > 0) ...<Widget>[
                      const SizedBox(width: 8),
                      Flexible(child: Text('Mínimo ${money(minOrder)}', style: TalaText.caption)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          applied
              ? const StatusPill(label: 'Listo', color: kGreen, background: kSoftGreen)
              : TextButton(onPressed: onUse, child: const Text('Usar')),
        ],
      ),
    );
  }
}

class PromoOfferCard extends StatelessWidget {
  const PromoOfferCard({super.key, required this.icon, required this.title, required this.subtitle, required this.code, required this.accent, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final String code;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TalaCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(color: kInk, fontWeight: FontWeight.w700, fontSize: 15)),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TalaText.caption.copyWith(fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
          if (code.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            StatusPill(label: code, color: accent, background: accent.withValues(alpha: 0.12), dot: false),
          ],
        ],
      ),
    );
  }
}
