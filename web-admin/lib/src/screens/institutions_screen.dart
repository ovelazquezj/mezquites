import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/paged_table.dart';

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
    } on ApiException catch (e) {
      // CR-028: 409 = ya hay una institución con ese nombre (aunque difiera en acentos,
      // mayúsculas o espacios). No es un fallo técnico, así que se explica en vez de invitar a
      // reintentar: reintentar daría el mismo 409. Se recarga para que la existente quede a la
      // vista en la tabla de abajo.
      if (e.statusCode == 409) {
        _showError(
          'Ya existe una institución con ese nombre. Búscala en la lista de abajo '
          'y apruébala o edítala en vez de agregar otra.',
        );
        setState(_reload);
      } else {
        _showError('No se pudo guardar. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Editar nombre/estado de una institución ya registrada (CR-029). No toca `status`.
  Future<void> _edit(Institution inst) async {
    final guardada = await showDialog<Institution>(
      context: context,
      builder: (_) => _EditInstitutionDialog(institution: inst),
    );
    if (guardada != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${guardada.name}" actualizada.')),
      );
      setState(_reload);
    }
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PagedTable<Institution>(
                  items: rows,
                  columns: const [
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Situación')),
                    DataColumn(label: Text('Acción')),
                  ],
                  rowBuilder: (i) => DataRow(cells: [
                    DataCell(Text(i.name)),
                    DataCell(Text(i.estado ?? '—')),
                    DataCell(Chip(
                      label: Text(Copy.institutionStatus(i.status)),
                      backgroundColor: i.isRequested
                          ? theme.colorScheme.secondary.withValues(alpha: 0.2)
                          : theme.colorScheme.tertiary.withValues(alpha: 0.15),
                    )),
                    // CR-029: "Editar" está siempre; "Aprobar" solo si sigue solicitada.
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          key: Key('institution-edit-${i.id}'),
                          onPressed: () => _edit(i),
                          child: const Text('Editar'),
                        ),
                        if (i.isRequested)
                          TextButton(
                            key: Key('institution-approve-${i.id}'),
                            onPressed: () => _approve(i),
                            child: const Text('Aprobar'),
                          ),
                      ],
                    )),
                  ]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Diálogo de edición de una institución (CR-029): nombre + estado.
///
/// **No ofrece cambiar la situación** (aprobada/solicitada) a propósito: degradar una aprobada la
/// sacaría del catálogo con voluntarios ya afiliados. Para aprobar está el botón "Aprobar".
///
/// Si el nombre nuevo ya lo usa otra institución, el backend responde 409 (índice único de CR-028)
/// y el error se muestra dentro del diálogo, sin cerrarlo, para que se pueda corregir en el momento.
class _EditInstitutionDialog extends ConsumerStatefulWidget {
  const _EditInstitutionDialog({required this.institution});

  final Institution institution;

  @override
  ConsumerState<_EditInstitutionDialog> createState() =>
      _EditInstitutionDialogState();
}

class _EditInstitutionDialogState
    extends ConsumerState<_EditInstitutionDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.institution.name);
  late final TextEditingController _estadoCtrl =
      TextEditingController(text: widget.institution.estado ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _estadoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe el nombre.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final actualizada = await ref.read(apiClientProvider).updateInstitution(
            widget.institution.id,
            name: name,
            estado: _estadoCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop(actualizada);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.statusCode == 409
            ? 'Ya existe otra institución con ese nombre. Elige uno distinto.'
            : 'No se pudo guardar. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar institución'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('institution-edit-name'),
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('institution-edit-estado'),
            controller: _estadoCtrl,
            decoration: const InputDecoration(
              labelText: 'Estado',
              helperText: 'Déjalo vacío si no aplica.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('institution-edit-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('institution-edit-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('institution-edit-save'),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
