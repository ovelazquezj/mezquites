import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_web_admin/src/theme/app_theme.dart';
import 'package:mezquite_web_admin/src/theme/design_tokens.dart';

void main() {
  group('T7 — tema generado SOLO desde design-tokens.json', () {
    late DesignTokens tokens;

    setUp(() {
      final raw =
          File('assets/design-tokens.json').readAsStringSync();
      tokens = DesignTokens.fromJsonString(raw);
    });

    test('el asset de tokens existe y es el del design system compartido', () {
      expect(File('assets/design-tokens.json').existsSync(), isTrue);
      // CR-003: paleta oficial Mezquite. primary -> navy (#1F3A6E) vía ref.
      expect(tokens.color('primary'), 0xFF1F3A6E);
      expect(tokens.color('accent'), 0xFF5C9A3A); // verde Mezquite
    });

    test('AppTheme.build() usa los colores de los tokens (sin hex literal)', () {
      final theme = AppTheme(tokens).build();
      expect(theme.colorScheme.primary, Color(tokens.color('primary')));
      expect(theme.colorScheme.secondary, Color(tokens.color('secondary')));
      expect(theme.colorScheme.tertiary, Color(tokens.color('accent')));
    });

    test(
        'el código de tema/widgets no introduce colores hex literales fuera del sistema',
        () {
      // Escanea lib/ buscando literales Color(0x...) o Color.fromARGB que NO sean
      // el error rojo de Material (único permitido, igual que en el móvil).
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final hexLiteral = RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)');
      final offenders = <String>[];
      for (final f in dartFiles) {
        for (final match in hexLiteral.allMatches(f.readAsStringSync())) {
          final lit = match.group(0)!;
          // 0xFFB3261E = error de Material, permitido (igual que el tema móvil).
          if (lit.toUpperCase().contains('FFB3261E')) continue;
          offenders.add('${f.path}: $lit');
        }
      }
      expect(offenders, isEmpty,
          reason: 'Colores deben venir de design-tokens.json: $offenders');
    });
  });
}
