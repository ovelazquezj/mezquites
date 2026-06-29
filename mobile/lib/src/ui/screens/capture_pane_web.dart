import 'package:flutter/material.dart';

import '../../services/camera_web.dart';
import '../../services/capture_service.dart';
import '../../services/capture_service_web.dart';
import '../copy.dart';
import '../widgets/common.dart';
import 'problem_report_screen.dart';

/// Panel de captura WEB robusto (CR-018): preview en vivo con `getUserMedia` + fallback.
///
/// Cambios sobre CR-005: ya NO se compuerta por user-agent (un Honor que no se reconocía
/// dejaba el botón muerto). Se intenta abrir la cámara con `getUserMedia` en cualquier
/// dispositivo con soporte (un escritorio con webcam capturando es cámara, no galería ⇒
/// gate #4 intacto: NUNCA galería). `getUserMedia` SÍ pide permiso al navegador.
///
/// Si `getUserMedia` no está soportado (WebView viejo), usa directo la cámara del sistema
/// (`image_picker`). Ante errores ofrece Reintentar, "Tomar con la cámara del sistema" y
/// "Reportar un problema".
enum _Phase { idle, opening, preview, error }

class CapturePane extends StatefulWidget {
  const CapturePane({super.key, required this.onCaptured});

  final void Function(CaptureResult result) onCaptured;

  @override
  State<CapturePane> createState() => _CapturePaneState();
}

class _CapturePaneState extends State<CapturePane> {
  final _service = WebCaptureService();

  _Phase _phase = _Phase.idle;
  bool _busy = false;
  String? _error;
  String? _errorDetail;

  List<CameraDevice> _cameras = const <CameraDevice>[];
  int _deviceIndex = 0;

  bool get _supported => _service.liveCameraSupported;

  @override
  void dispose() {
    _service.releaseCamera();
    super.dispose();
  }

  // --- Acciones ---

  /// Abre (o reabre) el preview en vivo. Sin [deviceId] usa la cámara trasera por defecto.
  Future<void> _open({String? deviceId}) async {
    setState(() {
      _phase = _Phase.opening;
      _error = null;
    });
    try {
      final cams = await _service.openLiveCamera(deviceId: deviceId);
      if (!mounted) {
        _service.releaseCamera();
        return;
      }
      setState(() {
        _cameras = cams;
        _phase = _Phase.preview;
      });
    } on CameraException catch (e) {
      _toError(_copyForKind(e.kind), e.detail);
    } catch (e) {
      _toError(Copy.cameraGenericError, e.toString());
    }
  }

  /// Cambia al siguiente lente disponible (defensa multi-lente).
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _deviceIndex = (_deviceIndex + 1) % _cameras.length;
    await _open(deviceId: _cameras[_deviceIndex].deviceId);
  }

  /// Toma la foto del preview en vivo.
  Future<void> _capture() async {
    setState(() => _busy = true);
    try {
      final result = await _service.captureFromLivePreview();
      if (!mounted) return;
      widget.onCaptured(result);
    } on CameraException catch (e) {
      _toError(_copyForKind(e.kind), e.detail);
    } on CaptureException catch (e) {
      // Error de ubicación (geolocator): el texto ya es llano.
      _toError(e.message, e.message);
    } catch (e) {
      _toError(Copy.cameraGenericError, e.toString());
    }
  }

  /// Fallback: cámara del sistema (`image_picker`). Para WebViews sin `getUserMedia`
  /// o como alternativa cuando el preview en vivo falla.
  Future<void> _systemCapture() async {
    setState(() => _busy = true);
    try {
      final result = await _service.captureFromSystemCamera();
      if (!mounted) return;
      widget.onCaptured(result);
    } on CaptureException catch (e) {
      _toError(e.message, e.message);
    } catch (e) {
      _toError(Copy.cameraGenericError, e.toString());
    }
  }

  void _report() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProblemReportScreen(
          prefillContext: 'camera',
          errorDetail: _errorDetail,
        ),
      ),
    );
  }

  void _toError(String message, String detail) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _error = message;
      _errorDetail = detail;
      _busy = false;
    });
  }

  String _copyForKind(CameraErrorKind kind) {
    switch (kind) {
      case CameraErrorKind.permission:
        return Copy.cameraPermissionDenied;
      case CameraErrorKind.notFound:
        return Copy.cameraNotFound;
      case CameraErrorKind.inUse:
        return Copy.cameraInUse;
      case CameraErrorKind.unsupported:
      case CameraErrorKind.generic:
        return Copy.cameraGenericError;
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const InfoNote(Copy.captureCameraOnly),
          const SizedBox(height: 16),
          Expanded(child: Center(child: _body())),
          const SizedBox(height: 16),
          ..._actions(),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.opening:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(Copy.cameraStarting, textAlign: TextAlign.center),
          ],
        );
      case _Phase.preview:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.expand(
            child: HtmlElementView(viewType: _service.previewViewType),
          ),
        );
      case _Phase.error:
        return Text(
          _error ?? Copy.cameraGenericError,
          textAlign: TextAlign.center,
        );
      case _Phase.idle:
        return const Text(
          'Toca el botón para tomar la foto con la cámara.',
          textAlign: TextAlign.center,
        );
    }
  }

  List<Widget> _actions() {
    switch (_phase) {
      case _Phase.opening:
        return const [];
      case _Phase.preview:
        return [
          if (_cameras.length > 1)
            OutlinedButton.icon(
              key: const Key('switch_camera'),
              onPressed: _busy ? null : _switchCamera,
              icon: const Icon(Icons.cameraswitch),
              label: const Text(Copy.cameraSwitch),
            ),
          if (_cameras.length > 1) const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('take_photo'),
            onPressed: _busy ? null : _capture,
            icon: const Icon(Icons.camera),
            label: const Text(Copy.cameraTakePhoto),
          ),
        ];
      case _Phase.error:
        return [
          FilledButton.icon(
            key: const Key('retry_camera'),
            onPressed: _busy
                ? null
                : () => _supported ? _open() : _systemCapture(),
            icon: const Icon(Icons.refresh),
            label: const Text(Copy.cameraRetry),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('system_camera'),
            onPressed: _busy ? null : _systemCapture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tomar con la cámara del sistema'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('report_problem'),
            onPressed: _report,
            icon: const Icon(Icons.flag_outlined),
            label: const Text(Copy.reportButton),
          ),
        ];
      case _Phase.idle:
        return [
          FilledButton.icon(
            key: const Key('open_camera'),
            // Con soporte: preview en vivo (pide permiso). Sin soporte: directo al
            // fallback del sistema (gate #3: no se bloquea, gate #4: cámara, no galería).
            onPressed: _busy
                ? null
                : () => _supported ? _open() : _systemCapture(),
            icon: const Icon(Icons.camera_alt),
            label: const Text(Copy.cameraOpen),
          ),
        ];
    }
  }
}
