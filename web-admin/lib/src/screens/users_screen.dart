import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';

/// Gestión de usuarios de backend (CR-002). SOLO el `administrador`: crea evaluador/analista/
/// administrador con contraseña temporal, dispara reset y cambia rol. Gate #2 acotado: el email
/// SOLO se ofrece para `administrador`; nunca se muestra el email de un usuario (solo "con correo").
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _role = 'evaluador';
  bool _busy = false;
  List<BackendUser> _users = const [];
  String? _lastTempPassword;
  String? _lastUsername;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final list = await ref.read(apiClientProvider).listUsers();
      if (mounted) setState(() => _users = list);
    } catch (_) {
      // Silencioso: la lista queda vacía si falla.
    }
  }

  Future<void> _create() async {
    final username = _userCtrl.text.trim();
    if (username.isEmpty) return;
    setState(() => _busy = true);
    try {
      final created = await ref.read(apiClientProvider).createUser(
            username: username,
            role: _role,
            email: _role == 'administrador' ? _emailCtrl.text.trim() : null,
          );
      setState(() {
        _lastTempPassword = created.tempPassword;
        _lastUsername = created.username;
      });
      _userCtrl.clear();
      _emailCtrl.clear();
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.statusCode == 409
                ? 'Ese nombre de usuario ya existe.'
                : 'No se pudo crear el usuario. Revisa los datos.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset(BackendUser u) async {
    try {
      final temp = await ref.read(apiClientProvider).resetUser(userId: u.id);
      setState(() {
        _lastTempPassword = temp;
        _lastUsername = u.username;
      });
    } on ApiException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo restablecer la contraseña.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Usuarios del equipo', style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          'Crea cuentas para evaluadores, analistas y administradores. No hay '
          'auto-registro: tú creas las cuentas y entregas la contraseña temporal. '
          'Solo los administradores pueden tener correo (para recuperar su acceso).',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        // --- Alta ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Crear usuario', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 240,
                      child: TextField(
                        key: const Key('user-username'),
                        controller: _userCtrl,
                        decoration: const InputDecoration(labelText: 'Usuario'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        key: const Key('user-role'),
                        value: _role,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Rol'),
                        items: [
                          for (final r in const [
                            'evaluador',
                            'analista',
                            'administrador'
                          ])
                            DropdownMenuItem(
                                value: r, child: Text(Copy.roleLabel(r))),
                        ],
                        onChanged: (v) => setState(() => _role = v ?? 'evaluador'),
                      ),
                    ),
                    // Email SOLO para administrador (gate #2 acotado).
                    if (_role == 'administrador')
                      SizedBox(
                        width: 260,
                        child: TextField(
                          key: const Key('user-email'),
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Correo (solo administrador)',
                            hintText: 'para recuperar la contraseña',
                          ),
                        ),
                      ),
                    FilledButton(
                      key: const Key('user-create'),
                      onPressed: _busy ? null : _create,
                      child: const Text('Crear usuario'),
                    ),
                  ],
                ),
                if (_lastTempPassword != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    key: const Key('user-temp-password'),
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contraseña temporal de "${_lastUsername ?? ''}"',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            _lastTempPassword!,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Compártela una sola vez; el usuario la cambia al entrar.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // --- Lista ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Usuarios existentes',
                        style: theme.textTheme.titleLarge),
                    IconButton(
                      key: const Key('users-refresh'),
                      tooltip: 'Actualizar',
                      icon: const Icon(Icons.refresh),
                      onPressed: _reload,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_users.isEmpty)
                  Text('Aún no hay usuarios de equipo.',
                      style: theme.textTheme.bodyMedium)
                else
                  for (final u in _users)
                    ListTile(
                      key: Key('user-row-${u.username}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(u.username ?? u.handle),
                      subtitle: Text(
                        '${Copy.roleLabel(u.role)}${u.hasEmail ? ' · con correo' : ''}'
                        '${u.mustChangePassword ? ' · contraseña temporal' : ''}',
                      ),
                      trailing: OutlinedButton(
                        key: Key('user-reset-${u.username}'),
                        onPressed: () => _reset(u),
                        child: const Text('Restablecer contraseña'),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
