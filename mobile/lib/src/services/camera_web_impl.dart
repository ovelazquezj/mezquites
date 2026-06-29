import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'camera_web_shared.dart';

/// Cámara web robusta (CR-018) — implementación WEB con `getUserMedia`.
///
/// A diferencia del antiguo `<input capture>` (que delegaba al SO y NUNCA pedía permiso
/// por navegador), `getUserMedia` SÍ dispara el diálogo de permiso de cámara del navegador
/// y nos da un stream en vivo. El frame se dibuja en un `<canvas>` y se exporta a JPEG.
///
/// Gate #4: esto es CÁMARA (no galería). Defensas de campo: reintento sin restricciones si
/// `OverconstrainedError`, "Cambiar cámara" multi-lente, y se detienen TODOS los tracks al
/// disponer/cambiar/capturar (evita la cámara "ocupada").
class WebCamera {
  WebCamera() : viewType = 'mezquite-camera-${_seq++}';

  /// Secuencia global para un viewType único por instancia (no se puede re-registrar uno igual).
  static int _seq = 0;

  /// viewType del HtmlElementView del preview en vivo.
  final String viewType;

  web.MediaStream? _stream;
  web.HTMLVideoElement? _video;
  bool _registered = false;

  /// `true` si el navegador ofrece `navigator.mediaDevices.getUserMedia` (requiere HTTPS/localhost).
  bool get isSupported {
    try {
      final nav = web.window.navigator as JSObject;
      final md = nav['mediaDevices'];
      if (!md.isDefinedAndNotNull) return false;
      return (md as JSObject).has('getUserMedia');
    } catch (_) {
      return false;
    }
  }

  /// Abre (o reabre, al cambiar de cámara) el stream y lo muestra en el `<video>`.
  ///
  /// Sin [deviceId] pide la cámara trasera (`facingMode: {ideal:'environment'}`); si la
  /// restricción no se puede cumplir (`OverconstrainedError`) reintenta con `{video:true}`.
  Future<void> start({String? deviceId}) async {
    if (!isSupported) {
      throw CameraException(CameraErrorKind.unsupported, 'sin-getusermedia');
    }
    // Suelta el stream anterior (defensa "cámara ocupada" al cambiar de lente).
    _stopStream();

    final md = web.window.navigator.mediaDevices;
    // `video` de MediaStreamConstraints es JSAny (no-nulo); el mapa nunca es null.
    final JSAny videoConstraint = deviceId != null
        ? (<String, Object>{
            'deviceId': <String, Object>{'exact': deviceId},
          }.jsify() as JSAny)
        : (<String, Object>{
            'facingMode': <String, Object>{'ideal': 'environment'},
          }.jsify() as JSAny);

    web.MediaStream stream;
    try {
      stream = await md
          .getUserMedia(
            web.MediaStreamConstraints(video: videoConstraint, audio: false.toJS),
          )
          .toDart;
    } catch (e) {
      // OverconstrainedError ⇒ reintenta sin restricciones de lente.
      if (_errorName(e).contains('Overconstrained')) {
        try {
          stream = await md
              .getUserMedia(
                web.MediaStreamConstraints(video: true.toJS, audio: false.toJS),
              )
              .toDart;
        } catch (e2) {
          throw _mapError(e2);
        }
      } else {
        throw _mapError(e);
      }
    }

    _stream = stream;
    final video = _ensureVideo();
    video.srcObject = stream;
    try {
      await video.play().toDart;
    } catch (_) {
      // El autoplay puede rechazar en algunos navegadores; con muted+playsInline
      // el preview suele arrancar igual. No es fatal.
    }
    _registerFactoryOnce();
  }

  /// Cámaras `videoinput` disponibles (para "Cambiar cámara"). Las etiquetas solo
  /// llegan tras conceder el permiso, así que se llama después de [start].
  Future<List<CameraDevice>> listVideoInputs() async {
    try {
      final infos = await web.window.navigator.mediaDevices.enumerateDevices().toDart;
      final list = infos.toDart;
      final cams = <CameraDevice>[];
      for (final d in list) {
        if (d.kind == 'videoinput') {
          final label = d.label.isNotEmpty ? d.label : 'Cámara ${cams.length + 1}';
          cams.add(CameraDevice(deviceId: d.deviceId, label: label));
        }
      }
      return cams;
    } catch (_) {
      return const <CameraDevice>[];
    }
  }

  /// Dibuja el frame actual del `<video>` en un `<canvas>` y lo exporta a JPEG (bytes).
  Future<Uint8List> capture() async {
    final video = _video;
    if (video == null) {
      throw CameraException(CameraErrorKind.generic, 'sin-video');
    }
    final w = video.videoWidth;
    final h = video.videoHeight;
    if (w == 0 || h == 0) {
      throw CameraException(CameraErrorKind.generic, 'sin-cuadro');
    }
    final canvas = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(video, 0, 0);
    final blob = await _toBlob(canvas);
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  /// Detiene TODOS los tracks y desconecta el `<video>` (libera la cámara).
  void dispose() {
    _stopStream();
    _video?.srcObject = null;
  }

  // --- Internos ---

  web.HTMLVideoElement _ensureVideo() {
    final existing = _video;
    if (existing != null) return existing;
    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      ..playsInline = true;
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover';
    _video = video;
    return video;
  }

  void _registerFactoryOnce() {
    if (_registered) return;
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => _video!,
    );
    _registered = true;
  }

  void _stopStream() {
    final stream = _stream;
    if (stream == null) return;
    final tracks = stream.getTracks().toDart;
    for (final track in tracks) {
      track.stop();
    }
    _stream = null;
  }

  Future<web.Blob> _toBlob(web.HTMLCanvasElement canvas) {
    final completer = Completer<web.Blob>();
    canvas.toBlob(
      (web.Blob? blob) {
        if (blob == null) {
          completer.completeError(
            CameraException(CameraErrorKind.generic, 'sin-imagen'),
          );
        } else {
          completer.complete(blob);
        }
      }.toJS,
      'image/jpeg',
      0.9.toJS,
    );
    return completer.future;
  }

  CameraException _mapError(Object error) {
    final name = _errorName(error);
    if (name.contains('NotAllowed') || name.contains('Security') ||
        name.contains('PermissionDenied')) {
      return CameraException(CameraErrorKind.permission, name);
    }
    if (name.contains('NotFound') ||
        name.contains('Overconstrained') ||
        name.contains('DevicesNotFound')) {
      return CameraException(CameraErrorKind.notFound, name);
    }
    if (name.contains('NotReadable') || name.contains('TrackStart')) {
      return CameraException(CameraErrorKind.inUse, name);
    }
    return CameraException(CameraErrorKind.generic, name);
  }

  /// Extrae el `name` del error de JS (p. ej. "NotAllowedError"); si no se puede, su texto.
  String _errorName(Object error) {
    try {
      final js = error as JSObject;
      final name = js['name'];
      if (name.isDefinedAndNotNull) {
        return (name as JSString).toDart;
      }
    } catch (_) {
      // No era un objeto de JS: caemos al texto.
    }
    return error.toString();
  }
}
