import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gate #4 / Q5.A: la captura es SOLO cámara; la **galería está DESHABILITADA**.
///
/// CR-005 (W0=a): la web para teléfono/tablet captura con la cámara del navegador
/// vía `image_picker` usando SIEMPRE `ImageSource.camera` (NUNCA `ImageSource.gallery`).
/// Por eso `image_picker`/`pickImage` ya NO están prohibidos; lo prohibido es la
/// **galería** (`ImageSource.gallery`, `pickMultiImage`, selector de archivos).
void main() {
  test('sin dependencia de selector de archivos/galería en pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // file_picker abriría el explorador de archivos (≈ galería): prohibido.
    expect(pubspec.contains('file_picker'), isFalse);
    // La cámara nativa SÍ debe estar (móvil).
    expect(pubspec.contains('camera:'), isTrue);
  });

  test('ningún uso de GALERÍA en el código de lib/ (gate #4)', () {
    // Escanea código (no comentarios). Prohibido SOLO lo de galería/archivos;
    // `image_picker`/`pickImage` con ImageSource.camera SÍ se permiten (CR-005).
    final libDir = Directory('lib');
    final offenders = <String>[];
    final banned = [
      'ImageSource.gallery',
      'pickMultiImage',
      'getImageFromGallery',
      'file_picker',
      'FilePicker',
    ];
    var usesPickImage = false;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final raw in entity.readAsLinesSync()) {
        final line = raw.trim();
        if (line.startsWith('//') || line.startsWith('///')) continue;
        if (line.contains('pickImage')) usesPickImage = true;
        for (final term in banned) {
          if (line.contains(term)) offenders.add('${entity.path}: $term');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'La galería debe estar deshabilitada (gate #4): $offenders',);
    // Si se usa pickImage (web), debe ser con ImageSource.camera (nunca gallery).
    if (usesPickImage) {
      final web = File('lib/src/services/capture_service_web.dart')
          .readAsStringSync();
      expect(web.contains('ImageSource.camera'), isTrue,
          reason: 'pickImage debe usar ImageSource.camera (gate #4).',);
    }
  });

  test('la captura nativa inyecta EXIF lat/lon/timestamp (gate #4)', () {
    final src =
        File('lib/src/services/capture_service_native.dart').readAsStringSync();
    // El servicio nativo escribe GPS y fecha al EXIF y usa la cámara nativa.
    expect(src.contains('GPSLatitude'), isTrue);
    expect(src.contains('GPSLongitude'), isTrue);
    expect(src.contains('DateTimeOriginal'), isTrue);
    expect(src.contains('takePicture'), isTrue,
        reason: 'La foto (móvil) se toma con la cámara nativa.',);
  });
}
