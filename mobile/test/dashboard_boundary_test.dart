import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Q5.B: la app NO genera PDFs (solo visualiza). CR-025: las vistas públicas
/// del mapa ya no prometen obfuscación de la ubicación. Gate #1: ningún copy
/// promete control fitosanitario / reducción de infestación / recomendaciones
/// de manejo.
void main() {
  test('la app no genera PDFs (Q5.B)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final pkg in ['pdf:', 'printing:', 'flutter_pdfview']) {
      expect(pubspec.contains(pkg), isFalse,
          reason: 'La app no debe generar/exportar PDFs (Q5.B).',);
    }
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final src = entity.readAsStringSync().toLowerCase();
        if (src.contains('generatepdf') ||
            src.contains('exportpdf') ||
            src.contains('savepdf')) {
          offenders.add(entity.path);
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('CR-025: el copy del mapa ya no promete obfuscación pública', () {
    final copy = File('lib/src/ui/copy.dart').readAsStringSync();
    // Ya NO se promete celda aproximada ni radio de obfuscación en el mapa.
    expect(copy.contains('~300 m'), isFalse);
    expect(copy.contains('~1 km'), isFalse);
    // El disclaimer del mapa sigue presente y mantiene el marco de dato
    // ciudadano sin validación experta (gate #1).
    expect(copy.contains('mapDisclaimer'), isTrue);
    expect(copy.contains('sin validación'), isTrue);
  });

  test('gate #1: ningún copy promete control fitosanitario o manejo', () {
    // Escanea SOLO cadenas de UI, ignorando comentarios (donde el gate aparece
    // en negativo, p.ej. "NADA promete control fitosanitario").
    final copy = File('lib/src/ui/copy.dart')
        .readAsLinesSync()
        .where((l) {
          final t = l.trim();
          return !t.startsWith('//') && !t.startsWith('///');
        })
        .join('\n')
        .toLowerCase();
    final banned = [
      'control fitosanitario',
      'erradicar',
      'eliminar la plaga',
      'reducir la infestación',
      'reducir la infestacion',
      'aplicar herbicida',
      'tratamiento químico',
      'tratamiento quimico',
      'poda recomendada',
      'recomendamos aplicar',
    ];
    final offenders = banned.where(copy.contains).toList();
    expect(offenders, isEmpty,
        reason: 'Frontera Q1 (gate #1): copy prohibido: $offenders',);
  });
}
