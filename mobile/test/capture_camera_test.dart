import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gate #4 / Q5.A: la captura es SOLO cámara nativa; la galería está
/// DESHABILITADA. Verificación por análisis estático del código fuente: no se
/// usa `image_picker`, `ImageSource.gallery`, `FilePicker`, ni `pickImage`.
void main() {
  test('ninguna dependencia de galería en pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('image_picker'), isFalse,
        reason: 'image_picker habilitaría la galería (gate #4).',);
    expect(pubspec.contains('file_picker'), isFalse);
    // La cámara nativa SÍ debe estar.
    expect(pubspec.contains('camera:'), isTrue);
  });

  test('ningún uso de galería en el código de lib/', () {
    // Escanea código (no comentarios): los docstrings describen el gate en
    // negativo ("no image_picker / ImageSource.gallery") y no son uso real.
    final libDir = Directory('lib');
    final offenders = <String>[];
    final banned = [
      'ImageSource.gallery',
      'pickImage',
      'pickMultiImage',
      'image_picker',
      'getImageFromGallery',
    ];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final raw in entity.readAsLinesSync()) {
        final line = raw.trim();
        if (line.startsWith('//') || line.startsWith('///')) continue;
        for (final term in banned) {
          if (line.contains(term)) offenders.add('${entity.path}: $term');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'La galería debe estar deshabilitada (gate #4): $offenders',);
  });

  test('la captura inyecta EXIF lat/lon/timestamp (gate #4)', () {
    final src = File('lib/src/services/capture_service.dart').readAsStringSync();
    // El servicio escribe GPS y fecha al EXIF.
    expect(src.contains('GPSLatitude'), isTrue);
    expect(src.contains('GPSLongitude'), isTrue);
    expect(src.contains('DateTimeOriginal'), isTrue);
    expect(src.contains('takePicture'), isTrue,
        reason: 'La foto se toma con la cámara nativa.',);
  });
}
