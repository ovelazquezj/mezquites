import 'dart:typed_data';

/// Resultado de una captura de cámara (gate #4). Portable entre plataformas (CR-005):
/// - **Móvil nativo**: foto con cámara nativa, EXIF real (lat/lon/timestamp), por **ruta** ([imagePath]).
/// - **Web (teléfono/tablet)**: la cámara del navegador entrega **bytes** ([imageBytes]); `native_exif`
///   no corre en web, así que lat/lon/timestamp viajan en el payload (el backend usa el payload).
class CaptureResult {
  const CaptureResult({
    this.imagePath,
    this.imageBytes,
    required this.lat,
    required this.lon,
    required this.capturedAt,
    this.gpsAccuracyM,
  }) : assert(imagePath != null || imageBytes != null,
            'Una captura debe tener ruta (móvil) o bytes (web).',);

  /// Ruta local del JPEG capturado con cámara nativa (móvil). `null` en web.
  final String? imagePath;

  /// Bytes del JPEG capturado con la cámara del navegador (web). `null` en móvil.
  final Uint8List? imageBytes;

  final double lat;
  final double lon;
  final DateTime capturedAt;

  /// CR-036: precisión del fix en metros, tal como la reporta el dispositivo. Nullable porque no
  /// todos los navegadores la entregan. Al retirar los selectores de estado/municipio ya no queda
  /// ningún humano que pueda notar un fix malo cerca de un límite estatal: este es el único dato
  /// que permite juzgar después si la ubicación derivada era confiable.
  final double? gpsAccuracyM;
}

/// Error de captura/permiso (cámara o ubicación denegadas) o plataforma no apta.
class CaptureException implements Exception {
  CaptureException(this.message);
  final String message;
  @override
  String toString() => 'CaptureException: $message';
}

/// Inyección de ubicación para pruebas (evita depender del hardware GPS).
abstract class GeolocatorPlatformReader {
  Future<({double lat, double lon, double? accuracy})> current();
}
