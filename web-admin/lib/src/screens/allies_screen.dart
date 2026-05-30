import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../state/session.dart';

/// Aliados firmantes (Q4/Q5.B). Promueve una cuenta existente a
/// `aliado_firmante` (POST /admin/allies). La UI deja claro que esto habilita
/// el acceso a **coordenadas exactas** vía la vista restringida.
class AlliesScreen extends ConsumerStatefulWidget {
  const AlliesScreen({super.key});

  @override
  ConsumerState<AlliesScreen> createState() => _AlliesScreenState();
}

class _AlliesScreenState extends ConsumerState<AlliesScreen> {
  final _handleCtrl = TextEditingController();
  bool _busy = false;
  String? _lastPromoted;

  @override
  void dispose() {
    _handleCtrl.dispose();
    super.dispose();
  }

  Future<void> _promote() async {
    final handle = _handleCtrl.text.trim();
    if (handle.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(apiClientProvider).addAlly(handle: handle);
      setState(() => _lastPromoted = (res['handle'] ?? handle) as String);
      _handleCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cuenta $_lastPromoted promovida a aliado firmante (coords exactas).'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.statusCode == 404
                ? 'No existe una cuenta con ese handle.'
                : 'No se pudo promover (${e.statusCode}).'),
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
        Text('Aliados firmantes', style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Card(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.vpn_key_outlined,
                    color: theme.colorScheme.tertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Un aliado firmante es la ÚNICA cuenta (además del consorcio) '
                    'que puede ver coordenadas EXACTAS de los árboles (vista '
                    'restringida). El resto del público solo ve coordenadas '
                    'obfuscadas a 1 km. Promover habilita ese acceso.',
                    key: const Key('allies-coords-explainer'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Promover cuenta', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        key: const Key('ally-handle'),
                        controller: _handleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Handle de la cuenta',
                          hintText: 'p.ej. obs-7HQ4K2',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      key: const Key('ally-promote'),
                      onPressed: _busy ? null : _promote,
                      child: const Text('Promover a aliado firmante'),
                    ),
                  ],
                ),
                if (_lastPromoted != null) ...[
                  const SizedBox(height: 12),
                  Text('Última promoción: $_lastPromoted',
                      style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
