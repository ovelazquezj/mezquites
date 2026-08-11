import 'package:geolocator/geolocator.dart';
// `hide CameraDevice`: image_picker exporta su propio `CameraDevice` (front/rear) que
// colisiona con el nuestro (camera_web_shared.dart). No usamos el de image_picker.
import 'package:image_picker/image_picker.dart' hide CameraDevice;

import 'camera_web.dart';
import 'capture_service.dart';

/// Servicio de captura WEB (CR-005 + CR-018): cámara del navegador.
///
/// CR-018 (cámara robusta): el camino principal es **`getUserMedia`** (preview en vivo +
/// captura por canvas, vía [camera_web.dart]). `getUserMedia` SÍ dispara el permiso del
/// navegador (arregla "no pidió permiso") y funciona en cualquier dispositivo con soporte
/// (ya NO se compuerta por user-agent). Para WebViews sin `getUserMedia` queda el **fallback**
/// [captureFromSystemCamera] con `image_picker` (`<input capture>` → cámara del SO).
///
/// Gate #4: ambos caminos son CÁMARA, NUNCA galería (`ImageSource.camera`, jamás `gallery`).
/// `native_exif` no corre en web: lat/lon/timestamp salen de `geolocator` y viajan en el
/// payload (el backend usa el payload, no el EXIF). La imagen se entrega por **bytes**.
class WebCaptureService {
  WebCaptureService({
    ImagePicker? picker,
    GeolocatorPlatformReader? geo,
    WebCamera? camera,
  })  : _picker = picker ?? ImagePicker(),
        _geo = geo,
        _camera = camera ?? WebCamera();

  final ImagePicker _picker;
  final GeolocatorPlatformReader? _geo;
  final WebCamera _camera;

  /// `true` si el navegador soporta el preview en vivo con `getUserMedia`.
  bool get liveCameraSupported => _camera.isSupported;

  /// viewType del HtmlElementView del preview en vivo.
  String get previewViewType => _camera.viewType;

  Future<({double lat, double lon, double? accuracy})> _currentPosition() async {
    if (_geo != null) return _geo.current();
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw CaptureException('El servicio de ubicación está desactivado.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw CaptureException('Permiso de ubicación denegado.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    return (lat: pos.latitude, lon: pos.longitude, accuracy: pos.accuracy);
  }

  /// Abre (o reabre, al cambiar de cámara) el preview en vivo y devuelve las cámaras
  /// disponibles para el botón "Cambiar cámara". Lanza [CameraException] mapeable a texto.
  Future<List<CameraDevice>> openLiveCamera({String? deviceId}) async {
    await _camera.start(deviceId: deviceId);
    return _camera.listVideoInputs();
  }

  /// Toma la foto del preview en vivo (canvas → JPEG) + ubicación real y libera la cámara.
  Future<CaptureResult> captureFromLivePreview() async {
    final bytes = await _camera.capture();
    try {
      final pos = await _currentPosition();
      return CaptureResult(
        imageBytes: bytes,
        lat: pos.lat,
        lon: pos.lon,
        gpsAccuracyM: pos.accuracy,
        capturedAt: DateTime.now(),
      );
    } finally {
      // Suelta la cámara tras capturar (defensa "cámara ocupada").
      _camera.dispose();
    }
  }

  /// Fallback para WebViews sin `getUserMedia`: cámara del SO vía `image_picker`.
  /// SOLO cámara (gate #4): NUNCA `ImageSource.gallery`.
  Future<CaptureResult> captureFromSystemCamera() async {
    final pos = await _currentPosition();
    final XFile? shot = await _picker.pickImage(source: ImageSource.camera);
    if (shot == null) {
      throw CaptureException('No se tomó ninguna foto.');
    }
    final bytes = await shot.readAsBytes();
    return CaptureResult(
      imageBytes: bytes,
      lat: pos.lat,
      lon: pos.lon,
      gpsAccuracyM: pos.accuracy,
      capturedAt: DateTime.now(),
    );
  }

  /// Compat (firma histórica): delega en el fallback de la cámara del sistema.
  Future<CaptureResult> captureFromCamera() => captureFromSystemCamera();

  /// Libera la cámara (llamar desde `dispose()` del panel).
  void releaseCamera() => _camera.dispose();
}
