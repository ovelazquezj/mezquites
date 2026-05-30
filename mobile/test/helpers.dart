import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezquite_app/src/theme/app_theme.dart';
import 'package:mezquite_app/src/theme/design_tokens.dart';

/// Carga los tokens reales desde el asset del repo (la misma fuente que en
/// runtime), sin depender del bundler de assets en pruebas.
DesignTokens loadTokensFromDisk() {
  final raw = File('assets/design-tokens.json').readAsStringSync();
  return DesignTokens.fromJsonString(raw);
}

/// Envuelve un widget en un MaterialApp con el tema generado desde los tokens
/// (T7) y un ProviderScope con los overrides indicados.
Widget wrap(
  Widget child, {
  List<Override> overrides = const [],
  DesignTokens? tokens,
}) {
  final t = tokens ?? loadTokensFromDisk();
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme(t).build(),
      home: child,
    ),
  );
}
