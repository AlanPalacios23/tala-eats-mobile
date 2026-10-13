import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/entities.dart';
import '../../data/withdrawal_gateway.dart';
import '../../state/operations_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/feedback.dart';
import '../../widgets/images.dart';
import '../../widgets/motion.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/states.dart';
import '../../widgets/surfaces.dart';
import '../withdrawals/withdrawals_screen.dart';
import 'location_screen.dart';
import 'restaurant_editor_screen.dart';
import 'team_sheet.dart';

const String kAppVersion = '0.7.5';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.ops,
    required this.session,
    required this.onOpenKds,
  });

  final OperationsController ops;
  final SessionController session;
  final VoidCallback onOpenKds;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: ops,
        builder: (context, _) {
          final Widget content;
          if (!ops.hasData && ops.status == LoadStatus.failure) {
            content = Center(
              key: const ValueKey<String>('more-failure'),
              child: SingleChildScrollView(
                child: StateView.failure(ops.loadFailure!, onRetry: ops.retry),
              ),
            );
          } else if (!ops.hasData) {
            content = const _MoreSkeleton(key: ValueKey<String>('more-loading'));
          } else {
            content = _MoreContent(
              key: const ValueKey<String>('more-ready'),
              ops: ops,
              session: session,
              onOpenKds: onOpenKds,
            );
          }
          return StateSwitcher(expand: true, child: content);
        },
      ),
    );
  }
}

class _MoreContent extends StatelessWidget {
  const _MoreContent({
    super.key,
    required this.ops,
    required this.session,
    required this.onOpenKds,
  });

  final OperationsController ops;
  final SessionController session;
  final VoidCallback onOpenKds;

  Future<void> _openEditor(BuildContext context) async {
    final message = await Navigator.of(context).push<String>(
      appRoute<String>(RestaurantEditorScreen(ops: ops)),
    );
    if (message != null && context.mounted) {
      showAppSnack(context, message, tone: AlertTone.success);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: '¿Cerrar sesión?',
      message: 'Tu restaurante seguirá configurado. Para volver a entrar '
          'necesitarás tu correo y contraseña.',
      confirmLabel: 'Cerrar sesión',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (ok) await session.signOut();
  }

  Future<void> _openLocation(BuildContext context) async {
    final message = await openRestaurantLocation(context, ops);
    if (message != null && context.mounted) {
      showAppSnack(context, message, tone: AlertTone.success);
    }
  }

  void _openWithdrawals(BuildContext context) {
    Navigator.of(context).push<void>(
      appRoute<void>(WithdrawalsScreen(
        gateway: ops.restaurant != null
            ? ops.services.withdrawals.forRecipient(ops.restaurant!.id)
            : const DisconnectedWithdrawalGateway(),
      )),
    );
  }

  void _licenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Tala Eats Restaurante',
      applicationVersion: 'Versión $kAppVersion',
      applicationIcon: const Padding(
        padding: EdgeInsets.all(12),
        child: BrandMark(size: 48),
      ),
    );
  }

  /// Hoja «Acerca de»: marca, versión y acceso a licencias.
  void _about(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          key: const ValueKey<String>('aboutSheet'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const BrandMark(size: 64),
            const SizedBox(height: 14),
            Text(
              'Tala Eats Restaurante',
              textAlign: TextAlign.center,
              style: AppText.headline.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              'Panel para restaurantes · Versión $kAppVersion',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Licencias de código abierto',
              icon: Icons.description_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _licenses(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = ops.restaurant!;
    final user = session.user;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        AppSpace.xxxl,
      ),
      children: <Widget>[
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const ScreenHeader(title: 'Más'),
                const SizedBox(height: AppSpace.lg),
                _IdentityCard(
                  restaurant: restaurant,
                  onEdit: () => _openEditor(context),
                ),
                const SectionHeader('Operación'),
                _Group(
                  children: <Widget>[
                    _NavRow(
                      icon: Icons.soup_kitchen_outlined,
                      title: 'Modo cocina',
                      subtitle: 'Comandas en pantalla completa',
                      onTap: onOpenKds,
                    ),
                    _NavRow(
                      key: const ValueKey<String>('moreLocationRow'),
                      icon: Icons.location_on_outlined,
                      title: 'Ubicación del establecimiento',
                      subtitle: 'Dirección y punto GPS para calcular envíos',
                      onTap: () => _openLocation(context),
                    ),
                    _PickupRow(ops: ops, restaurant: restaurant),
                    _NavRow(
                      icon: Icons.delivery_dining_outlined,
                      title: 'Preparación y entrega',
                      subtitle: '${restaurant.etaMin} min de preparación · '
                          'envío calculado por Tala Eats',
                      onTap: () => _openEditor(context),
                    ),
                  ],
                ),
                const SectionHeader('Pagos'),
                _Group(
                  children: <Widget>[
                    _NavRow(
                      key: const ValueKey<String>('moreWithdrawalsRow'),
                      icon: Icons.account_balance_outlined,
                      title: 'Retiros y cuenta bancaria',
                      subtitle: 'Saldo, cuenta de cobro e historial',
                      onTap: () => _openWithdrawals(context),
                    ),
                  ],
                ),
                const SectionHeader('Equipo'),
                _Group(
                  children: <Widget>[
                    _NavRow(
                      icon: Icons.groups_outlined,
                      title: 'Equipo y permisos',
                      subtitle: 'Gerentes, caja y cocina',
                      onTap: () => showTeamSheet(context, ops),
                    ),
                  ],
                ),
                const SectionHeader('Cuenta'),
                _Group(
                  children: <Widget>[
                    _InfoRowTile(
                      icon: Icons.person_outline_rounded,
                      title: user?.name ?? 'Propietario',
                      subtitle: user?.email ?? '',
                    ),
                    if (user?.twoFactorEnabled ?? false)
                      const _InfoRowTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Verificación en dos pasos',
                        subtitle: 'Activa en tu cuenta',
                      ),
                    _NavRow(
                      icon: Icons.info_outline_rounded,
                      title: 'Acerca de la app',
                      subtitle: 'Versión $kAppVersion y licencias',
                      onTap: () => _about(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xxl),
                AppButton(
                  key: const ValueKey<String>('signOutButton'),
                  label: 'Cerrar sesión',
                  icon: Icons.logout_rounded,
                  variant: AppButtonVariant.dangerQuiet,
                  onPressed: () => _signOut(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.restaurant, required this.onEdit});

  final RestaurantInfo restaurant;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg - 1),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: AppImage(
                source: restaurant.imagePath,
                placeholderIcon: Icons.storefront_outlined,
                iconSize: 34,
                semanticLabel: 'Foto de ${restaurant.name}',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        restaurant.name,
                        style: AppText.title.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(restaurant.cuisine, style: AppText.caption),
                      if (restaurant.description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          restaurant.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySoft.copyWith(fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Tag(
                        label: restaurant.isOpen ? 'Abierto' : 'Cerrado',
                        icon: restaurant.isOpen
                            ? Icons.circle
                            : Icons.circle_outlined,
                        foreground: restaurant.isOpen
                            ? AppColors.green
                            : AppColors.inkSoft,
                        background: restaurant.isOpen
                            ? AppColors.greenTint
                            : AppColors.sunken,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  key: const ValueKey<String>('editRestaurantButton'),
                  label: 'Editar',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.compact,
                  expand: false,
                  onPressed: onEdit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grupo de filas en una sola superficie (sin tarjetas anidadas).
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const Divider(indent: 64),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.sunken,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: AppColors.ink),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: <Widget>[
              _RowIcon(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppText.subtitle.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRowTile extends StatelessWidget {
  const _InfoRowTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: <Widget>[
          _RowIcon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppText.subtitle.copyWith(fontSize: 15)),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recoger en el local: cambio inmediato con estado "guardando".
class _PickupRow extends StatefulWidget {
  const _PickupRow({required this.ops, required this.restaurant});

  final OperationsController ops;
  final RestaurantInfo restaurant;

  @override
  State<_PickupRow> createState() => _PickupRowState();
}

class _PickupRowState extends State<_PickupRow> {
  bool _saving = false;

  Future<void> _set(bool value) async {
    final r = widget.restaurant;
    setState(() => _saving = true);
    final failure = await widget.ops.updateProfile(
      RestaurantProfileInput(
        name: r.name,
        cuisine: r.cuisine,
        description: r.description,
        etaMin: r.etaMin,
        deliveryFee: r.deliveryFee,
        pickupEnabled: value,
        imagePath: r.imagePath,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      showFailureSnack(context, failure, onRetry: () => _set(value));
    } else {
      showAppSnack(
        context,
        value
            ? 'Los clientes ya pueden recoger en tu local.'
            : 'Recoger en el local quedó desactivado.',
        tone: AlertTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.restaurant.pickupEnabled;
    return MergeSemantics(
      child: InkWell(
        onTap: _saving ? null : () => _set(!enabled),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: <Widget>[
              const _RowIcon(Icons.shopping_bag_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Recoger en el local',
                      style: AppText.subtitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    SwapText(
                      _saving
                          ? 'Guardando…'
                          : enabled
                              ? 'Activo para tus clientes'
                              : 'Solo entrega a domicilio',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 64,
                height: 48,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.fast),
                    child: _saving
                        ? const SizedBox(
                            key: ValueKey<String>('saving'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            key: const ValueKey<String>('pickupSwitch'),
                            value: enabled,
                            onChanged: _set,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreSkeleton extends StatelessWidget {
  const _MoreSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        AppSpace.lg,
      ),
      children: const <Widget>[
        Text('Más', style: AppText.headline),
        SizedBox(height: AppSpace.lg),
        Shimmer(child: Bone(height: 230, radius: AppRadius.lg)),
        SizedBox(height: 40),
        Shimmer(child: Bone(height: 190, radius: AppRadius.lg)),
      ],
    );
  }
}
