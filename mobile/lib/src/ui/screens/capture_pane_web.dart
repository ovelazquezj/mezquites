import 'package:flutter/material.dart';

import '../../services/capture_service.dart';
import '../../services/capture_service_web.dart';
import '../copy.dart';
import '../widgets/common.dart';

/// Panel de captura WEB (teléfono/tablet): cámara del navegador vía `image_picker`
/// (gate #4, W0=a). En escritorio la captura se **bloquea/advierte** (no es objetivo
/// y no se permite galería). SIN preview en vivo: un toque abre la cámara del SO.
class CapturePane extends StatefulWidget {
  const CapturePane({super.key, required this.onCaptured});

  final void Function(CaptureResult result) onCaptured;

  @override
  State<CapturePane> createState() => _CapturePaneState();
}

class _CapturePaneState extends State<CapturePane> {
  final _service = WebCaptureService();
  bool _busy = false;
  String? _error;

  Future<void> _take() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _service.captureFromCamera();
      if (!mounted) return;
      widget.onCaptured(result);
    } catch (e) {
      final msg = e is CaptureException
          ? e.message
          : 'No se pudo usar la cámara. Inténtalo de nuevo.';
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _service.cameraAvailable;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const InfoNote(Copy.captureCameraOnly),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Text(
                available
                    ? (_error ?? 'Toca el botón para tomar la foto con la cámara.')
                    : _service.unavailableReason,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('open_camera'),
            onPressed: (!available || _busy) ? null : _take,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tomar foto'),
          ),
          // Nota: SIEMPRE ImageSource.camera; NUNCA galería (gate #4).
        ],
      ),
    );
  }
}
