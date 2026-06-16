import 'dart:io';

import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_exif/native_exif.dart';

import 'capture_service.dart';

/// Servicio de captura NATIVO (móvil): SOLO cámara nativa (gate #4, Q5.A).
///
/// Intacto respecto a la app móvil original: la galería del dispositivo NO se usa
/// (no hay `image_picker`/`ImageSource.gallery` aquí), toma la foto con la cámara
/// nativa e inyecta lat/lon/timestamp REALES en el EXIF del JPEG y entrega la **ruta**.
///
/// Este archivo importa `native_exif`/`dart:io` (sin soporte web): se compila SOLO
/// en la rama nativa (ver `capture_pane.dart`, import condicional).
class NativeCaptureService {
  NativeCaptureService({GeolocatorPlatformReader? geo}) : _geo = geo;

  final GeolocatorPlatformReader? _geo;

  /// Lista las cámaras del dispositivo (la UI inicializa una `CameraController`).
  Future<List<CameraDescription>> cameras() => availableCameras();

  /// Obtiene la ubicación real del dispositivo, pidiendo permiso si hace falta.
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

  /// Toma la foto con [controller] (cámara nativa) e inyecta el EXIF real.
  Future<CaptureResult> capture(CameraController controller) async {
    final pos = await _currentPosition();
    final XFile shot = await controller.takePicture();
    final now = DateTime.now();
    await injectExif(shot.path, lat: pos.lat, lon: pos.lon, when: now);
    return CaptureResult(
      imagePath: shot.path,
      lat: pos.lat,
      lon: pos.lon,
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

/// Utilidad: verifica que la ruta apunte a un archivo de imagen existente.
bool isCapturedFile(String path) => File(path).existsSync();
