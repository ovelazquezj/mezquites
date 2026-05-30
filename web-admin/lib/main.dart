import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/theme/design_tokens.dart';

/// Punto de entrada de la web admin (Flutter Web).
///
/// Carga el design system (`assets/design-tokens.json`, copiado de
/// `docs/design-system/`) antes de montar la app, para que el tema se genere
/// EXCLUSIVAMENTE desde tokens (T7). La base de la API es conmutable por
/// `--dart-define=API_BASE_URL=...` (gate #6).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tokens = await DesignTokens.load();
  runApp(ProviderScope(child: AdminApp(tokens: tokens)));
}
