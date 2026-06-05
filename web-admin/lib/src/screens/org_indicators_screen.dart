import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';

/// Indicadores organizacionales (Q6 amendment): captura MANUAL en la web admin
/// (mesas formales, aliados firmantes, eventos W3, menciones/coberturas).
///
/// **SIN lógica de umbrales/aprobación (U1, gate boundary):** solo registro y
/// visualización. No hay metas, semáforos ni juicio de aprobación/reprobación.
class OrgIndicatorsScreen extends ConsumerStatefulWidget {
  const OrgIndicatorsScreen({super.key});

  @override
  ConsumerState<OrgIndicatorsScreen> createState() =>
      _OrgIndicatorsScreenState();
}

class _OrgIndicatorsScreenState extends ConsumerState<OrgIndicatorsScreen> {
  OrganizationalIndicatorKey _key = OrganizationalIndicatorKey.all.first;
  final _valueCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  bool _busy = false;
  final List<String> _log = [];

  @override
  void dispose() {
    _valueCtrl.dispose();
    _estadoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = double.tryParse(_valueCtrl.text.trim());
    if (value == null) {
      _snack('Ingresa un valor numérico.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).addOrganizationalIndicator(
            key: _key.key,
            value: value,
            estado: _estadoCtrl.text.trim(),
          );
      setState(() {
        _log.insert(0,
            '${_key.label}: $value${_estadoCtrl.text.trim().isEmpty ? '' : ' (${_estadoCtrl.text.trim()})'}');
        _valueCtrl.clear();
      });
      _snack('Indicador registrado.');
    } on ApiException catch (_) {
      _snack('No se pudo registrar. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Indicadores organizacionales',
            style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          'Captura manual. Solo se registran y se les da seguimiento: ningún '
          'indicador define metas, semáforos ni aprobación/reprobación.',
          key: const Key('org-u1-note'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registrar indicador', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 340,
                      child:
                          DropdownButtonFormField<OrganizationalIndicatorKey>(
                        key: const Key('org-key'),
                        value: _key,
                        decoration:
                            const InputDecoration(labelText: 'Indicador'),
                        items: [
                          for (final k in OrganizationalIndicatorKey.all)
                            DropdownMenuItem(value: k, child: Text(k.label)),
                        ],
                        onChanged: (v) =>
                            setState(() => _key = v ?? _key),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        key: const Key('org-value'),
                        controller: _valueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Valor'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        key: const Key('org-estado'),
                        controller: _estadoCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Estado (opcional)'),
                      ),
                    ),
                    FilledButton(
                      key: const Key('org-submit'),
                      onPressed: _busy ? null : _submit,
                      child: const Text('Registrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Capturados en esta sesión',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final entry in _log)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $entry',
                          style: theme.textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
