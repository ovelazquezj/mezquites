// Prueba de integración (T1): corre en emulador/dispositivo Android.
//
// Verifica que la captura inyecta lat/lon/timestamp REALES en el EXIF del JPEG
// (gate #4). Requiere hardware/emulador con cámara y permisos. Se ejecuta con:
//   flutter test integration_test/capture_exif_test.dart -d <android_device>
//
// NOTA: este archivo requiere `integration_test` del SDK; se añade como
// dev_dependency solo cuando se vaya a ejecutar en dispositivo (ver README).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_exif/native_exif.dart';
import 'package:mezquite_app/src/services/capture_service_native.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('injectExif escribe y relee GPS/fecha en un JPEG', (tester) async {
    // Copia un JPEG de prueba al almacenamiento del dispositivo.
    final dir = Directory.systemTemp.createTempSync('mezq');
    final path = '${dir.path}/shot.jpg';
    // JPEG mínimo válido.
    File(path).writeAsBytesSync(<int>[
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00,
      0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
    ]);

    await NativeCaptureService.injectExif(
      path,
      lat: 25.6866,
      lon: -100.3161,
      when: DateTime(2026, 5, 30, 12, 0, 0),
    );

    final exif = await Exif.fromPath(path);
    final attrs = await exif.getAttributes();
    await exif.close();

    expect(attrs, isNotNull);
    expect(attrs!.containsKey('GPSLatitude'), isTrue);
    expect(attrs.containsKey('GPSLongitude'), isTrue);
    expect(attrs.containsKey('DateTimeOriginal'), isTrue);
  });
}
