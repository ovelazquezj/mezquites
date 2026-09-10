import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/confirm_delete_dialog.dart';
import '../ui/copy.dart';

/// ARCO — Cancelación de cuenta (CR-006). SOLO el `administrador`: busca una cuenta
/// (por usuario/handle) y la **elimina** con confirmación + motivo. Llama al
/// `DELETE /admin/accounts/{id}` (el backend anonimiza las observaciones, borra la
/// identidad y audita sin PII — gates #2/#7). No expone PII: solo handle, rol y
/// el conteo de observaciones que se anonimizarán.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final _searchCtrl = TextEditingController();
  bool _busy = false;
  bool _searched = false;
  List<AdminAccountSummary> _results = const [];
  DeleteAccountResult? _lastResult;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _busy = true);
    try {
      final list = await ref
          .read(apiClientProvider)
          .searchAccounts(handle: _searchCtrl.text.trim());
      if (mounted) {
        setState(() {
          _results = list;
          _searched = true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.isAuthError
                ? 'No tienes permisos para esta acción (solo administrador).'
                : 'No se pudo buscar. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndDelete(AdminAccountSummary account) async {
    // El diálogo gestiona y descarta su propio controlador; devuelve el motivo
    // (puede ser vacío) si se confirma, o null si se cancela.
    final decision = await showDialog<ConfirmDeleteDecision>(
      context: context,
      builder: (ctx) => ConfirmDeleteDialog(
        keyPrefix: 'accounts',
        description: Copy.accountsConfirmBody(
          nombre: account.displayName,
          rol: Copy.roleLabel(account.role),
          observaciones: account.observations,
        ),
      ),
    );
    if (decision == null) return; // cancelado

    final reason = decision.reason.trim();
    setState(() => _busy = true);
    try {
      final result = await ref.read(apiClientProvider).deleteAccount(
            accountId: account.id,
            reason: reason.isEmpty ? null : reason,
          );
      if (mounted) {
        setState(() {
          _lastResult = result;
          // Quita la cuenta eliminada de los resultados visibles.
          _results = _results.where((a) => a.id != account.id).toList();
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.isAuthError
                ? 'No tienes permisos para esta acción (solo administrador).'
                : 'No se pudo eliminar la cuenta. Inténtalo de nuevo.'),
          ),
        );
      }
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
        Text(Copy.navAccounts, style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(Copy.accountsIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),

        // --- Resultado de la última eliminación ---
        if (_lastResult != null) ...[
          Card(
            key: const Key('accounts-result'),
            color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: theme.colorScheme.tertiary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lastResult!.message.isEmpty
                              ? 'Cuenta eliminada.'
                              : _lastResult!.message,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Observaciones anonimizadas: '
                          '${_lastResult!.observationsAnonymized}.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // --- Buscador ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buscar la cuenta', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('accounts-search-field'),
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          labelText: Copy.accountsSearchLabel,
                        ),
                        onSubmitted: (_) => _busy ? null : _search(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      key: const Key('accounts-search'),
                      onPressed: _busy ? null : _search,
                      child: const Text(Copy.accountsSearch),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Resultados ---
        if (_searched)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resultados', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (_results.isEmpty)
                    Text(Copy.accountsEmpty,
                        style: theme.textTheme.bodyMedium)
                  else
                    for (final a in _results)
                      _AccountRow(
                        account: a,
                        // CR-040: nadie se elimina a sí mismo (se quedaría fuera
                        // a media sesión) ni elimina la cuenta principal. El
                        // backend responde 400 en ambos casos; aquí ni se ofrece.
                        esPropia: a.handle == miHandle,
                        busy: _busy,
                        onDelete: () => _confirmAndDelete(a),
                      ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Un resultado de la búsqueda. Muestra el nombre por el que se conoce a la
/// cuenta (CR-040: el nombre de acceso si es del equipo; si no, el handle) y
/// desactiva el borrado cuando el backend lo va a rechazar de todos modos.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.esPropia,
    required this.busy,
    required this.onDelete,
  });

  final AdminAccountSummary account;
  final bool esPropia;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final bloqueada = a.protected || esPropia;
    final partes = <String>[
      // El handle solo cuando NO es el título: para un usuario de consola es un
      // código interno que nadie conoce, pero sirve para identificar la fila.
      if (a.username != null && a.username!.isNotEmpty) a.handle,
      Copy.roleLabel(a.role),
      '${a.observations} observación(es)',
      if (a.hasEmail) 'con correo',
      if (esPropia) Copy.userTagSelf,
      if (a.protected) Copy.userTagProtected,
    ];
    return ListTile(
      key: Key('account-row-${a.handle}'),
      contentPadding: EdgeInsets.zero,
      title: Text(a.displayName),
      subtitle: Text(partes.join(' · ')),
      trailing: OutlinedButton.icon(
        key: Key('account-delete-${a.handle}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text(Copy.accountsDelete),
        onPressed: (busy || bloqueada) ? null : onDelete,
      ),
    );
  }
}
