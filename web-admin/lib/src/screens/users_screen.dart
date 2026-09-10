import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/confirm_delete_dialog.dart';
import '../ui/copy.dart';

/// Roles que el administrador puede asignar a una cuenta de consola.
const _rolesAsignables = <String>['evaluador', 'analista', 'administrador'];

/// Gestión de usuarios de backend (CR-002). SOLO el `administrador`: crea evaluador/analista/
/// administrador con contraseña temporal, dispara reset, **cambia rol y elimina** (CR-040).
/// Gate #2 acotado: el email SOLO se ofrece para `administrador`; nunca se muestra el email de
/// un usuario (solo "con correo").
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

  void _aviso(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// Traduce el fallo del backend a un texto llano. El **400** es la respuesta a
  /// tocar la propia cuenta o la principal (CR-040); no es un error del sistema,
  /// así que se explica sin dramatismo.
  String _mensajeDeError(ApiException e, String respaldo) {
    if (e.statusCode == 400) return Copy.userActionBlocked;
    if (e.isAuthError) return Copy.userActionForbidden;
    return respaldo;
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
      _aviso(e.statusCode == 409
          ? 'Ese nombre de usuario ya existe.'
          : 'No se pudo crear el usuario. Revisa los datos.');
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
      _aviso('No se pudo restablecer la contraseña.');
    }
  }

  /// CR-040: cambia el rol con confirmación. Si la persona deja de ser
  /// administrador, el backend le borra el correo de recuperación (solo el
  /// `administrador` puede tenerlo, gate #2), y eso hay que advertirlo antes.
  Future<void> _cambiarRol(BackendUser u, String nuevoRol) async {
    if (nuevoRol == u.role) return;
    final pierdeCorreo =
        u.role == 'administrador' && nuevoRol != 'administrador' && u.hasEmail;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('user-role-confirm-dialog'),
        title: const Text(Copy.userRoleConfirmTitle),
        content: Text(
          Copy.userRoleConfirmBody(
            nombre: u.username ?? u.handle,
            rolActual: Copy.roleLabel(u.role),
            rolNuevo: Copy.roleLabel(nuevoRol),
            pierdeCorreo: pierdeCorreo,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('user-role-confirm-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(Copy.userRoleConfirmCancel),
          ),
          FilledButton(
            key: const Key('user-role-confirm-ok'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(Copy.userRoleConfirmOk),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .patchUserRole(userId: u.id, role: nuevoRol);
      await _reload();
      _aviso(Copy.userRoleDone);
    } on ApiException catch (e) {
      _aviso(_mensajeDeError(e, Copy.userRoleFailed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// CR-040: elimina la cuenta del equipo. Es el MISMO endpoint que la
  /// cancelación ARCO (`DELETE /admin/accounts/{id}`), así que pide el mismo
  /// motivo para la bitácora de auditoría (gate #7).
  Future<void> _eliminar(BackendUser u) async {
    final decision = await showDialog<ConfirmDeleteDecision>(
      context: context,
      builder: (ctx) => ConfirmDeleteDialog(
        keyPrefix: 'user-delete',
        description: Copy.userDeleteConfirmBody(u.username ?? u.handle),
      ),
    );
    if (decision == null) return; // cancelado

    final motivo = decision.reason.trim();
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).deleteAccount(
            accountId: u.id,
            reason: motivo.isEmpty ? null : motivo,
          );
      await _reload();
      _aviso(Copy.userDeleteDone);
    } on ApiException catch (e) {
      _aviso(_mensajeDeError(e, Copy.userDeleteFailed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final miHandle = ref.watch(sessionProvider).session?.handle;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Usuarios del equipo', style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          'Crea cuentas para evaluadores, analistas y administradores. No hay '
          'auto-registro: tú creas las cuentas y entregas la contraseña temporal. '
          'Solo los administradores pueden tener correo (para recuperar su acceso). '
          'Desde la lista puedes cambiarles el rol o eliminarlas.',
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
                          for (final r in _rolesAsignables)
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
                    _UserRow(
                      user: u,
                      // CR-040: nadie se degrada ni se borra a sí mismo (se
                      // quedaría fuera a media sesión), ni toca la cuenta
                      // principal. El backend responde 400 en ambos casos;
                      // aquí ni siquiera se ofrece.
                      esPropia: u.handle == miHandle,
                      busy: _busy,
                      onReset: () => _reset(u),
                      onRoleChanged: (r) => _cambiarRol(u, r),
                      onDelete: () => _eliminar(u),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Un renglón de la lista de usuarios: nombre, marcas de estado y las tres
/// acciones (rol, contraseña, eliminar). Va en un [Wrap] para que en pantallas
/// angostas las acciones bajen de línea en vez de desbordarse.
class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.esPropia,
    required this.busy,
    required this.onReset,
    required this.onRoleChanged,
    required this.onDelete,
  });

  final BackendUser user;
  final bool esPropia;
  final bool busy;
  final VoidCallback onReset;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = user;
    final bloqueada = u.protected || esPropia;
    final habilitado = !busy && !bloqueada;

    // Si el backend devolviera un rol fuera del catálogo, se muestra igual: el
    // Dropdown reventaría con un `value` que no está entre sus opciones.
    final roles = _rolesAsignables.contains(u.role)
        ? _rolesAsignables
        : <String>[u.role, ..._rolesAsignables];

    final marcas = <String>[
      if (u.hasEmail) 'con correo',
      if (u.mustChangePassword) 'contraseña temporal',
      if (esPropia) Copy.userTagSelf,
      if (u.protected) Copy.userTagProtected,
    ];

    return Padding(
      key: Key('user-row-${u.username}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(u.username ?? u.handle,
                    style: theme.textTheme.titleMedium),
                if (marcas.isNotEmpty)
                  Text(marcas.join(' · '), style: theme.textTheme.bodySmall),
                if (bloqueada)
                  Text(
                    u.protected
                        ? Copy.userProtectedLocked
                        : Copy.userSelfLocked,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 220,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: Copy.userChangeRoleLabel,
                isDense: true,
                enabled: habilitado,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: Key('user-role-${u.username}'),
                  value: u.role,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    for (final r in roles)
                      DropdownMenuItem(
                          value: r, child: Text(Copy.roleLabel(r))),
                  ],
                  onChanged: habilitado
                      ? (v) {
                          if (v != null) onRoleChanged(v);
                        }
                      : null,
                ),
              ),
            ),
          ),
          OutlinedButton(
            key: Key('user-reset-${u.username}'),
            onPressed: busy ? null : onReset,
            child: const Text('Restablecer contraseña'),
          ),
          OutlinedButton.icon(
            key: Key('user-delete-${u.username}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text(Copy.userDelete),
            onPressed: habilitado ? onDelete : null,
          ),
        ],
      ),
    );
  }
}
