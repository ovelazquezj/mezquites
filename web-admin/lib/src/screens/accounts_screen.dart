import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
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
    final decision = await showDialog<_DeleteDecision>(
      context: context,
      builder: (ctx) => _DeleteAccountDialog(account: account),
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
                      ListTile(
                        key: Key('account-row-${a.handle}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(a.handle),
                        subtitle: Text(
                          '${a.role} · ${a.observations} observación(es)'
                          '${a.hasEmail ? ' · con correo' : ''}',
                        ),
                        trailing: OutlinedButton.icon(
                          key: Key('account-delete-${a.handle}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text(Copy.accountsDelete),
                          onPressed:
                              _busy ? null : () => _confirmAndDelete(a),
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

/// Resultado del diálogo de confirmación: solo se construye al confirmar (lleva el
/// motivo capturado). `null` desde `showDialog` significa que se canceló.
class _DeleteDecision {
  const _DeleteDecision(this.reason);
  final String reason;
}

/// Diálogo de confirmación de la cancelación ARCO. Gestiona su propio
/// [TextEditingController] (lo descarta en `dispose`), evitando usarlo tras
/// liberarlo durante la animación de cierre.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.account});

  final AdminAccountSummary account;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.account;
    return AlertDialog(
      key: const Key('accounts-confirm-dialog'),
      title: const Text(Copy.accountsConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cuenta "${a.handle}" (${a.role}). Se eliminará su identidad y se '
            'anonimizarán ${a.observations} observación(es). El dato ecológico '
            'se conserva. Esta acción no se puede deshacer.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('accounts-reason'),
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: Copy.accountsReasonLabel,
              hintText: Copy.accountsReasonHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('accounts-confirm-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Copy.accountsConfirmCancel),
        ),
        FilledButton(
          key: const Key('accounts-confirm-ok'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: () =>
              Navigator.of(context).pop(_DeleteDecision(_reasonCtrl.text)),
          child: const Text(Copy.accountsConfirmOk),
        ),
      ],
    );
  }
}
