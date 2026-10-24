import 'package:flutter/material.dart';

import '../core/controller.dart';
import '../core/delivery_flow.dart';
import '../core/theme.dart';
import '../models/delivery.dart';
import '../widgets/common.dart';
import '../widgets/delivery_widgets.dart';
import '../widgets/motion.dart';
import 'proof_screen.dart';

/// Estados visuales de Inicio (uno por momento operativo).
enum HomeMode { offline, waiting, active, completed }

HomeMode homeModeOf(DriverController controller) {
  final job = controller.active;
  if (job != null && job.stage == DeliveryStage.delivered) {
    return HomeMode.completed;
  }
  if (!controller.online) return HomeMode.offline;
  if (job == null) return HomeMode.waiting;
  return HomeMode.active;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final DriverController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-fetch the authoritative assignment on foreground return; a READY
    // event can arrive while Dart timers are suspended by Android.
    if (state == AppLifecycleState.resumed &&
        controller.isProduction && controller.signedIn && controller.online) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          controller.refreshHistory();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _showLockNotice = false;

  /// Dirección pedida mientras el backend confirma la disponibilidad.
  bool? _pendingOnline;

  /// Error de disponibilidad mostrado junto al control que lo provocó.
  String? _availabilityError;

  // Detección de nueva asignación (solo UI): waiting → active.
  HomeMode? _lastMode;
  String? _announceJobId;

  DriverController get controller => widget.controller;

  Future<void> _toggleAvailability(bool value) async {
    // Una acción de producción ya está en curso: no se apila otra.
    if (controller.actionBusy || _pendingOnline != null) return;
    setState(() {
      _pendingOnline = value;
      _availabilityError = null;
    });
    final changed = await controller.setOnlineAsync(value);
    if (!mounted) return;
    setState(() => _pendingOnline = null);
    if (changed) {
      Haptics.selection();
      if (_showLockNotice) setState(() => _showLockNotice = false);
      return;
    }
    Haptics.warning();
    if (controller.deliveryInProgress) {
      setState(() => _showLockNotice = true);
    } else if (controller.lastErrorMessage != null) {
      setState(() => _availabilityError = controller.lastErrorMessage);
    }
  }

  void _trackAssignment(HomeMode mode, DeliveryJob? job) {
    if (mode == HomeMode.active &&
        _lastMode == HomeMode.waiting &&
        job != null) {
      _announceJobId = job.id;
    }
    _lastMode = mode;
  }

  @override
  Widget build(BuildContext context) {
    final mode = homeModeOf(controller);
    final job = controller.active;
    final profile = controller.profile;
    _trackAssignment(mode, job);
    // Los avisos de bloqueo solo tienen sentido mientras la ruta sigue activa.
    if (!controller.deliveryInProgress) _showLockNotice = false;
    final locationIssue = controller.locationIssue;

    final Widget main = switch (mode) {
      HomeMode.offline => const _OfflinePanel(key: ValueKey('home-offline')),
      HomeMode.waiting => const _WaitingPanel(key: ValueKey('home-waiting')),
      HomeMode.active => ActiveDeliveryCard(
          key: ValueKey('home-active-${job!.id}'),
          job: job,
          announce: _announceJobId == job.id,
        ),
      HomeMode.completed => CompletedDeliveryPanel(
          key: ValueKey('home-completed-${job!.id}'),
          job: job,
          todayEarnings: controller.todayEarnings,
          onViewDeliveries: () => controller.setTab(1),
        ),
    };

    return ScreenPad(
      onRefresh: controller.refreshHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(
            child: ScreenHeading(
              title: 'Hola, ${profile.firstName}',
              subtitle: formatLongDate(controller.now()),
              trailing: Semantics(
                label: 'Perfil de ${profile.fullName}',
                button: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => controller.setTab(3),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: InitialsAvatar(initials: profile.initials),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.l + 2),
          Entrance(
            delay: const Duration(milliseconds: 40),
            child: _AvailabilityCard(
              online: controller.online,
              locked: controller.deliveryInProgress,
              pending: _pendingOnline,
              onChanged: _toggleAvailability,
            ),
          ),
          // Avisos ligados a la disponibilidad: aparecen junto al control.
          Reveal(
            visible: _showLockNotice && controller.deliveryInProgress,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.s + 2),
              child: NoticeBanner(
                key: const Key('lock-notice'),
                icon: Icons.lock_outline_rounded,
                tone: Tone.warning,
                message: 'Termina la entrega en curso para desconectarte.',
                onDismiss: () => setState(() => _showLockNotice = false),
              ),
            ),
          ),
          Reveal(
            visible: _availabilityError != null,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.s + 2),
              child: NoticeBanner(
                key: const Key('availability-error'),
                icon: Icons.error_outline_rounded,
                tone: Tone.error,
                message: _availabilityError ?? '',
                onDismiss: () => setState(() => _availabilityError = null),
              ),
            ),
          ),
          Reveal(
            visible: locationIssue != null,
            child: Padding(
              padding: const EdgeInsets.only(top: Space.s + 2),
              child: NoticeBanner(
                key: const Key('location-issue'),
                icon: Icons.location_off_outlined,
                tone: Tone.warning,
                message: locationIssue ?? '',
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          Entrance(
            delay: const Duration(milliseconds: 80),
            child: StateSwitcher(duration: Motion.emphasis, child: main),
          ),
          const SizedBox(height: Space.xxl),
          Entrance(
            delay: const Duration(milliseconds: 120),
            child: _DaySummary(controller: controller),
          ),
          Reveal(
            visible: controller.deliveryInProgress,
            child: const Padding(
              padding: EdgeInsets.only(top: Space.l),
              child: InlineNotice(
                icon: Icons.shield_outlined,
                text: 'Por seguridad, detente antes de usar la app en ruta.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Disponibilidad — control de alto valor pero compacto.
// En línea: tinte verde suave + punto con pulso único. En ruta: candado.
// Mientras el backend confirma: indicador de progreso en lugar del switch.
// ---------------------------------------------------------------------------
class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.online,
    required this.locked,
    required this.pending,
    required this.onChanged,
  });

  final bool online;
  final bool locked;

  /// Dirección solicitada mientras se confirma (`null` = sin operación).
  final bool? pending;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final busy = pending != null;
    final title = online ? 'En línea' : 'Fuera de línea';
    final subtitle = busy
        ? (pending! ? 'Conectando…' : 'Desconectando…')
        : locked
            ? 'Entrega en curso'
            : online
                ? 'Recibiendo pedidos'
                : 'No recibirás pedidos nuevos';

    final Widget trailing;
    if (busy) {
      trailing = SizedBox(
        key: const ValueKey('pending'),
        width: 52,
        height: 48,
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: reduced
                ? const Icon(Icons.hourglass_top_rounded, size: 21, color: kInk)
                : const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: kInk,
                  ),
          ),
        ),
      );
    } else if (locked) {
      trailing = const Padding(
        key: ValueKey('locked'),
        padding: EdgeInsets.symmetric(vertical: 10),
        child: StatusChip(
          label: 'En ruta',
          icon: Icons.lock_rounded,
          tone: Tone.warning,
        ),
      );
    } else if (reduced) {
      trailing = Semantics(
        key: const Key('availability-switch'),
        toggled: online,
        button: true,
        child: Container(
          width: 48,
          height: 30,
          alignment: online ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: online ? kGreen : kLineStrong,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(dimension: 24),
          ),
        ),
      );
    } else {
      trailing = Switch(
        key: const Key('availability-switch'),
        value: online,
        onChanged: onChanged,
      );
    }

    return Semantics(
      container: true,
      toggled: online,
      enabled: !locked && !busy,
      label: 'Disponibilidad: $title. $subtitle',
      hint: locked
          ? 'No puedes desconectarte durante una entrega en curso'
          : busy
              ? null
              : (online ? 'Toca para desconectarte' : 'Toca para conectarte'),
      onTap: busy ? null : () => onChanged(!online),
      excludeSemantics: true,
      child: Builder(
        builder: (context) {
          final decoration = BoxDecoration(
            color: online ? Color.lerp(kSurface, kSoftGreen, .55) : kSurface,
            borderRadius: Radii.lg,
            border: Border.all(
              color: online ? kGreen.withValues(alpha: .32) : kLine,
            ),
          );
          final child = Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: Radii.lg,
            onTap: busy ? null : () => onChanged(!online),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.s,
                  Space.s,
                  Space.m,
                  Space.s,
                ),
                child: Row(
                  children: [
                    StatusDot(
                      on: online,
                      onColor: kGreen,
                      offColor: kOfflineDot,
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StateSwitcher(
                            duration: Motion.short,
                            rise: 4,
                            animateSize: false,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              key: ValueKey(title),
                              style: AppText.section.copyWith(
                                fontSize: 17.5,
                                color: online ? kGreen : kInk,
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          StateSwitcher(
                            duration: Motion.short,
                            rise: 0,
                            animateSize: false,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              subtitle,
                              key: ValueKey(subtitle),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.s),
                    StateSwitcher(
                      duration: Motion.short,
                      rise: 0,
                      animateSize: false,
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
          if (reduced) return Container(decoration: decoration, child: child);
          return AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.standard,
            decoration: decoration,
            child: child,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paneles de estado
// ---------------------------------------------------------------------------
class _OfflinePanel extends StatelessWidget {
  const _OfflinePanel({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.bedtime_outlined,
        title: 'Estás fuera de línea',
        message: 'Conéctate cuando estés listo para recibir pedidos.',
      );
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.delivery_dining_rounded,
        tone: Tone.success,
        title: 'Esperando pedidos',
        message: 'Te avisaremos en cuanto tengas una asignación. '
            'Mantén la app abierta.',
      );
}

// ---------------------------------------------------------------------------
// Resumen de jornada (una sola superficie, sin tarjetas pesadas)
// ---------------------------------------------------------------------------
class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.controller});

  final DriverController controller;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Tu jornada',
            trailing: TextButton(
              onPressed: () => controller.setTab(2),
              child: const Text('Ver ganancias'),
            ),
          ),
          SurfaceCard(
            onTap: () => controller.setTab(2),
            semanticLabel: 'Resumen de tu jornada. Abrir ganancias',
            child: MetricStrip(
              items: [
                MetricItem(
                  label: 'Ganancias',
                  value: AnimatedNumber(
                    value: controller.todayEarnings,
                    format: money,
                    style: AppText.metric,
                  ),
                ),
                MetricItem(
                  label: 'Entregas',
                  value: AnimatedNumber(
                    value: controller.todayDeliveries.toDouble(),
                    format: (v) => v.round().toString(),
                    style: AppText.metric,
                  ),
                ),
                MetricItem(
                  label: 'Distancia',
                  value: AnimatedNumber(
                    value: controller.todayKm,
                    format: formatKm,
                    style: AppText.metric,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

// ===========================================================================
// HomeActionBar — CTA principal fijo en zona del pulgar (sobre la navegación).
// Los errores aparecen JUSTO encima del CTA que falló (no como modal).
// ===========================================================================
class HomeActionBar extends StatefulWidget {
  const HomeActionBar({super.key, required this.controller});

  final DriverController controller;

  @override
  State<HomeActionBar> createState() => _HomeActionBarState();
}

class _HomeActionBarState extends State<HomeActionBar>
    with SingleTickerProviderStateMixin {
  /// Ventana anti doble-toque: tras una acción, el siguiente CTA (que aparece
  /// en el mismo lugar) ignora toques durante 650 ms. Evita avanzar dos
  /// etapas por accidente con un toque doble en movimiento.
  late final AnimationController _cooldown;

  /// Último error y el CTA al que pertenece (se oculta al cambiar de estado).
  String? _error;
  String? _errorKey;

  DriverController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _cooldown = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addStatusListener((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _cooldown.dispose();
    super.dispose();
  }

  String _keyFor(HomeMode mode, DeliveryJob? job) =>
      'cta-${mode.name}-${job?.id}-${job?.stage.name}';

  void _run(Future<void> Function() action) {
    if (_cooldown.isAnimating) return;
    if (!Motion.reduced(context)) {
      _cooldown.forward(from: 0);
    }
    if (_error != null) setState(() => _error = null);
    action();
  }

  void _fail(String key, String fallback) {
    Haptics.warning();
    if (!mounted) return;
    setState(() {
      _error = controller.lastErrorMessage ?? fallback;
      _errorKey = key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = homeModeOf(controller);
    final job = controller.active;
    final key = _keyFor(mode, job);
    final busy = controller.actionBusy;
    final showError = _error != null && _errorKey == key && !busy;

    final Widget? action = switch (mode) {
      HomeMode.offline => PrimaryButton(
          key: const Key('primary-cta'),
          label: 'Conectarme',
          icon: Icons.power_settings_new_rounded,
          loading: busy,
          loadingLabel: 'Conectando…',
          onPressed: busy
              ? null
              : () => _run(() async {
                    if (await controller.setOnlineAsync(true)) {
                      Haptics.selection();
                    } else {
                      _fail(key, 'No pudimos conectarte. Intenta de nuevo.');
                    }
                  }),
        ),
      HomeMode.waiting => null,
      HomeMode.active => _stageButton(key, job!, busy, showError),
      HomeMode.completed => PrimaryButton(
          key: const Key('primary-cta'),
          label: 'Listo, seguir disponible',
          icon: Icons.check_rounded,
          loading: busy,
          onPressed: busy
              ? null
              : () => _run(() async {
                    if (await controller.dismissCompletedAsync()) {
                      Haptics.selection();
                    }
                  }),
        ),
    };

    return Reveal(
      visible: action != null,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kLine)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.m,
            Space.gutter,
            Space.m,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Reveal(
                visible: showError,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.s + 2),
                  child: NoticeBanner(
                    key: const Key('cta-error'),
                    icon: Icons.error_outline_rounded,
                    tone: Tone.error,
                    message: _error ?? '',
                    onDismiss: () => setState(() => _error = null),
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: _cooldown.isAnimating,
                child: StateSwitcher(
                  duration: Motion.short,
                  rise: 6,
                  animateSize: false,
                  child: KeyedSubtree(
                    key: ValueKey(key),
                    child: action ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageButton(String key, DeliveryJob job, bool busy, bool retry) {
    final ui = StagePresentation.of(job);
    return PrimaryButton(
      key: const Key('primary-cta'),
      label: retry ? 'Reintentar' : ui.cta,
      icon: retry ? Icons.refresh_rounded : ui.ctaIcon,
      loading: busy,
      loadingLabel: 'Actualizando…',
      onPressed: busy ? null : () => _run(() => _advance(key, job)),
    );
  }

  Future<void> _advance(String key, DeliveryJob job) async {
    final bool ok;
    switch (job.stage) {
      case DeliveryStage.assigned:
        ok = await controller.beginRouteAsync();
      case DeliveryStage.toRestaurant:
        ok = await controller.arrivedRestaurantAsync();
      case DeliveryStage.atRestaurant:
        ok = await controller.confirmPickupAsync();
      case DeliveryStage.pickedUp:
        ok = await controller.beginCustomerRouteAsync();
      case DeliveryStage.toCustomer:
        Haptics.selection();
        await Navigator.of(context).push<bool>(
          SheetRoute<bool>(
            reduceMotion: Motion.reduced(context),
            builder: (_) => ProofScreen(controller: controller),
          ),
        );
        return;
      case DeliveryStage.delivered:
        return;
    }
    if (ok) {
      Haptics.confirm();
      return;
    }
    _fail(key, 'No fue posible actualizar la entrega. Intenta de nuevo.');
  }
}
