import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../services/capture_service.dart';
import '../../services/capture_service_native.dart';
import '../copy.dart';
import '../widgets/common.dart';

/// Panel de captura NATIVO (móvil): cámara nativa con preview (gate #4).
/// SIN ninguna acción de galería. Aísla `camera`/`native_exif`/`dart:io` para que
/// el build web no los compile (ver `capture_pane.dart`, import condicional).
class CapturePane extends StatefulWidget {
  const CapturePane({super.key, required this.onCaptured});

  /// Se invoca con la captura (imagen por ruta + EXIF/geo reales) lista.
  final void Function(CaptureResult result) onCaptured;

  @override
  State<CapturePane> createState() => _CapturePaneState();
}

class _CapturePaneState extends State<CapturePane> {
  final _service = NativeCaptureService();
  CameraController? _controller;
  bool _initializing = false;
  String? _error;

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
      widget.onCaptured(result);
    } catch (e) {
      final msg = e is CaptureException
          ? e.message
          : 'No se pudo usar la cámara. Inténtalo de nuevo.';
      setState(() => _error = msg);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const InfoNote(Copy.captureCameraOnly),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: controller != null && controller.value.isInitialized
                  ? CameraPreview(controller)
                  : (_initializing
                      ? const CircularProgressIndicator()
                      : Text(_error ?? 'Toca para abrir la cámara')),
            ),
          ),
          const SizedBox(height: 16),
          if (controller == null)
            FilledButton.icon(
              key: const Key('open_camera'),
              onPressed: _initializing ? null : _startCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Abrir cámara'),
            )
          else
            FilledButton.icon(
              key: const Key('take_photo'),
              onPressed: _take,
              icon: const Icon(Icons.camera),
              label: const Text('Tomar foto'),
            ),
          // Nota: NO hay botón de galería aquí ni en ninguna otra pantalla.
        ],
      ),
    );
  }
}
