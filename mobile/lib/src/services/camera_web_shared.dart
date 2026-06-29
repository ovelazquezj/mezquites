/// Tipos compartidos de la cámara web robusta (CR-018).
///
/// Viven aparte (sin dependencias de navegador) para que tanto la
/// implementación web (`camera_web_impl.dart`) como el stub no-web
/// (`camera_web_stub.dart`) compartan una sola definición. El despachador
/// `camera_web.dart` los reexporta.
library;

/// Clase de error de la cámara, para mapear a un texto llano (sin códigos internos).
enum CameraErrorKind {
  /// El usuario no dio permiso (NotAllowedError/SecurityError).
  permission,

  /// No hay cámara o la restricción no se pudo cumplir (NotFoundError/OverconstrainedError).
  notFound,

  /// La cámara está ocupada por otra app (NotReadableError/TrackStartError).
  inUse,

  /// El navegador no ofrece `getUserMedia` (contexto inseguro o WebView viejo).
  unsupported,

  /// Cualquier otro fallo.
  generic,
}

/// Falla al abrir/usar la cámara del navegador. [detail] es el dato técnico crudo
/// (p. ej. el `name` del error de JS) para el reporte de problemas; NUNCA es PII.
class CameraException implements Exception {
  CameraException(this.kind, this.detail);

  final CameraErrorKind kind;
  final String detail;

  @override
  String toString() => 'CameraException(${kind.name}): $detail';
}

/// Una entrada de cámara (`videoinput`) para el botón "Cambiar cámara".
class CameraDevice {
  const CameraDevice({required this.deviceId, required this.label});

  final String deviceId;
  final String label;
}
