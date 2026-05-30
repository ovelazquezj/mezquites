import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/theme/app_theme.dart';

import 'helpers.dart';

/// T7: el tema se genera EXCLUSIVAMENTE desde design-tokens.json; ningún widget
/// declara colores/medidas literales.
void main() {
  test('el tema deriva primary del token Rotary royal blue', () {
    final tokens = loadTokensFromDisk();
    final theme = AppTheme(tokens).build();
    // semantic.primary -> brand.rotary_royal_blue = #17458F
    expect(theme.colorScheme.primary, const Color(0xFF17458F));
    // semantic.secondary -> brand.rotary_gold = #F7A81B
    expect(theme.colorScheme.secondary, const Color(0xFFF7A81B));
    // semantic.accent -> eco.green_500 = #4C9A5A
    expect(theme.colorScheme.tertiary, const Color(0xFF4C9A5A));
  });

  test('los tokens resuelven referencias semánticas y escalas', () {
    final tokens = loadTokensFromDisk();
    expect(tokens.color('primary'), 0xFF17458F);
    expect(tokens.radius('md'), 12);
    expect(tokens.spacing('lg'), 24);
    final body = tokens.typeToken('body');
    expect(body.size, 16);
    expect(body.weight, 400);
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
