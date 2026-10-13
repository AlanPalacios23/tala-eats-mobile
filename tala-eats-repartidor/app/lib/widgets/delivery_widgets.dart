import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/delivery_flow.dart';
import '../core/theme.dart';
import '../models/delivery.dart';
import 'common.dart';
import 'motion.dart';

// ===========================================================================
// StageProgress — progreso segmentado de la entrega (texto + barra).
// ===========================================================================
class StageProgress extends StatelessWidget {
  const StageProgress({super.key, required this.stage, this.compact = false});

  final DeliveryStage stage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final step = stage.step;
    final reduced = Motion.reduced(context);
    final bar = Row(
      children: [
        for (var i = 0; i < kDeliverySteps; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: SizedBox(
                height: compact ? 4 : 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: kSurfaceSunken),
                    reduced
                        ? FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: i < step ? 1.0 : 0.0,
                            child: ColoredBox(
                              color: stage == DeliveryStage.delivered
                                  ? kGreen
                                  : kBrandDeep,
                            ),
                          )
                        : TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: i < step ? 1.0 : 0.0),
                            duration: Motion.emphasis,
                            curve: Motion.standard,
                            builder: (context, fill, _) =>
                                FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: fill,
                              child: ColoredBox(
                                color: stage == DeliveryStage.delivered
                                    ? kGreen
                                    : kBrandDeep,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
    return Semantics(
      label: 'Progreso: paso $step de $kDeliverySteps, ${stage.label}',
      excludeSemantics: true,
      child: bar,
    );
  }
}

// ===========================================================================
// RouteStops — restaurante y cliente con estado (hecho / actual / siguiente).
// ===========================================================================
enum StopState { done, current, upcoming }

class RouteStops extends StatelessWidget {
  const RouteStops({super.key, required this.job});

  final DeliveryJob job;

  @override
  Widget build(BuildContext context) {
    final step = job.stage.step;
    final pickupState = step >= 3 ? StopState.done : StopState.current;
    final dropoffState = step >= 5
        ? StopState.done
        : step >= 3
            ? StopState.current
            : StopState.upcoming;
    return Column(
      children: [
        _StopRow(
          icon: Icons.storefront_rounded,
          kind: 'Recoger',
          title: job.restaurant,
          subtitle: job.restaurantAddress,
          state: pickupState,
          connectorBelow: true,
        ),
        _StopRow(
          icon: Icons.location_on_rounded,
          kind: 'Entregar',
          title: job.customer,
          subtitle: job.customerAddress,
          state: dropoffState,
          connectorBelow: false,
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.icon,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.state,
    required this.connectorBelow,
  });

  final IconData icon;
  final String kind;
  final String title;
  final String subtitle;
  final StopState state;
  final bool connectorBelow;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final current = state == StopState.current;
    final done = state == StopState.done;
    final Color tileColor = current
        ? kSoftOrange
        : done
            ? kSoftGreen
            : kSurfaceSunken;
    final Color iconColor = current
        ? kBrandInk
        : done
            ? kGreen
            : kMuted;
    final statusText = switch (state) {
      StopState.done => 'Listo',
      StopState.current => 'Ahora',
      StopState.upcoming => 'Después',
    };

    final stopIcon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        color: iconColor,
        size: 20,
      ),
    );

    final stopDetails = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                kind.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.overline.copyWith(
                  color: current ? kBrandInk : kMuted,
                ),
              ),
            ),
            if (done) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle_rounded,
                size: 13,
                color: kGreen,
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.title,
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption,
        ),
      ],
    );

    return Semantics(
      container: true,
      label: '$kind: $title, $subtitle. $statusText',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  reduced
                      ? stopIcon
                      : AnimatedContainer(
                          duration: Motion.medium,
                          curve: Motion.standard,
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tileColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: StateSwitcher(
                            duration: Motion.short,
                            rise: 0,
                            animateSize: false,
                            alignment: Alignment.center,
                            child: Icon(
                              done ? Icons.check_rounded : icon,
                              key: ValueKey(done),
                              color: iconColor,
                              size: 20,
                            ),
                          ),
                        ),
                  if (connectorBelow)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: reduced
                            ? Container(
                                width: 2,
                                decoration: BoxDecoration(
                                  color: done
                                      ? kGreen.withValues(alpha: .35)
                                      : kLine,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                            : AnimatedContainer(
                                duration: Motion.medium,
                                width: 2,
                                decoration: BoxDecoration(
                                  color: done
                                      ? kGreen.withValues(alpha: .35)
                                      : kLine,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: 1,
                  bottom: connectorBelow ? Space.l : 0,
                ),
                child: reduced
                    ? Opacity(
                        opacity: state == StopState.upcoming ? .62 : 1.0,
                        child: stopDetails,
                      )
                    : AnimatedOpacity(
                        duration: Motion.medium,
                        opacity: state == StopState.upcoming ? .62 : 1.0,
                        child: stopDetails,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// JobMeta — distancia, tiempo estimado y ganancia (texto + icono).
// ===========================================================================
class JobMeta extends StatelessWidget {
  const JobMeta({super.key, required this.job});

  final DeliveryJob job;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: Space.l,
        runSpacing: Space.s,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _MetaItem(
            icon: Icons.route_rounded,
            text: formatKm(job.distanceKm),
            semantics: 'Distancia ${formatKm(job.distanceKm)}',
          ),
          _MetaItem(
            icon: Icons.schedule_rounded,
            text: '${job.etaMinutes} min',
            semantics: 'Tiempo estimado ${job.etaMinutes} minutos',
          ),
          _MetaItem(
            icon: Icons.payments_outlined,
            text: 'Ganas ${money(job.earning)}',
            semantics: 'Tu ganancia ${money(job.earning)}',
            color: kGreen,
            strong: true,
          ),
        ],
      );
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.text,
    required this.semantics,
    this.color = kInk,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final String semantics;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semantics,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: strong ? color : kMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                style: AppText.money.copyWith(
                  color: color,
                  fontSize: 14,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

// ===========================================================================
// FlashStrip — confirmación breve de una acción (se oculta sola).
// ===========================================================================
class FlashStrip extends StatelessWidget {
  const FlashStrip({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.l,
            vertical: Space.s + 2,
          ),
          color: kSoftGreen,
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 18, color: kGreen),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(
                    color: kGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ===========================================================================
// ActiveDeliveryCard — la entrega domina la jerarquía de Inicio.
//
// Jerarquía (v1.0.1 polish):
//   1. Fase + progreso + etapa actual (qué está pasando).
//   2. Destino actual con Navegar / Llamar a la mano (a dónde voy).
//   3. Siguiente / anterior parada en una sola línea (contexto).
//   4. Distancia · tiempo · ganancia + Detalles (secundario).
// ===========================================================================
class ActiveDeliveryCard extends StatefulWidget {
  const ActiveDeliveryCard({super.key, required this.job, this.announce = false});

  final DeliveryJob job;

  /// `true` cuando la tarjeta aparece por una asignación nueva: dirige la
  /// mirada con un destello único del borde y un háptico.
  final bool announce;

  @override
  State<ActiveDeliveryCard> createState() => _ActiveDeliveryCardState();
}

class _ActiveDeliveryCardState extends State<ActiveDeliveryCard>
    with SingleTickerProviderStateMixin {
  /// Mantiene visible la confirmación ~2.4 s sin usar timers sueltos.
  late final AnimationController _flash;
  String? _flashMessage;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..addStatusListener(_onFlashStatus);
    if (widget.announce) Haptics.confirm();
  }

  void _onFlashStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _flashMessage = null);
    }
  }

  @override
  void didUpdateWidget(ActiveDeliveryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final advanced = oldWidget.job.id == widget.job.id &&
        widget.job.stage.step > oldWidget.job.stage.step;
    if (advanced) {
      if (Motion.reduced(context)) {
        _flash.stop();
        _flashMessage = null;
      } else {
        _flashMessage = StagePresentation.of(widget.job).reachedMessage;
        _flash.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final ui = StagePresentation.of(job);
    final pickup = job.stage.isPickupPhase;
    final focusAddress = pickup ? job.restaurantAddress : job.customerAddress;
    // Evita repetir la dirección: si la instrucción ES la dirección del
    // destino actual, ya se lee en el bloque de destino.
    final showInstruction = ui.instruction.trim() != focusAddress.trim();

    return AttentionFlash(
      active: widget.announce,
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Reveal(
              visible: _flashMessage != null,
              child: FlashStrip(message: _flashMessage ?? ''),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.l,
                Space.l,
                Space.l,
                Space.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Space.s,
                    runSpacing: Space.xxs,
                    children: [
                      StateSwitcher(
                        duration: Motion.short,
                        rise: 4,
                        animateSize: false,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${ui.phase.toUpperCase()} · ${job.stage.step}/$kDeliverySteps',
                          key: ValueKey('phase-${job.stage.name}'),
                          style: AppText.overline.copyWith(
                            color: pickup ? kBrandInk : kInk,
                          ),
                        ),
                      ),
                      Text(job.id, style: AppText.overline),
                    ],
                  ),
                  const SizedBox(height: Space.s + 2),
                  StageProgress(stage: job.stage),
                  const SizedBox(height: Space.l),
                  StateSwitcher(
                    duration: Motion.emphasis,
                    child: Column(
                      key: ValueKey('stage-${job.stage.name}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          liveRegion: true,
                          child: Text(ui.title, style: AppText.stageTitle),
                        ),
                        if (showInstruction) ...[
                          const SizedBox(height: Space.xs),
                          Text(ui.instruction, style: AppText.bodyMuted),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.l),
                  StateSwitcher(
                    duration: Motion.medium,
                    child: _FocusStop(
                      key: ValueKey('focus-${pickup ? 'pickup' : 'dropoff'}'),
                      job: job,
                      pickup: pickup,
                    ),
                  ),
                  const SizedBox(height: Space.m),
                  _ContextStop(job: job, pickup: pickup),
                  Reveal(
                    visible: !pickup && job.note != null,
                    child: Padding(
                      padding: const EdgeInsets.only(top: Space.m),
                      child: NoticeBanner(
                        icon: Icons.sticky_note_2_outlined,
                        message: job.note ?? '',
                        tone: Tone.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.l),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.l,
                Space.xs,
                Space.xs,
                Space.xs,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 310 ||
                      MediaQuery.textScalerOf(context).scale(1) >= 1.25;
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        JobMeta(job: job),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => showDeliveryDetails(context, job),
                            child: const Text('Detalles'),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: JobMeta(job: job)),
                      TextButton(
                        onPressed: () => showDeliveryDetails(context, job),
                        child: const Text('Detalles'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Destino actual: nombre, dirección y acciones de orientación a la mano.
class _FocusStop extends StatelessWidget {
  const _FocusStop({super.key, required this.job, required this.pickup});

  final DeliveryJob job;
  final bool pickup;

  @override
  Widget build(BuildContext context) {
    final name = pickup ? job.restaurant : job.customer;
    final address = pickup ? job.restaurantAddress : job.customerAddress;
    final kind = pickup ? 'Recoger en' : 'Entregar a';
    final canNavigate = hasNavigationTarget(job);
    final canCall = !pickup && hasCustomerPhone(job);

    return Container(
      padding: const EdgeInsets.all(Space.m + 2),
      decoration: BoxDecoration(
        color: pickup ? kSoftOrange.withValues(alpha: .55) : kBackground,
        borderRadius: Radii.md,
        border: Border.all(
          color: pickup ? kBrand.withValues(alpha: .18) : kLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: '$kind $name, $address',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  icon: pickup
                      ? Icons.storefront_rounded
                      : Icons.location_on_rounded,
                  tone: pickup ? Tone.brand : Tone.neutral,
                  size: 40,
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kind.toUpperCase(),
                        style: AppText.overline.copyWith(
                          color: pickup ? kBrandInk : kMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.section,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (canNavigate || canCall) ...[
            const SizedBox(height: Space.m),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                if (canNavigate)
                  CompactAction(
                    key: const Key('focus-navigate'),
                    icon: Icons.navigation_rounded,
                    label: 'Navegar',
                    semanticLabel: 'Abrir navegación hacia $name',
                    onPressed: () => openJobNavigation(context, job),
                  ),
                if (canCall)
                  CompactAction(
                    key: const Key('focus-call'),
                    icon: Icons.call_outlined,
                    label: 'Llamar',
                    semanticLabel: 'Llamar a $name',
                    onPressed: () => callCustomer(context, job.customerPhone!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Una línea de contexto: la siguiente parada (recogida) o la ya hecha
/// (entrega). Mantiene la continuidad de la ruta sin otra tarjeta.
class _ContextStop extends StatelessWidget {
  const _ContextStop({required this.job, required this.pickup});

  final DeliveryJob job;
  final bool pickup;

  @override
  Widget build(BuildContext context) {
    final label = pickup
        ? 'Después: ${job.customer} · ${job.customerAddress}'
        : 'Recogido en ${job.restaurant}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs),
        child: Row(
          children: [
            Icon(
              pickup
                  ? Icons.radio_button_unchecked_rounded
                  : Icons.check_circle_rounded,
              size: 16,
              color: pickup ? kMuted : kGreen,
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// CompletedDeliveryPanel — éxito discreto y claro (sin confetti).
// ===========================================================================
class CompletedDeliveryPanel extends StatelessWidget {
  const CompletedDeliveryPanel({
    super.key,
    required this.job,
    required this.todayEarnings,
    required this.onViewDeliveries,
  });

  final DeliveryJob job;
  final double todayEarnings;
  final VoidCallback onViewDeliveries;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        padding: const EdgeInsets.fromLTRB(
          Space.xl,
          Space.xxl,
          Space.xl,
          Space.m,
        ),
        child: Column(
          children: [
            const SuccessMark(size: 64),
            const SizedBox(height: Space.l),
            Semantics(
              header: true,
              liveRegion: true,
              child: const Text(
                'Entrega completada',
                style: AppText.stageTitle,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              '${job.id} · ${job.customer}',
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.l + 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: CountUp(
                value: job.earning,
                format: (v) => '+${money(v)}',
                style: AppText.display.copyWith(color: kGreen, fontSize: 34),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              'Llevas ${money(todayEarnings)} hoy',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.m),
            TextButton.icon(
              onPressed: onViewDeliveries,
              icon: const Icon(Icons.receipt_long_rounded, size: 19),
              label: const Text('Ver mis entregas'),
            ),
          ],
        ),
      );
}

// ===========================================================================
// Hoja de detalles del pedido (revelación progresiva).
// ===========================================================================
Future<void> showDeliveryDetails(BuildContext context, DeliveryJob job) =>
    showAppSheet<void>(
      context: context,
      title: 'Pedido ${job.id}',
      subtitle: job.completedAt != null
          ? 'Entregado a las ${formatClock(job.completedAt!)}'
          : job.stage.label,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SurfaceCard(
            padding: const EdgeInsets.all(Space.l),
            child: RouteStops(job: job),
          ),
          if (job.note != null) ...[
            const SizedBox(height: Space.m),
            NoticeBanner(
              icon: Icons.sticky_note_2_outlined,
              message: job.note!,
              tone: Tone.brand,
            ),
          ],
          const SizedBox(height: Space.l),
          DetailRow(label: 'Distancia', value: formatKm(job.distanceKm)),
          DetailRow(label: 'Tiempo estimado', value: '${job.etaMinutes} min'),
          const Divider(height: Space.xl),
          DetailRow(
            label: 'Tu ganancia',
            value: money(job.earning),
            emphasize: true,
          ),
          DetailRow(label: 'Total del pedido', value: money(job.total)),
          if (_navigationTarget(job) != null ||
              (job.customerPhone?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: Space.l),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                if (_navigationTarget(job) != null)
                  OutlinedButton.icon(
                    onPressed: () => openJobNavigation(context, job),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Navegar'),
                  ),
                if (job.customerPhone?.trim().isNotEmpty ?? false)
                  OutlinedButton.icon(
                    onPressed: () => callCustomer(context, job.customerPhone!),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Llamar al cliente'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.xs),
          const InlineNotice(
            icon: Icons.info_outline_rounded,
            text: 'El total del pedido lo paga el cliente y no forma parte '
                'de tu ganancia.',
          ),
        ],
      ),
    );

/// Hay coordenadas del destino actual (restaurante o cliente).
bool hasNavigationTarget(DeliveryJob job) => _navigationTarget(job) != null;

/// El backend entregó un teléfono del cliente.
bool hasCustomerPhone(DeliveryJob job) =>
    job.customerPhone?.trim().isNotEmpty ?? false;

({double lat, double lng})? _navigationTarget(DeliveryJob job) {
  final customerPhase = job.stage == DeliveryStage.pickedUp ||
      job.stage == DeliveryStage.toCustomer;
  final lat = customerPhase ? job.customerLat : job.restaurantLat;
  final lng = customerPhase ? job.customerLng : job.restaurantLng;
  if (lat == null || lng == null) return null;
  return (lat: lat, lng: lng);
}

Future<void> openJobNavigation(BuildContext context, DeliveryJob job) async {
  final target = _navigationTarget(job);
  if (target == null) return;
  final uri = Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'destination': '${target.lat},${target.lng}',
    'travelmode': 'driving',
  });
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
    showAppSnack(context, 'No pudimos abrir la navegación.',
        icon: Icons.error_outline_rounded);
  }
}

/// Abre el marcador del teléfono (comportamiento de producción sin cambios).
Future<void> callCustomer(BuildContext context, String rawPhone) async {
  final phone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (phone.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: phone);
  if (!await launchUrl(uri) && context.mounted) {
    showAppSnack(context, 'No pudimos abrir el teléfono.',
        icon: Icons.error_outline_rounded);
  }
}
