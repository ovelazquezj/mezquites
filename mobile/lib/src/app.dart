import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'theme/app_theme.dart';
import 'ui/copy.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/welcome_screen.dart';

/// Raíz de la app. Construye el tema desde los tokens del design system (T7) y
/// enruta a Welcome (sin sesión) o Home (con sesión seudonimizada).
class MezquiteApp extends ConsumerWidget {
  const MezquiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensAsync = ref.watch(designTokensProvider);
    final session = ref.watch(authProvider);

    return tokensAsync.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Error de tema: $e'))),
      ),
      data: (tokens) => MaterialApp(
        title: Copy.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme(tokens).build(),
        home: session == null ? const WelcomeScreen() : const HomeShell(),
      ),
    );
  }
}
