import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/controller.dart';
import '../core/theme.dart';
import '../core/validators.dart';
import '../models/delivery.dart';
import '../widgets/common.dart';
import '../widgets/delivery_widgets.dart';
import '../widgets/motion.dart';

/// Prueba de entrega: evidencia → PIN de 4 dígitos → confirmación → éxito.
///
/// Hardening conservado: el CTA permanece deshabilitado hasta tener PIN válido
/// y evidencia; el controlador vuelve a validar todo y el estado de la entrega
/// antes de acreditar (ver [DriverController.submitProof]).
class ProofScreen extends StatefulWidget {
  const ProofScreen({super.key, required this.controller});

  final DriverController controller;

  @override
  State<ProofScreen> createState() => _ProofScreenState();
}

class _ProofScreenState extends State<ProofScreen> {
  final TextEditingController _pin = TextEditingController();
  final FocusNode _pinFocus = FocusNode();

  String? _photoPath;
  DateTime? _photoTime;
  bool _pinTouched = false;
  int _pinShake = 0;
  String? _pinError;
  String? _formError;
  bool _completed = false;
  DeliveryJob? _snapshot;

  /// La confirmación ya se aceptó y falló por red/servidor: el reintento no
  /// vuelve a pedir confirmación (la evidencia subida se reutiliza en el
  /// controlador). Se reinicia si cambian PIN o foto.
  bool _retryReady = false;

  bool get _pinValid => Validators.isPin(_pin.text);
  bool get _photoAttached => _photoPath != null;
  bool get _ready => _pinValid && _photoAttached && !widget.controller.actionBusy;
  bool get _dirty => _pin.text.isNotEmpty || _photoAttached;
  int get _doneSteps => (_pinValid ? 1 : 0) + (_photoAttached ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _pinFocus.addListener(_onPinFocus);
  }

  void _onPinFocus() {
    if (!_pinFocus.hasFocus && _pin.text.isNotEmpty && !_pinTouched) {
      setState(() => _pinTouched = true);
    }
  }

  @override
  void dispose() {
    _pinFocus
      ..removeListener(_onPinFocus)
      ..dispose();
    _pin.dispose();
    super.dispose();
  }

  void _onPinChanged(String value) {
    setState(() {
      _pinError = null;
      _formError = null;
      _retryReady = false;
    });
    if (Validators.isPin(value)) {
      Haptics.selection();
      _pinFocus.unfocus();
    }
  }

  /// Repetir foto = quitar la actual y abrir la cámara otra vez
  /// (reutiliza exactamente el mismo flujo de producción).
  Future<void> _retakePhoto() async {
    await _togglePhoto();
    if (!mounted || _photoAttached) return;
    await _togglePhoto();
  }

  Future<void> _togglePhoto() async {
    if (widget.controller.actionBusy) return;
    if (_retryReady) setState(() => _retryReady = false);
    if (_photoAttached) {
      Haptics.selection();
      await _deleteLocalProof();
      if (!mounted) return;
      setState(() {
        _photoPath = null;
        _photoTime = null;
        _formError = null;
      });
      return;
    }
    if (!widget.controller.isProduction) {
      Haptics.selection();
      setState(() {
        _photoPath = 'mock-delivery-proof.jpg';
        _photoTime = widget.controller.now();
        _formError = null;
      });
      return;
    }
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 78,
        maxWidth: 1600,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image == null || !mounted) return;
      Haptics.selection();
      setState(() {
        _photoPath = image.path;
        _photoTime = widget.controller.now();
        _formError = null;
      });
    } catch (_) {
      if (!mounted) return;
      Haptics.warning();
      setState(() => _formError =
          'No pudimos abrir la cámara. Revisa el permiso e intenta de nuevo.');
    }
  }

  Future<void> _requestCompletion() async {
    FocusScope.of(context).unfocus();
    if (!_ready) {
      _reject(pin: !_pinValid);
      return;
    }
    final job = widget.controller.active;
    if (job == null) return;
    if (!_retryReady) {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => _ConfirmSheet(job: job),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _formError = null);

    final result = await widget.controller.submitProofAsync(
      pin: _pin.text,
      evidencePath: _photoPath ?? '',
    );
    if (!mounted) return;
    switch (result) {
      case ProofResult.completed:
        Haptics.success();
        // Se marca completado ANTES de esperar la limpieza local: así la
        // vista no parpadea a "no disponible" mientras se cierra.
        setState(() => _completed = true);
        await _deleteLocalProof();
        if (!mounted) return;
        Navigator.of(context).pop(true);
      case ProofResult.invalidPin:
        _pin.clear();
        _reject(
          pin: true,
          message: 'PIN incorrecto. Confírmalo con el cliente.',
        );
        _pinFocus.requestFocus();
      case ProofResult.missingEvidence:
        _reject(pin: false);
      case ProofResult.wrongStage:
        Haptics.warning();
        setState(
          () => _formError = 'Esta entrega ya no puede confirmarse desde aquí.',
        );
      case ProofResult.failed:
        Haptics.warning();
        setState(() {
          _retryReady = true;
          _formError = widget.controller.lastErrorMessage ??
              'No pudimos confirmar la entrega. Revisa tu conexión.';
        });
    }
  }

  void _reject({required bool pin, String? message}) {
    Haptics.warning();
    setState(() {
      _pinTouched = true;
      if (pin) {
        _pinShake++;
        _pinError = message;
      } else {
        _formError = 'Agrega la foto de evidencia para continuar.';
      }
    });
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir sin confirmar?'),
        content: const Text(
          'Se borrarán el PIN y la foto. La entrega seguirá en curso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Seguir aquí'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _close() async {
    // Durante el envío no se abandona la pantalla a medias.
    if (widget.controller.actionBusy) return;
    if (_dirty && !_completed) {
      final leave = await _confirmDiscard();
      if (!leave || !mounted) return;
      await _deleteLocalProof();
      if (!mounted) return;
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _deleteLocalProof() async {
    if (!widget.controller.isProduction) return;
    final path = _photoPath;
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // La evidencia autoritativa ya vive en el endpoint privado del backend.
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          // Tras completar, se conserva la última vista mientras la ruta
          // se cierra (evita un parpadeo del estado "no disponible").
          if (!_completed) _snapshot = widget.controller.active;
          final job = _snapshot;
          return PopScope<bool>(
            canPop: !_dirty || _completed,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop) _close();
            },
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: widget.controller.actionBusy ? null : _close,
                  icon: const Icon(Icons.close_rounded),
                ),
                title: const Text('Confirmar entrega'),
              ),
              body: job == null || job.stage != DeliveryStage.toCustomer
                  ? _UnavailableBody(onBack: () => Navigator.of(context).pop())
                  : _buildForm(job),
              bottomNavigationBar: job == null ||
                      job.stage != DeliveryStage.toCustomer
                  ? null
                  : _buildBottomBar(),
            ),
          );
        },
      );

  Widget _buildForm(DeliveryJob job) {
    final pinIncomplete = _pinTouched && !_pinValid;
    final remaining = Validators.pinLength - _pin.text.length;
    final busy = widget.controller.actionBusy;
    final canCall = hasCustomerPhone(job);
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.xs,
          Space.gutter,
          Space.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ENTREGA ${job.id}', style: AppText.overline),
            const SizedBox(height: Space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.customer,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.screenTitle,
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(job.customerAddress, style: AppText.bodyMuted),
                    ],
                  ),
                ),
                if (canCall) ...[
                  const SizedBox(width: Space.s),
                  IconButton.outlined(
                    key: const Key('proof-call'),
                    tooltip: 'Llamar a ${job.customer}',
                    onPressed: () => callCustomer(context, job.customerPhone!),
                    style: IconButton.styleFrom(
                      side: const BorderSide(color: kLineStrong),
                    ),
                    icon: const Icon(Icons.call_outlined),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Space.xl),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Space.s,
              runSpacing: Space.xs,
              children: [
                const Text('Antes de finalizar', style: AppText.section),
                StateSwitcher(
                  duration: Motion.short,
                  rise: 4,
                  animateSize: false,
                  alignment: Alignment.centerRight,
                  child: StatusChip(
                    key: ValueKey(_doneSteps),
                    label: '$_doneSteps de 2 listos',
                    icon: _doneSteps == 2
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    tone: _doneSteps == 2 ? Tone.success : Tone.neutral,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            // Mientras se sube la evidencia y se confirma, los pasos quedan
            // bloqueados (y atenuados) para que nada cambie a mitad del envío.
            IgnorePointer(
              ignoring: busy,
              child: Builder(
                builder: (context) {
                  final steps = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StepCard(
                        number: 1,
                        done: _photoAttached,
                        title: 'Foto de evidencia',
                        subtitle:
                            'Toma una foto del pedido en el punto de entrega.',
                        child: _EvidenceTile(
                          attached: _photoAttached,
                          path: _photoPath,
                          time: _photoTime,
                          onToggle: _togglePhoto,
                          onRetake: _retakePhoto,
                        ),
                      ),
                      const SizedBox(height: Space.m),
                      _StepCard(
                        number: 2,
                        done: _pinValid,
                        title: 'PIN del cliente',
                        subtitle: 'Pide al cliente su PIN de 4 dígitos.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Shake(
                              trigger: _pinShake,
                              child: PinInput(
                                controller: _pin,
                                focusNode: _pinFocus,
                                error: _pinError != null || pinIncomplete,
                                onChanged: _onPinChanged,
                              ),
                            ),
                            Reveal(
                              visible: _pinError != null || pinIncomplete,
                              child: Padding(
                                padding: const EdgeInsets.only(top: Space.s),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      size: 16,
                                      color: kRed,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _pinError ??
                                            (remaining == 1
                                                ? 'Falta 1 dígito.'
                                                : 'Faltan $remaining dígitos.'),
                                        style: AppText.caption
                                            .copyWith(color: kRed),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  if (Motion.reduced(context)) {
                    return Opacity(
                      opacity: busy ? .55 : 1.0,
                      child: steps,
                    );
                  }
                  return AnimatedOpacity(
                    duration: Motion.short,
                    opacity: busy ? .55 : 1.0,
                    child: steps,
                  );
                },
              ),
            ),
            if (job.note != null) ...[
              const SizedBox(height: Space.l),
              InlineNotice(icon: Icons.sticky_note_2_outlined, text: job.note!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final busy = widget.controller.actionBusy;
    final hint = !_photoAttached && !_pinValid
        ? 'Toma la foto e ingresa el PIN para continuar.'
        : !_photoAttached
            ? 'Falta la foto de evidencia.'
            : 'Falta el PIN del cliente.';
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kLine)),
      ),
      child: SafeArea(
        top: false,
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
                visible: _formError != null && !busy,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.s + 2),
                  child: NoticeBanner(
                    key: const Key('proof-error'),
                    icon: Icons.error_outline_rounded,
                    tone: Tone.error,
                    message: _formError ?? '',
                  ),
                ),
              ),
              Reveal(
                visible: busy,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: Space.s + 2),
                  child: Text(
                    'Enviando evidencia y confirmando con Tala Eats…',
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                ),
              ),
              Reveal(
                visible: !_ready && !busy && _formError == null,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.s + 2),
                  child: Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: AppText.caption,
                  ),
                ),
              ),
              PrimaryButton(
                key: const Key('proof-complete'),
                label: _retryReady ? 'Reintentar confirmación' : 'Completar entrega',
                icon: _retryReady ? Icons.refresh_rounded : Icons.check_rounded,
                loading: busy,
                loadingLabel: 'Confirmando…',
                onPressed: _ready ? _requestCompletion : null,
                semanticHint: _ready
                    ? null
                    : 'Disponible al adjuntar la foto e ingresar el PIN',
                stackOnNarrow: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paso numerado con estado (número → check animado)
// ---------------------------------------------------------------------------
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.done,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final int number;
  final bool done;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final indicatorContent = done
        ? const Icon(
            Icons.check_rounded,
            key: ValueKey('done'),
            size: 17,
            color: Colors.white,
          )
        : Text(
            '$number',
            key: const ValueKey('todo'),
            style: AppText.caption.copyWith(
              color: kInk,
              fontWeight: FontWeight.w800,
            ),
          );
    final decoration = BoxDecoration(
      color: done ? kGreen : kSurfaceSunken,
      shape: BoxShape.circle,
    );
    final indicator = Motion.reduced(context)
        ? Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: decoration,
            child: indicatorContent,
          )
        : AnimatedContainer(
            duration: Motion.short,
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: decoration,
            child: StateSwitcher(
              duration: Motion.short,
              rise: 0,
              animateSize: false,
              alignment: Alignment.center,
              child: indicatorContent,
            ),
          );

    return SurfaceCard(
      borderColor: done ? kGreen.withValues(alpha: .35) : kLine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: done ? 'Paso $number completo' : 'Paso $number',
                excludeSemantics: true,
                child: indicator,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title),
                    const SizedBox(height: Space.xxs),
                    Text(subtitle, style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PinInput — 4 casillas grandes sobre un único campo numérico accesible.
// ---------------------------------------------------------------------------
class PinInput extends StatelessWidget {
  const PinInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.error = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([controller, focusNode]),
        builder: (context, _) {
          final text = controller.text;
          final focused = focusNode.hasFocus;
          return Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  alwaysIncludeSemantics: true,
                  child: Semantics(
                    label: 'PIN del cliente, 4 dígitos',
                    child: TextField(
                      key: const Key('pin-field'),
                      controller: controller,
                      focusNode: focusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(Validators.pinLength),
                      ],
                      autocorrect: false,
                      enableSuggestions: false,
                      enableInteractiveSelection: false,
                      showCursor: false,
                      onChanged: onChanged,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Row(
                  children: [
                    for (var i = 0; i < Validators.pinLength; i++) ...[
                      if (i > 0) const SizedBox(width: Space.s + 2),
                      Expanded(
                        child: _PinBox(
                          digit: i < text.length ? text[i] : null,
                          active: focused &&
                              (i == text.length ||
                                  (i == Validators.pinLength - 1 &&
                                      text.length == Validators.pinLength)),
                          error: error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _PinBox extends StatelessWidget {
  const _PinBox({
    required this.digit,
    required this.active,
    required this.error,
  });

  final String? digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final Color border = error
        ? kRed
        : active
            ? kInk
            : digit != null
                ? kLineStrong
                : kLine;
    final decoration = BoxDecoration(
      color: digit != null ? kSurface : kBackground,
      borderRadius: Radii.md,
      border: Border.all(color: border, width: active || error ? 1.6 : 1),
    );
    final content = StateSwitcher(
      duration: Motion.micro,
      rise: 6,
      animateSize: false,
      alignment: Alignment.center,
      child: Text(
        digit ?? '',
        key: ValueKey(digit ?? 'empty'),
        style: AppText.screenTitle.copyWith(
          fontSize: 26,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (Motion.reduced(context)) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        decoration: decoration,
        child: content,
      );
    }
    return AnimatedContainer(
      duration: Motion.micro,
      curve: Motion.standard,
      height: 60,
      alignment: Alignment.center,
      decoration: decoration,
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Evidencia privada: cámara real + carga autenticada al backend
// ---------------------------------------------------------------------------
class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.attached,
    required this.path,
    required this.time,
    required this.onToggle,
    required this.onRetake,
  });

  final bool attached;
  final String? path;
  final DateTime? time;
  final VoidCallback onToggle;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Este estado vive dentro de una tarjeta, por eso el ancho REAL del
        // componente importa más que el ancho de pantalla. En 320–360 dp la
        // zona útil puede caer por debajo de 260 dp.
        final compact = constraints.maxWidth < 300 || scale >= 1.2;

        final attachedChild = Column(
          key: const ValueKey('photo-attached'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              image: true,
              label: 'Foto de evidencia adjunta',
              child: ClipRRect(
                borderRadius: Radii.md,
                child: SizedBox(
                  height: 148,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (path != null && File(path!).existsSync())
                        Image.file(
                          File(path!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const _PhotoPlaceholder(),
                        )
                      else
                        const _PhotoPlaceholder(),
                      Positioned(
                        left: Space.s,
                        right: Space.s,
                        bottom: Space.s,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: kInk.withValues(alpha: .78),
                              borderRadius: BorderRadius.circular(Radii.pill),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      time == null
                                          ? 'Foto adjunta'
                                          : 'Foto · ${formatClock(time!)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.s),
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    key: const Key('retake-photo'),
                    onPressed: onRetake,
                    icon: const Icon(Icons.photo_camera_outlined, size: 19),
                    label: const Text('Repetir foto'),
                  ),
                  const SizedBox(height: Space.xs),
                  TextButton.icon(
                    key: const Key('remove-photo'),
                    onPressed: onToggle,
                    style: TextButton.styleFrom(foregroundColor: kRed),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Quitar foto'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  TextButton.icon(
                    key: const Key('retake-photo'),
                    onPressed: onRetake,
                    icon: const Icon(Icons.photo_camera_outlined, size: 19),
                    label: const Text('Repetir'),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('remove-photo'),
                    onPressed: onToggle,
                    style: TextButton.styleFrom(foregroundColor: kRed),
                    child: const Text('Quitar'),
                  ),
                ],
              ),
          ],
        );

        final emptyChild = SizedBox(
          key: const ValueKey('photo-empty'),
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('attach-photo'),
            onPressed: onToggle,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 64),
              side: const BorderSide(color: kLineStrong),
            ),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Tomar foto'),
          ),
        );

        final child = attached ? attachedChild : emptyChild;
        // En el estado más estrecho evitamos mantener simultáneamente el
        // botón viejo y la evidencia nueva dentro de AnimatedSwitcher.
        if (compact || Motion.reduced(context)) return child;
        return StateSwitcher(duration: Motion.medium, child: child);
      },
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: kSoftGreen,
        child: Center(
          child: Icon(Icons.image_rounded, color: kGreen, size: 36),
        ),
      );
}

// ---------------------------------------------------------------------------
// Confirmación previa (resumen + doble confirmación explícita)
// ---------------------------------------------------------------------------
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.job});

  final DeliveryJob job;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width <= 360 ? Space.l : Space.xl;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              '¿Confirmar entrega a ${job.customer}?',
              style: AppText.stageTitle,
            ),
          ),
          const SizedBox(height: Space.xs),
          const Text(
            'Esta acción finaliza el pedido y no se puede deshacer.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: Space.l),
          const _CheckLine(text: 'Foto de evidencia adjunta'),
          const _CheckLine(text: 'PIN del cliente ingresado'),
          const Divider(height: Space.xl),
          Text('Tu ganancia', style: AppText.bodyMuted),
          const SizedBox(height: Space.xs),
          Text(money(job.earning), style: AppText.money.copyWith(fontSize: 17)),
          const SizedBox(height: Space.l),
          PrimaryButton(
            key: const Key('proof-confirm'),
            label: 'Completar entrega',
            stackOnNarrow: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: Space.xs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: kGreen, size: 20),
            const SizedBox(width: Space.s + 2),
            Expanded(child: Text(text, style: AppText.body)),
          ],
        ),
      );
}

class _UnavailableBody extends StatelessWidget {
  const _UnavailableBody({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmptyState(
              icon: Icons.lock_outline_rounded,
              tone: Tone.warning,
              title: 'No disponible',
              message: 'Esta entrega no está lista para confirmarse.',
              actionLabel: 'Volver',
              actionIcon: Icons.arrow_back_rounded,
              onAction: onBack,
            ),
          ],
        ),
      );
}
