import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/failures.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../state/session_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import '../widgets/motion.dart';
import '../widgets/surfaces.dart';

class OnboardingPendingScreen extends StatefulWidget {
  const OnboardingPendingScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<OnboardingPendingScreen> createState() => _OnboardingPendingScreenState();
}

class _OnboardingPendingScreenState extends State<OnboardingPendingScreen> {
  AppFailure? _failure;
  DateTime? _checkedAt;
  bool _changed = false;

  Future<void> _refresh() async {
    if (widget.session.approvalRefreshing) return;
    final before = widget.session.onboardingApplication?.status;
    final failure = await widget.session.refreshApproval();
    if (!mounted) return;
    setState(() {
      _failure = failure;
      _checkedAt = DateTime.now();
      _changed = before != widget.session.onboardingApplication?.status;
    });
  }

  /// Resultado de la última consulta, para que el restaurante sepa que sí
  /// se revisó aunque el estado siga igual.
  String _checkedLabel(DateTime at) {
    final time = clockTime(at);
    if (_failure != null) return 'Último intento: $time';
    if (_changed) return 'Estado actualizado a las $time';
    return 'Sin cambios · consultado a las $time';
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.session.onboardingApplication;
    final status = application?.status ?? 'pending';
    final needsInfo = status == 'needs_info';
    final rejected = status == 'rejected';
    final suspended = status == 'suspended';
    final blocked = rejected || suspended;
    final name = application?.businessName ?? 'tu restaurante';
    final hasNote = (application?.notes ?? '').trim().isNotEmpty;
    final String title;
    final String message;
    if (rejected) {
      title = 'La solicitud necesita una nueva revisión';
      message = 'La solicitud de $name no fue aprobada. '
          '${hasNote ? 'Revisa la nota de revisión y contacta' : 'Contacta'} '
          'a soporte antes de volver a enviarla.';
    } else if (suspended) {
      title = 'La solicitud está suspendida';
      message = 'La solicitud de $name fue suspendida por el equipo de '
          'Tala Eats.${hasNote ? ' Revisa la nota de revisión para conocer el motivo.' : ''}';
    } else if (needsInfo) {
      title = 'Necesitamos un dato más';
      message = 'El equipo de Tala Eats necesita información adicional antes '
          'de activar $name.';
    } else {
      title = 'Tu restaurante está en revisión';
      message = 'Recibimos $name. Tu panel se activará en cuanto el equipo de '
          'Tala Eats apruebe el alta.';
    }
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.ink,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpace.gutter),
                children: <Widget>[
                  const SizedBox(height: 32),
                  Entrance(
                    child: Center(
                      child: _StatusHalo(
                        icon: blocked
                            ? Icons.error_outline_rounded
                            : (needsInfo
                                ? Icons.description_outlined
                                : Icons.schedule_rounded),
                        color: blocked
                            ? AppColors.red
                            : (needsInfo ? AppColors.brandText : AppColors.green),
                        tint: blocked
                            ? AppColors.redTint
                            : (needsInfo ? AppColors.brandTint : AppColors.greenTint),
                        animate: !blocked,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Entrance(
                    delay: const Duration(milliseconds: 70),
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppText.display.copyWith(fontSize: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Entrance(
                    delay: const Duration(milliseconds: 120),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppText.bodySoft,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Entrance(
                    delay: const Duration(milliseconds: 180),
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('Estado de solicitud', style: AppText.label),
                          const SizedBox(height: 8),
                          Text(
                            rejected
                                ? 'No aprobada'
                                : (suspended
                                    ? 'Suspendida'
                                    : (needsInfo ? 'Información requerida' : 'En revisión')),
                            style: AppText.title,
                          ),
                          const SizedBox(height: 16),
                          const _ApprovalStep(
                            title: 'Solicitud enviada',
                            state: _StepState.done,
                          ),
                          _ApprovalStep(
                            title: blocked
                                ? 'Revisión de Tala Eats: detenida'
                                : (needsInfo
                                    ? 'Revisión de Tala Eats: falta información'
                                    : 'Revisión de Tala Eats'),
                            state: blocked
                                ? _StepState.blocked
                                : (needsInfo ? _StepState.attention : _StepState.current),
                          ),
                          const _ApprovalStep(
                            title: 'Panel listo para recibir pedidos',
                            state: _StepState.pending,
                            last: true,
                          ),
                          if (hasNote) ...<Widget>[
                            const SizedBox(height: 14),
                            const Divider(),
                            const SizedBox(height: 14),
                            const Text('Nota de revisión', style: AppText.label),
                            const SizedBox(height: 6),
                            Text(application!.notes, style: AppText.bodySoft),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_failure != null) ...<Widget>[
                    const SizedBox(height: 18),
                    InlineAlert.failure(_failure!),
                  ],
                  if (!blocked) ...<Widget>[
                    const SectionHeader('Mientras tanto'),
                    const _Tip(
                      icon: Icons.photo_camera_outlined,
                      text: 'Prepara fotos claras de tus platillos para completar '
                          'tu menú en cuanto se active el panel.',
                    ),
                    const _Tip(
                      icon: Icons.location_on_outlined,
                      text: 'Ten a la mano la dirección exacta de tu local: la '
                          'usarás para calcular los envíos.',
                    ),
                    const _Tip(
                      icon: Icons.refresh_rounded,
                      text: 'Toca «Actualizar estado» o desliza la pantalla '
                          'hacia abajo para saber si ya te aprobaron.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AppButton(
                        label: 'Actualizar estado',
                        loadingLabel: 'Consultando…',
                        loading: widget.session.approvalRefreshing,
                        icon: Icons.refresh_rounded,
                        onPressed: _refresh,
                      ),
                      if (_checkedAt != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          _checkedLabel(_checkedAt!),
                          key: const ValueKey<String>('pendingCheckedAt'),
                          textAlign: TextAlign.center,
                          style: AppText.caption,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Cerrar sesión',
                    variant: AppButtonVariant.ghost,
                    onPressed: widget.session.approvalRefreshing
                        ? null
                        : () => widget.session.signOut(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, current, attention, blocked, pending }

/// Paso del proceso de aprobación: ícono + texto (nunca solo color).
class _ApprovalStep extends StatelessWidget {
  const _ApprovalStep({
    required this.title,
    required this.state,
    this.last = false,
  });

  final String title;
  final _StepState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String status;
    switch (state) {
      case _StepState.done:
        icon = Icons.check_circle_rounded;
        color = AppColors.green;
        status = 'completado';
        break;
      case _StepState.current:
        icon = Icons.schedule_rounded;
        color = AppColors.amber;
        status = 'en curso';
        break;
      case _StepState.attention:
        icon = Icons.description_outlined;
        color = AppColors.brandText;
        status = 'requiere acción';
        break;
      case _StepState.blocked:
        icon = Icons.error_outline_rounded;
        color = AppColors.red;
        status = 'detenido';
        break;
      case _StepState.pending:
        icon = Icons.radio_button_unchecked_rounded;
        color = AppColors.inkFaint;
        status = 'pendiente';
        break;
    }
    return Semantics(
      label: '$title, $status',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 10),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: AppText.label.copyWith(
                  fontSize: 14.5,
                  fontWeight: state == _StepState.pending
                      ? FontWeight.w600
                      : FontWeight.w700,
                  color: state == _StepState.pending
                      ? AppColors.inkSoft
                      : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Consejo breve con ícono (pantalla de espera).
class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, size: 19, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: AppText.bodySoft.copyWith(fontSize: 14.5)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ícono de estado con ondas suaves que se expanden mientras se espera la
/// revisión. Con «reducir movimiento» (o estado detenido) queda estático.
class _StatusHalo extends StatefulWidget {
  const _StatusHalo({
    required this.icon,
    required this.color,
    required this.tint,
    required this.animate,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final bool animate;

  @override
  State<_StatusHalo> createState() => _StatusHaloState();
}

class _StatusHaloState extends State<_StatusHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  void _sync() {
    if (widget.animate && !Motion.reduced(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0.35;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StatusHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 148,
        height: 148,
        child: CustomPaint(
          painter: _HaloPainter(progress: _controller, color: widget.color),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: widget.tint,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 4),
              ),
              child: Icon(widget.icon, color: widget.color, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.progress, required this.color})
      : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = math.min(size.width, size.height) / 2;
    for (var i = 0; i < 2; i++) {
      final t = (progress.value + i * 0.5) % 1.0;
      final radius = 36 + (maxRadius - 36) * t;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.28 * (1 - t));
      canvas.drawCircle(center, radius, paint);
    }
    canvas.drawCircle(
      center,
      46,
      Paint()..color = color.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}
