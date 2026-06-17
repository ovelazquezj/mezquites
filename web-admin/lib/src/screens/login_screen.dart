import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import '../ui/copy.dart';

/// Login de la consola de administración (CR-002): **usuario + contraseña** (POST /auth/login). Los
/// usuarios los crea el administrador (no hay auto-registro). Acceso por token Bearer pegado tras
/// "Opciones avanzadas" (uso técnico). Si el rol no entra a la consola, se deniega el acceso.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithPassword() async {
    setState(() => _busy = true);
    await ref.read(sessionProvider.notifier).loginWithPassword(
          username: _userCtrl.text,
          password: _passCtrl.text,
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
                    Text('Administración — ${Copy.orgName}',
                        style: theme.textTheme.displayLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Proyecto de ciencia ciudadana del mezquite. Inicia sesión '
                      'con tu usuario y contraseña. ¿No tienes cuenta? El '
                      'administrador la crea por ti.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('login-username'),
                      controller: _userCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('login-password'),
                      controller: _passCtrl,
                      obscureText: true,
                      onSubmitted: (_) => _busy ? null : _loginWithPassword(),
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('login-submit'),
                      onPressed: _busy ? null : _loginWithPassword,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Entrar'),
                    ),
                    const SizedBox(height: 8),
                    // Acceso por token: solo para uso técnico. Oculto por defecto.
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
