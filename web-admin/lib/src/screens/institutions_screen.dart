import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/h_scroll.dart';

/// Lista F3 / instituciones (Q4). Ver lista completa (aprobadas + solicitadas),
/// crear/aprobar, y "solicitar agregar" (ticket a EA3, status=solicitada).
class InstitutionsScreen extends ConsumerStatefulWidget {
  const InstitutionsScreen({super.key});

  @override
  ConsumerState<InstitutionsScreen> createState() =>
      _InstitutionsScreenState();
}

class _InstitutionsScreenState extends ConsumerState<InstitutionsScreen> {
  late Future<List<Institution>> _future;
  final _nameCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();
  bool _requestOnly = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _estadoCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    _future = ref.read(apiClientProvider).listInstitutions();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).addInstitution(
            name: _nameCtrl.text.trim(),
            estado: _estadoCtrl.text.trim(),
            requestOnly: _requestOnly,
          );
      _nameCtrl.clear();
      _estadoCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_requestOnly
                ? 'Solicitud enviada al ${Copy.orgName} para su revisión.'
                : 'Institución aprobada y agregada.'),
          ),
        );
        setState(_reload);
      }
    } on ApiException catch (_) {
      _showError('No se pudo guardar. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Aprueba una institución solicitada (CR-011): pasa a aprobada y al catálogo público.
  Future<void> _approve(Institution inst) async {
    try {
      await ref.read(apiClientProvider).approveInstitution(inst.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${inst.name}" aprobada y publicada en el catálogo.')),
        );
        setState(_reload);
      }
    } on ApiException catch (_) {
      _showError('No se pudo aprobar. Inténtalo de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Instituciones', style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          'Las nuevas instituciones las revisa y aprueba el ${Copy.orgName}. Las '
          'marcadas como "Solicitada" quedan pendientes de esa revisión.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agregar institución', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        key: const Key('institution-name'),
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: TextField(
                        key: const Key('institution-estado'),
                        controller: _estadoCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Estado (opcional)'),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          key: const Key('institution-request-only'),
                          value: _requestOnly,
                          onChanged: (v) => setState(() => _requestOnly = v),
                        ),
                        Text('Solo solicitar (revisión del ${Copy.orgName})'),
                      ],
                    ),
                    FilledButton(
                      key: const Key('institution-submit'),
                      onPressed: _busy ? null : _submit,
                      child: Text(_requestOnly ? 'Solicitar' : 'Aprobar y agregar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Institution>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return const Text('No se pudo cargar la lista. Inténtalo de nuevo.');
            }
            final rows = snap.data ?? const <Institution>[];
            if (rows.isEmpty) {
              return const Text('Sin instituciones registradas.');
            }
            return Card(
              child: HScroll(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Situación')),
                    DataColumn(label: Text('Acción')),
                  ],
                  rows: [
                    for (final i in rows)
                      DataRow(cells: [
                        DataCell(Text(i.name)),
                        DataCell(Text(i.estado ?? '—')),
                        DataCell(Chip(
                          label: Text(Copy.institutionStatus(i.status)),
                          backgroundColor: i.isRequested
                              ? theme.colorScheme.secondary
                                  .withValues(alpha: 0.2)
                              : theme.colorScheme.tertiary
                                  .withValues(alpha: 0.15),
                        )),
                        DataCell(i.isRequested
                            ? TextButton(
                                key: Key('institution-approve-${i.id}'),
                                onPressed: () => _approve(i),
                                child: const Text('Aprobar'),
                              )
                            : const Text('—')),
                      ]),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
