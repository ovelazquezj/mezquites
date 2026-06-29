import 'dart:typed_data';

import 'camera_web_shared.dart';

/// Stub no-web de la cámara web robusta (CR-018).
///
/// Fuera del navegador no hay `getUserMedia`: [isSupported] es `false` y todo lanza
/// "no soportado". En la práctica la rama nativa ni compila este archivo (el panel web
/// solo existe en el build web); el stub está para mantener válido el import condicional.
class WebCamera {
  /// Sin soporte fuera del navegador.
  bool get isSupported => false;

  /// Identificador del HtmlElementView (no se usa fuera de web).
  String get viewType => 'mezquite-camera-stub';

  Future<void> start({String? deviceId}) async =>
      throw CameraException(CameraErrorKind.unsupported, 'no-web');

  Future<List<CameraDevice>> listVideoInputs() async => const <CameraDevice>[];

  Future<Uint8List> capture() async =>
      throw CameraException(CameraErrorKind.unsupported, 'no-web');

  void dispose() {}
}
