import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_web_admin/src/widgets/caveat_banner.dart';

/// Escaneo del código fuente para gates de frontera (revisión estática, no UI).
/// Ignora líneas de comentario para no marcar el copy que explícitamente DICE
/// "sin PDF". Devuelve solo el código ejecutable, en minúsculas.
String _allLibCode() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  final buffer = StringBuffer();
  for (final f in files) {
    for (final line in f.readAsLinesSync()) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
      buffer.writeln(line);
    }
  }
  return buffer.toString().toLowerCase();
}

void main() {
  group('Boundary Q5.B — dashboards como pieza única (sin PDF)', () {
    test('no hay generación/exportación de PDF en el código (sin comentarios)',
        () {
      final code = _allLibCode();
      // Sin símbolos/identificadores de generación de PDF o exportación de
      // reportes. (El copy que dice "sin PDF" vive en comentarios y se ignora.)
      for (final banned in [
        'exportpdf',
        'export_pdf',
        'savepdf',
        'printdocument',
        'generatereport',
        'generate_report',
        'package:pdf',
        'package:printing',
      ]) {
        expect(code.contains(banned), isFalse,
            reason: 'Q5.B: no se generan PDFs ni reportes narrativos ($banned)');
      }
    });

    test('pubspec no declara paquetes de PDF', () {
      final pubspec =
          File('pubspec.yaml').readAsStringSync().toLowerCase();
      expect(pubspec.contains('pdf'), isFalse);
      expect(pubspec.contains('printing'), isFalse);
    });
  });

  group('Boundary Q1 (gate #1) — sin promesas fitosanitarias', () {
    test('el copy no promete control fitosanitario ni manejo', () {
      final src = _allLibCode();
      for (final banned in [
        'control fitosanitario',
        'reducción de infestación',
        'reduccion de infestacion',
        'recomendación de manejo',
        'recomendacion de manejo',
        'erradicar',
        'fumig',
      ]) {
        expect(src.contains(banned), isFalse,
            reason: 'gate #1: solo datos/observación, sin manejo ($banned)');
      }
    });
  });

  group('Caveat de origen ciudadano visible', () {
    testWidgets('CaveatBanner muestra el texto del backend', (tester) async {
      const caveat = 'Datos de origen ciudadano, sin validación por expertos.';
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CaveatBanner(caveat: caveat)),
      ));
      expect(find.byKey(const Key('caveat-text')), findsOneWidget);
      expect(find.text(caveat), findsOneWidget);
    });

    testWidgets('CaveatBanner usa placeholder marcado si el backend no lo da',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CaveatBanner(caveat: '')),
      ));
      final text = tester
          .widget<Text>(find.byKey(const Key('caveat-text')))
          .data!;
      expect(text, contains('PLACEHOLDER'));
    });

    testWidgets('SnapshotStamp muestra la etiqueta Qn', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: SnapshotStamp(quarter: 'Q2-2026'))),
      ));
      expect(find.textContaining('Q2-2026'), findsOneWidget);
    });
  });
}
