import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Q5.B: la app NO genera PDFs (solo dashboards). Gate #5: las vistas públicas
/// muestran la advertencia de obfuscación a ~1 km. Gate #1: ningún copy promete
/// control fitosanitario / reducción de infestación / recomendaciones de manejo.
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

  test('el dashboard advierte la obfuscación a ~1 km (gate #5)', () {
    final src =
        File('lib/src/ui/screens/dashboard_screen.dart').readAsStringSync();
    expect(src.contains('obfuscationNote'), isTrue);
    final copy = File('lib/src/ui/copy.dart').readAsStringSync();
    expect(copy.contains('1 km'), isTrue);
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
