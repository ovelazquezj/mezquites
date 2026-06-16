import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'capture_service.dart';
import 'web_platform.dart';

/// Servicio de captura WEB (CR-005): cámara del navegador vía `image_picker`.
///
/// Gate #4 (W0, opción a): la web es para **teléfono/tablet**. La captura usa
/// SIEMPRE `ImageSource.camera` (NUNCA `ImageSource.gallery`): en navegador móvil
/// abre la cámara real. En **escritorio** `ImageSource.camera` degradaría a un
/// selector de archivos (≈ galería), así que [cameraAvailable] es `false` y la UI
/// **bloquea/advierte** la captura (no es objetivo y la galería no se permite).
///
/// `native_exif` no corre en web: lat/lon/timestamp se obtienen de `geolocator`
/// (geolocalización del navegador) y viajan en el payload (el backend usa el
/// payload, no el EXIF). La imagen se entrega por **bytes** (`readAsBytes`).
class WebCaptureService {
  WebCaptureService({ImagePicker? picker, GeolocatorPlatformReader? geo})
      : _picker = picker ?? ImagePicker(),
        _geo = geo;

  final ImagePicker _picker;
  final GeolocatorPlatformReader? _geo;

  /// En web, la captura por cámara solo se ofrece en teléfono/tablet (gate #4).
  bool get cameraAvailable => isMobileWebBrowser();

  String get unavailableReason =>
      'Esta página es para teléfono o tablet. Ábrela en tu celular para tomar la foto con la cámara.';

  Future<({double lat, double lon})> _currentPosition() async {
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
    return (lat: pos.latitude, lon: pos.longitude);
  }

  /// Toma la foto con la cámara del navegador y devuelve bytes + ubicación real.
  Future<CaptureResult> captureFromCamera() async {
    if (!cameraAvailable) {
      throw CaptureException(unavailableReason);
    }
    final pos = await _currentPosition();
    // SOLO cámara (gate #4): nunca ImageSource.gallery.
    final XFile? shot = await _picker.pickImage(source: ImageSource.camera);
    if (shot == null) {
      throw CaptureException('No se tomó ninguna foto.');
    }
    final bytes = await shot.readAsBytes();
    return CaptureResult(
      imageBytes: bytes,
      lat: pos.lat,
      lon: pos.lon,
      capturedAt: DateTime.now(),
    );
  }
}
