import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/session.dart';
import 'theme/app_theme.dart';
import 'theme/design_tokens.dart';
import 'ui/copy.dart';

/// Raíz de la web admin. Carga los tokens del design system (T7) y conmuta entre
/// login (sin sesión) y el shell admin (sesión `admin_consorcio`).
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key, required this.tokens});

  final DesignTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      title: 'Mezquite — Administración · ${Copy.orgName}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme(tokens).build(),
      home: session.isAuthenticated ? const HomeShell() : const LoginScreen(),
    );
  }
}
