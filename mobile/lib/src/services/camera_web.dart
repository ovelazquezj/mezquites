/// Cámara web robusta (CR-018): preview en vivo con `getUserMedia` + captura por canvas.
///
/// Import condicional al estilo de `pwa_install.dart`: en web usa la implementación con
/// `dart:js_interop` + `package:web` + `dart:ui_web`; fuera de web (móvil nativo / `flutter test`)
/// usa el stub, que reporta "no soportado" (la rama nativa no compila este archivo de todos modos).
library;

export 'camera_web_shared.dart';
export 'camera_web_stub.dart'
    if (dart.library.js_interop) 'camera_web_impl.dart';
