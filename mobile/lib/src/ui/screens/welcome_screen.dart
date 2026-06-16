import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../copy.dart';
import '../widgets/common.dart';
import '../widgets/wordmark.dart';
import 'register_screen.dart';
import 'recover_screen.dart';

/// Pantalla de bienvenida. Punto de entrada cuando no hay sesión.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Wordmark(),
              const SizedBox(height: 8),
              Text(Copy.welcomeSubtitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const InfoNote(Copy.aboutBoundary),
              const SizedBox(height: 12),
              const InfoNote(Copy.noPiiNote),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('go_register'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegisterScreen(),
                    ),
                  ),
                  child: const Text('Crear cuenta'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('go_recover'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RecoverScreen(),
                    ),
                  ),
                  child: const Text('Ya tengo cuenta (recuperar)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
