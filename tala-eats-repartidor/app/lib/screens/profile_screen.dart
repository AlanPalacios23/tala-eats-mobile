import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../models/driver_profile.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Versión visible en Perfil (mantener sincronizada con pubspec.yaml).
const String kAppVersionLabel = 'v1.2.4';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final DriverController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _logoutBlocked = false;

  DriverController get controller => widget.controller;

  Future<void> _logout() async {
    if (controller.logoutLocked) {
      Haptics.warning();
      setState(() => _logoutBlocked = true);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Dejarás de recibir pedidos hasta que vuelvas a entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('logout-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!await controller.logoutAsync()) {
      if (!mounted) return;
      Haptics.warning();
      if (controller.logoutLocked) {
        setState(() => _logoutBlocked = true);
      } else if (controller.lastErrorMessage != null) {
        showAppSnack(
          context,
          controller.lastErrorMessage!,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    // Sin documentos registrados no se puede afirmar que están "al día".
    final hasDocs = profile.documents.isNotEmpty;
    final docsOk = hasDocs && profile.documentsUpToDate;
    final busy = controller.actionBusy;
    if (!controller.logoutLocked) _logoutBlocked = false;
    return ScreenPad(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Entrance(child: ScreenHeading(title: 'Perfil')),
          const SizedBox(height: Space.xl),
          Entrance(
            delay: const Duration(milliseconds: 40),
            child: _IdentityCard(controller: controller),
          ),
          const SizedBox(height: Space.xxl),
          const SectionHeader('Trabajo'),
          Entrance(
            delay: const Duration(milliseconds: 80),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListRow(
                    icon: Icons.two_wheeler_rounded,
                    title: 'Vehículo',
                    subtitle: '${profile.vehicleType} · ${_plateText(profile)}',
                    onTap: () => _showVehicle(context, profile),
                  ),
                  const Divider(indent: 68),
                  ListRow(
                    icon: Icons.badge_outlined,
                    title: 'Documentos',
                    subtitle: !hasDocs
                        ? 'Sin documentos registrados'
                        : docsOk
                            ? 'Todos vigentes'
                            : 'Revisa tus documentos pendientes',
                    tone: docsOk ? Tone.neutral : Tone.warning,
                    trailing: StatusChip(
                      label: docsOk ? 'Al día' : 'Pendiente',
                      icon: docsOk
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      tone: docsOk ? Tone.success : Tone.warning,
                    ),
                    onTap: () => _showDocuments(context, profile),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.xxl),
          const SectionHeader('Cuenta'),
          Entrance(
            delay: const Duration(milliseconds: 110),
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListRow(
                    icon: Icons.shield_outlined,
                    title: 'Seguridad',
                    subtitle: 'Acceso y sesión',
                    onTap: () => _showSecurity(context),
                  ),
                  const Divider(indent: 68),
                  ListRow(
                    icon: Icons.support_agent_rounded,
                    title: 'Ayuda',
                    subtitle: 'Problemas frecuentes en una entrega',
                    onTap: () => _showSupport(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.xxl),
          Reveal(
            visible: _logoutBlocked && controller.logoutLocked,
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: NoticeBanner(
                key: const Key('logout-blocked'),
                icon: Icons.lock_outline_rounded,
                tone: Tone.warning,
                message: 'Termina la entrega en curso antes de cerrar sesión.',
                onDismiss: () => setState(() => _logoutBlocked = false),
              ),
            ),
          ),
          // Visible pero no protagonista: acción de texto en rojo, sin borde.
          Center(
            child: TextButton.icon(
              key: const Key('logout'),
              onPressed: busy ? null : _logout,
              style: TextButton.styleFrom(
                foregroundColor: kRed,
                minimumSize: const Size(160, 48),
              ),
              icon: StateSwitcher(
                duration: Motion.short,
                rise: 0,
                animateSize: false,
                alignment: Alignment.center,
                child: busy
                    ? SizedBox.square(
                        key: const ValueKey('logout-busy'),
                        dimension: 18,
                        child: Motion.reduced(context)
                            ? const Icon(
                                Icons.hourglass_top_rounded,
                                size: 18,
                                color: kMuted,
                              )
                            : const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kMuted,
                              ),
                      )
                    : const Icon(
                        Icons.logout_rounded,
                        key: ValueKey('logout-icon'),
                      ),
              ),
              label: Text(busy ? 'Un momento…' : 'Cerrar sesión'),
            ),
          ),
          const SizedBox(height: Space.l),
          const Center(
            child: Text(
              'Tala Eats Repartidor · $kAppVersionLabel',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }

  void _showVehicle(BuildContext context, DriverProfile profile) =>
      showAppSheet<void>(
        context: context,
        title: 'Vehículo',
        subtitle: 'Datos registrados para tus entregas.',
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailRow(label: 'Tipo', value: profile.vehicleType),
            DetailRow(label: 'Placa', value: capitalize(_plateText(profile))),
            const SizedBox(height: Space.m),
            const InlineNotice(
              icon: Icons.info_outline_rounded,
              text: 'Para cambiar de vehículo, contacta a soporte de '
                  'repartidores.',
            ),
          ],
        ),
      );

  void _showDocuments(BuildContext context, DriverProfile profile) =>
      showAppSheet<void>(
        context: context,
        title: 'Documentos',
        subtitle: 'Estado de tu documentación.',
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (profile.documents.isEmpty)
              const EmptyState(
                icon: Icons.description_outlined,
                compact: true,
                title: 'Aún no hay documentos',
                message: 'Cuando Tala Eats revise tu registro, aquí verás '
                    'el estado de cada documento.',
              ),
            for (final doc in profile.documents)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.s),
                child: Row(
                  children: [
                    const IconTile(icon: Icons.description_outlined, size: 36),
                    const SizedBox(width: Space.m),
                    Expanded(child: Text(doc.name, style: AppText.title)),
                    const SizedBox(width: Space.s),
                    _DocumentChip(status: doc.status),
                  ],
                ),
              ),
          ],
        ),
      );

  void _showSecurity(BuildContext context) => showAppSheet<void>(
        context: context,
        title: 'Seguridad',
        builder: (_) => const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoBlock(
              icon: Icons.password_rounded,
              title: 'Contraseña',
              text: 'Si necesitas cambiarla, usa “¿Olvidaste tu contraseña?” '
                  'al iniciar sesión o contacta a soporte.',
            ),
            _InfoBlock(
              icon: Icons.phonelink_lock_rounded,
              title: 'Sesión en este teléfono',
              text: 'Cierra sesión si alguien más usará este dispositivo. '
                  'No se puede cerrar sesión durante una entrega en curso.',
            ),
          ],
        ),
      );

  void _showSupport(BuildContext context) => showAppSheet<void>(
        context: context,
        title: 'Ayuda',
        subtitle: 'Qué hacer en situaciones frecuentes.',
        builder: (_) => const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FaqTile(
              question: 'El cliente no responde',
              answer: 'Espera unos minutos en el punto de entrega y revisa '
                  'las indicaciones del pedido. No dejes el pedido sin '
                  'confirmar con el PIN.',
            ),
            _FaqTile(
              question: 'El restaurante se retrasa',
              answer: 'Permanece en “En el restaurante” hasta recibir el '
                  'pedido completo. Verifica el número de pedido antes de '
                  'confirmar la recogida.',
            ),
            _FaqTile(
              question: 'El pedido llegó incompleto o dañado',
              answer: 'No confirmes la recogida. Informa al restaurante y '
                  'contacta a soporte de repartidores.',
            ),
          ],
        ),
      );
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.controller});

  final DriverController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: profile.initials, size: 56),
              const SizedBox(width: Space.m + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.section,
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(profile.zone, style: AppText.caption),
                    const SizedBox(height: Space.s),
                    profile.verified
                        ? const StatusChip(
                            label: 'Verificado',
                            icon: Icons.verified_rounded,
                            tone: Tone.success,
                          )
                        : const StatusChip(
                            label: 'En verificación',
                            icon: Icons.hourglass_top_rounded,
                            tone: Tone.warning,
                          ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          const Divider(),
          const SizedBox(height: Space.l),
          MetricStrip(
            items: [
              MetricItem(
                label: 'Aceptación',
                value: Text('${controller.acceptance}%'),
              ),
              MetricItem(
                label: 'Entregas hoy',
                value: Text('${controller.todayDeliveries}'),
              ),
              MetricItem(
                label: 'Km hoy',
                value: Text(controller.todayKm.toStringAsFixed(1)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentChip extends StatelessWidget {
  const _DocumentChip({required this.status});

  final DocumentStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        DocumentStatus.verified => const StatusChip(
            label: 'Vigente',
            icon: Icons.check_circle_rounded,
            tone: Tone.success,
          ),
        DocumentStatus.pending => const StatusChip(
            label: 'En revisión',
            icon: Icons.schedule_rounded,
            tone: Tone.warning,
          ),
        DocumentStatus.expired => const StatusChip(
            label: 'Vencido',
            icon: Icons.error_outline_rounded,
            tone: Tone.error,
          ),
      };
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon: icon, size: 36),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.title),
                  const SizedBox(height: Space.xxs),
                  Text(text, style: AppText.bodyMuted),
                ],
              ),
            ),
          ],
        ),
      );
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: Space.m),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: kInk,
        collapsedIconColor: kMuted,
        shape: const Border(),
        collapsedShape: const Border(),
        expansionAnimationStyle: Motion.reduced(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: Motion.medium,
                curve: Motion.standard,
              ),
        title: Text(question, style: AppText.title),
        children: [Text(answer, style: AppText.bodyMuted)],
      );
}

/// Terminación de placa legible; el backend puede no tenerla registrada.
String _plateText(DriverProfile profile) {
  final suffix = profile.plateSuffix.trim();
  if (suffix.isEmpty || suffix == '—' || suffix == '-') {
    return 'Placa no registrada';
  }
  return 'placa terminación $suffix';
}
