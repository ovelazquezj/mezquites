import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/capture_service.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/common.dart';
import 'help_screen.dart';
import 'observation_form.dart';

/// Pantalla de captura (gate #4, Q5.A): SOLO cámara nativa.
///
/// NO existe botón/acción de galería en ninguna parte. La única forma de iniciar
/// una observación es tomar la foto con la cámara del dispositivo, que además
/// inyecta lat/lon/timestamp REALES en el EXIF.
///
/// El submit es fire-and-forget: encola localmente como "pendiente" y dispara el
/// POST sin bloquear la UI. NUNCA muestra estado de validación individual (gate #9).
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _service = CaptureService();
  CameraController? _controller;
  bool _initializing = false;
  String? _error;
  CaptureResult? _shot;

  Future<void> _startCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      final cams = await _service.cameras();
      if (cams.isEmpty) {
        throw CaptureException('No se encontró cámara en el dispositivo.');
      }
      final controller = CameraController(
        cams.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      final msg = e is CaptureException
          ? e.message
          : 'No se pudo usar la cámara. Inténtalo de nuevo.';
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _take() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final result = await _service.capture(controller);
      if (!mounted) return;
      setState(() => _shot = result);
    } catch (e) {
      final msg = e is CaptureException
          ? e.message
          : 'No se pudo usar la cámara. Inténtalo de nuevo.';
      setState(() => _error = msg);
    }
  }

  /// Fire-and-forget: encola pendiente, dispara POST, no espera (Q5.A).
  void _submit(ObservationDraft draft) {
    final pending = MineObservation(
      observationId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      capturedAt: draft.capturedAt,
      nivelG4: draft.nivelG4.wire,
      flagCuscuta: draft.flagCuscuta,
      flagDanio: draft.flagDanio,
      tamanio: draft.tamanio.wire,
      contexto: draft.contexto.wire,
      pending: true,
    );
    ref.read(pendingQueueProvider.notifier).add(pending);

    // Dispara sin await (no bloquea la UI). Al confirmar, retira de pendientes.
    ref.read(apiClientProvider).submitObservation(draft).then((serverId) {
      ref.read(pendingQueueProvider.notifier).remove(pending.observationId);
      ref.invalidate(myObservationsProvider);
    }).catchError((_) {
      // Permanece "pendiente" para reintento; NO es estado de validación.
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Copy.captureQueued)),
    );
    setState(() => _shot = null); // listo para la siguiente
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot;
    return Scaffold(
      appBar: AppBar(
        title: const Text(Copy.captureTitle),
        actions: [
          IconButton(
            key: const Key('help_button'),
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
            ),
          ),
        ],
      ),
      body: shot != null
          ? ObservationForm(capture: shot, onSubmit: _submit)
          : _CameraPane(
              controller: _controller,
              initializing: _initializing,
              error: _error,
              onStart: _startCamera,
              onTake: _take,
            ),
    );
  }
}

/// Panel de cámara. SIN ninguna acción de galería (gate #4).
class _CameraPane extends StatelessWidget {
  const _CameraPane({
    required this.controller,
    required this.initializing,
    required this.error,
    required this.onStart,
    required this.onTake,
  });

  final CameraController? controller;
  final bool initializing;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const InfoNote(Copy.captureCameraOnly),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: controller != null && controller!.value.isInitialized
                  ? CameraPreview(controller!)
                  : (initializing
                      ? const CircularProgressIndicator()
                      : Text(error ?? 'Toca para abrir la cámara')),
            ),
          ),
          const SizedBox(height: 16),
          if (controller == null)
            FilledButton.icon(
              key: const Key('open_camera'),
              onPressed: initializing ? null : onStart,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Abrir cámara'),
            )
          else
            FilledButton.icon(
              key: const Key('take_photo'),
              onPressed: onTake,
              icon: const Icon(Icons.camera),
              label: const Text('Tomar foto'),
            ),
          // Nota: NO hay botón de galería aquí ni en ninguna otra pantalla.
        ],
      ),
    );
  }
}
