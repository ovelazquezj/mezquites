import 'dart:io';

import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_exif/native_exif.dart';

/// Resultado de una captura de cámara nativa con EXIF real inyectado (gate #4).
class CaptureResult {
  const CaptureResult({
    required this.imagePath,
    required this.lat,
    required this.lon,
    required this.capturedAt,
  });

  final String imagePath;
  final double lat;
  final double lon;
  final DateTime capturedAt;
}

/// Error de captura/permiso (cámara o ubicación denegadas).
class CaptureException implements Exception {
  CaptureException(this.message);
  final String message;
  @override
  String toString() => 'CaptureException: $message';
}

/// Servicio de captura — SOLO cámara nativa (gate #4, Q5.A).
///
/// La galería del dispositivo NO se usa en ninguna parte de la app: no hay
/// `image_picker`/`ImageSource.gallery` ni importación de archivos. La única vía
/// para producir una observación es [capture], que toma la foto con la cámara
/// del dispositivo e inyecta lat/lon/timestamp REALES en el EXIF del JPEG.
class CaptureService {
  CaptureService({GeolocatorPlatformReader? geo}) : _geo = geo;

  final GeolocatorPlatformReader? _geo;

  /// Lista las cámaras del dispositivo (la UI inicializa una `CameraController`).
  Future<List<CameraDescription>> cameras() => availableCameras();

  /// Obtiene la ubicación real del dispositivo, pidiendo permiso si hace falta.
  Future<Position> _currentPosition() async {
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
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  /// Toma la foto con [controller] (cámara nativa) e inyecta el EXIF real.
  ///
  /// Devuelve [CaptureResult] con la ruta del JPEG y los datos de georreferencia
  /// y timestamp que también viajarán como las primeras 3 de las 8 etiquetas.
  Future<CaptureResult> capture(CameraController controller) async {
    final pos = await _currentPosition();
    final XFile shot = await controller.takePicture();
    final now = DateTime.now();
    await injectExif(shot.path, lat: pos.latitude, lon: pos.longitude, when: now);
    return CaptureResult(
      imagePath: shot.path,
      lat: pos.latitude,
      lon: pos.longitude,
      capturedAt: now,
    );
  }

  /// Escribe lat/lon/timestamp en el EXIF del JPEG (gate #4).
  /// Aislado para poder probarlo sin hardware de cámara.
  static Future<void> injectExif(
    String path, {
    required double lat,
    required double lon,
    required DateTime when,
  }) async {
    final exif = await Exif.fromPath(path);
    await exif.writeAttributes({
      'GPSLatitude': lat.abs(),
      'GPSLatitudeRef': lat >= 0 ? 'N' : 'S',
      'GPSLongitude': lon.abs(),
      'GPSLongitudeRef': lon >= 0 ? 'E' : 'W',
      'DateTimeOriginal': _exifDate(when),
    });
    await exif.close();
  }

  static String _exifDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}:${two(d.month)}:${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}

/// Inyección de ubicación para pruebas (evita depender del hardware GPS).
abstract class GeolocatorPlatformReader {
  Future<Position> current();
}

/// Utilidad: verifica que la ruta apunte a un archivo de imagen existente.
bool isCapturedFile(String path) => File(path).existsSync();
