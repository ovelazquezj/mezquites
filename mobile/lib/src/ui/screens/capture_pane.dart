// Selector de plataforma del panel de captura (CR-005, gate #4 W0=a).
//
// - nativo (io): cámara nativa con preview + EXIF real (capture_pane_io.dart).
// - web: cámara del navegador (teléfono/tablet) vía image_picker (capture_pane_web.dart).
//
// El import condicional evita compilar native_exif/dart:io en el build web.
export 'capture_pane_io.dart' if (dart.library.html) 'capture_pane_web.dart';
