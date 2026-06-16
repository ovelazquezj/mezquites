import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Carga y resuelve `design-tokens.json` (fuente ÚNICA de estilo, T7).
///
/// El JSON vive en `assets/design-tokens.json`, copiado desde
/// `docs/design-system/design-tokens.json`. Esta clase resuelve las referencias
/// semánticas (p.ej. `color.semantic.primary -> color.brand.rotary_royal_blue`)
/// y expone getters tipados. Ningún widget debe declarar colores/medidas
/// literales: deben pedirlos a [DesignTokens].
class DesignTokens {
  DesignTokens._(this._root);

  final Map<String, dynamic> _root;

  static const String assetPath = 'assets/design-tokens.json';

  /// Carga los tokens desde el asset empaquetado.
  static Future<DesignTokens> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return DesignTokens.fromJsonString(raw);
  }

  /// Construye desde una cadena JSON (útil en pruebas).
  factory DesignTokens.fromJsonString(String raw) {
    final decoded = json.decode(raw) as Map<String, dynamic>;
    return DesignTokens._(decoded);
  }

  Map<String, dynamic> _section(String key) =>
      (_root[key] as Map).cast<String, dynamic>();

  /// Navega un path con punto (`color.semantic.primary`).
  dynamic _at(String path) {
    dynamic node = _root;
    for (final part in path.split('.')) {
      if (node is Map && node.containsKey(part)) {
        node = node[part];
      } else {
        throw StateError('Token no encontrado: $path');
      }
    }
    return node;
  }

  /// Resuelve un nodo de color: sigue `ref` hasta encontrar `value` (#RRGGBB).
  int color(String semanticOrPath) {
    final fullPath = semanticOrPath.contains('.')
        ? semanticOrPath
        : 'color.semantic.$semanticOrPath';
    return _resolveColor(fullPath);
  }

  int _resolveColor(String path) {
    final node = _at(path);
    if (node is Map) {
      final map = node.cast<String, dynamic>();
      if (map.containsKey('ref')) {
        return _resolveColor(map['ref'] as String);
      }
      if (map.containsKey('value')) {
        return _hexToArgb(map['value'] as String);
      }
    }
    throw StateError('Nodo de color inválido en $path');
  }

  static int _hexToArgb(String hex) {
    var h = hex.replaceFirst('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return int.parse(h, radix: 16);
  }

  // --- Tipografía ---
  String get fontFamilyBase {
    final value = (_section('typography')['font_family_base']
        as Map)['value'] as String;
    // El primer token de la lista CSS = familia primaria.
    return value.split(',').first.trim();
  }

  /// Familia serif del wordmark "Mezquite" (CR-003). Es un nombre de familia de
  /// Google Fonts (p. ej. "Fraunces"), servido vía `google_fonts`. SOLO se aplica
  /// al wordmark, nunca al texto base (que sigue en [fontFamilyBase]).
  String get fontFamilyWordmark {
    final typo = _section('typography');
    final node = typo['font_family_wordmark'];
    if (node is Map && node['value'] is String) {
      return (node['value'] as String).split(',').first.trim();
    }
    // Salvaguarda: si no hay token, no cambiamos la familia base.
    return fontFamilyBase;
  }

  TypeToken typeToken(String name) {
    final scale = (_section('typography')['scale'] as Map).cast<String, dynamic>();
    final t = (scale[name] as Map).cast<String, dynamic>();
    return TypeToken(
      size: (t['size'] as num).toDouble(),
      weight: (t['weight'] as num).toInt(),
      line: (t['line'] as num).toDouble(),
    );
  }

  // --- Radios / espaciado / elevación ---
  double radius(String name) =>
      ((_section('radius')[name]) as num).toDouble();

  double spacing(String name) =>
      ((_section('spacing')[name]) as num).toDouble();

  double elevation(String name) =>
      ((_section('elevation')[name]) as num).toDouble();
}

/// Un escalón tipográfico del design system.
class TypeToken {
  const TypeToken({
    required this.size,
    required this.weight,
    required this.line,
  });

  final double size;
  final int weight;
  final double line;
}
