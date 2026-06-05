import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';

/// Login admin **sin PII** (gate #2): handle + código de respaldo (POST
/// /auth/recover) o token Bearer pegado. NO hay campos de email/contraseña/
/// nombre. Si el rol del token no es `admin_consorcio`, se deniega el acceso.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _handleCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _handleCtrl.dispose();
    _codeCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithCode() async {
    setState(() => _busy = true);
    await ref.read(sessionProvider.notifier).loginWithBackupCode(
          handle: _handleCtrl.text,
          backupCode: _codeCtrl.text,
        );
    if (mounted) setState(() => _busy = false);
  }

  void _loginWithToken() {
    ref.read(sessionProvider.notifier).loginWithToken(_tokenCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Administración del consorcio',
                        style: theme.textTheme.displayLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Proyecto de ciencia ciudadana del mezquite. '
                      'Acceso sin datos personales: tu usuario y tu código de '
                      'respaldo.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('login-handle'),
                      controller: _handleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        hintText: 'p.ej. obs-7HQ4K2',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('login-backup-code'),
                      controller: _codeCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Código de respaldo',
                        hintText: 'MZQ-XXXX-XXXX',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('login-submit'),
                      onPressed: _busy ? null : _loginWithCode,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 8),
                    // Acceso por token: solo para uso técnico. Oculto por
                    // defecto para no confundir al usuario no experto.
                    Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: const Key('login-advanced'),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                        title: Text('Opciones avanzadas',
                            style: theme.textTheme.bodyMedium),
                        children: [
                          TextField(
                            key: const Key('login-token'),
                            controller: _tokenCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Pegar token de acceso',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            key: const Key('login-token-submit'),
                            onPressed: _loginWithToken,
                            child: const Text('Entrar con token'),
                          ),
                        ],
                      ),
                    ),
                    if (session.error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        session.error!,
                        key: const Key('login-error'),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
