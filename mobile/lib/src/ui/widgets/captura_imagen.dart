// Selector de plataforma para pintar la foto recién capturada (CR-037).
//
// La captura llega por **bytes** (web: la cámara del navegador exporta el canvas) o por
// **ruta** (móvil nativo: el JPEG con EXIF que dejó la cámara). `Image.file` necesita
// `dart:io`, que no existe en web, así que la rama nativa se aísla por import condicional
// igual que en `capture_pane.dart` y `capture_service.dart`.
export 'captura_imagen_io.dart' if (dart.library.html) 'captura_imagen_web.dart';
