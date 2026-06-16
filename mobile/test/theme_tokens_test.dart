import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/theme/app_theme.dart';

import 'helpers.dart';

/// T7: el tema se genera EXCLUSIVAMENTE desde design-tokens.json; ningún widget
/// declara colores/medidas literales.
void main() {
  test('el tema deriva primary de la paleta oficial Mezquite (navy)', () {
    final tokens = loadTokensFromDisk();
    final theme = AppTheme(tokens).build();
    // semantic.primary -> brand.mezquite_navy = #1F3A6E
    expect(theme.colorScheme.primary, const Color(0xFF1F3A6E));
    // semantic.secondary -> brand.mezquite_gold = #E0A21A
    expect(theme.colorScheme.secondary, const Color(0xFFE0A21A));
    // semantic.accent -> brand.mezquite_green = #5C9A3A
    expect(theme.colorScheme.tertiary, const Color(0xFF5C9A3A));
  });

  test('los tokens resuelven referencias semánticas y escalas', () {
    final tokens = loadTokensFromDisk();
    expect(tokens.color('primary'), 0xFF1F3A6E);
    expect(tokens.color('blue'), 0xFF2E6FB7); // CR-003: azul Mezquite
    expect(tokens.radius('md'), 12);
    expect(tokens.spacing('lg'), 24);
    final body = tokens.typeToken('body');
    expect(body.size, 16);
    expect(body.weight, 400);
    // Wordmark serif (CR-003): familia de Google Fonts, distinta de la sans base.
    expect(tokens.fontFamilyWordmark, 'Fraunces');
    expect(tokens.fontFamilyWordmark, isNot(tokens.fontFamilyBase));
  });

  test('el asset de tokens del móvil está sincronizado con docs/', () {
    final mobile = File('assets/design-tokens.json').readAsStringSync();
    final docs = File('../docs/design-system/design-tokens.json')
        .readAsStringSync();
    expect(mobile, docs,
        reason: 'assets/design-tokens.json debe ser copia EXACTA de la fuente.',);
  });

  test('ningún color literal hex en widgets de UI (salvo el tema)', () {
    // Permitimos hex SOLO en app_theme.dart (error semántico Material) y en
    // design_tokens.dart (parser). Ningún otro archivo de lib/ debe llevar hex.
    final hex = RegExp(r'0x[Ff][Ff][0-9A-Fa-f]{6}');
    final colorCtor = RegExp(r'Color\(0x');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      if (name == 'app_theme.dart' || name == 'design_tokens.dart') continue;
      final src = entity.readAsStringSync();
      if (hex.hasMatch(src) || colorCtor.hasMatch(src)) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Colores literales fuera del tema (T7): $offenders',);
  });
}
