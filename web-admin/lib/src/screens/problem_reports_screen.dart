import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/paged_table.dart';

/// Pantalla **Reportes** (CR-019): lista los avisos de problemas que envían las
/// apps (`GET /admin/problem-reports`) y permite marcarlos como "Visto" o
/// "Resuelto" (`POST /admin/problem-reports/{id}/status`). Visible para los
/// roles que administran la consola (`admin_consorcio`/`administrador`).
///
/// Gate #2: no muestra PII; como mucho el `handle` seudónimo de quien reporta.
class ProblemReportsScreen extends ConsumerStatefulWidget {
  const ProblemReportsScreen({super.key});

  @override
  ConsumerState<ProblemReportsScreen> createState() =>
      _ProblemReportsScreenState();
}

class _ProblemReportsScreenState extends ConsumerState<ProblemReportsScreen> {
  late Future<List<ProblemReport>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(apiClientProvider).listProblemReports();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _setStatus(ProblemReport r, String status) async {
    try {
      await ref
          .read(apiClientProvider)
          .setProblemReportStatus(id: r.id, status: status);
      _showSnack(status == 'resuelto'
          ? Copy.problemsMarkedResolved
          : Copy.problemsMarkedSeen);
      if (mounted) setState(_reload);
    } on ApiException catch (_) {
      _showSnack(Copy.problemsActionError);
    } catch (_) {
      _showSnack(Copy.problemsActionError);
    }
  }

  Future<void> _openDetail(ProblemReport r) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProblemDetailDialog(report: r),
    );
    if (mounted) setState(_reload); // refresca por si cambió el estado
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.problemsTitle, style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(Copy.problemsIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('problems-refresh'),
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
            label: const Text(Copy.problemsRefresh),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<ProblemReport>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Text(Copy.problemsLoadError,
                  key: const Key('problems-error'));
            }
            final rows = snap.data ?? const <ProblemReport>[];
            if (rows.isEmpty) {
              return Text(Copy.problemsEmpty, key: const Key('problems-empty'));
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PagedTable<ProblemReport>(
                  items: rows,
                  columns: const [
                    DataColumn(label: Text(Copy.problemsDateLabel)),
                    DataColumn(label: Text(Copy.problemsContextLabel)),
                    DataColumn(label: Text(Copy.problemsBrowserLabel)),
                    DataColumn(label: Text(Copy.problemsVersionLabel)),
                    DataColumn(label: Text(Copy.problemsUserLabel)),
                    DataColumn(label: Text(Copy.problemsStatusLabel)),
                    DataColumn(label: Text(Copy.problemsMessageLabel)),
                    DataColumn(label: Text('')),
                  ],
                  rowBuilder: (r) => DataRow(
                    key: ValueKey('problem-row-${r.id}'),
                    onSelectChanged: (_) => _openDetail(r),
                    cells: [
                      DataCell(Text(_fmtDateTime(r.createdAt))),
                      DataCell(_truncated(r.context, maxWidth: 160)),
                      DataCell(_truncated(r.userAgent, maxWidth: 220)),
                      DataCell(Text(r.appVersion ?? '—')),
                      DataCell(Text((r.handle == null || r.handle!.isEmpty)
                          ? Copy.problemsAnon
                          : r.handle!)),
                      DataCell(_StatusChip(status: r.status)),
                      DataCell(_truncated(r.message, maxWidth: 280)),
                      DataCell(_Actions(
                        report: r,
                        onSeen: () => _setStatus(r, 'visto'),
                        onResolved: () => _setStatus(r, 'resuelto'),
                        onDetail: () => _openDetail(r),
                      )),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Acciones por fila: ver detalle + marcar visto/resuelto. Los botones de estado
/// se deshabilitan si el reporte ya está en ese estado.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.report,
    required this.onSeen,
    required this.onResolved,
    required this.onDetail,
  });

  final ProblemReport report;
  final VoidCallback onSeen;
  final VoidCallback onResolved;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          key: Key('problem-detail-${report.id}'),
          tooltip: Copy.problemsViewDetail,
          icon: const Icon(Icons.info_outline),
          onPressed: onDetail,
        ),
        TextButton(
          key: Key('problem-seen-${report.id}'),
          onPressed: (report.isVisto || report.isResuelto) ? null : onSeen,
          child: const Text(Copy.problemsMarkSeen),
        ),
        TextButton(
          key: Key('problem-resolved-${report.id}'),
          onPressed: report.isResuelto ? null : onResolved,
          child: const Text(Copy.problemsMarkResolved),
        ),
      ],
    );
  }
}

/// Diálogo de detalle de un reporte: muestra todos los campos y el `error_detail`
/// completo, con botones para marcar visto/resuelto.
class _ProblemDetailDialog extends ConsumerStatefulWidget {
  const _ProblemDetailDialog({required this.report});

  final ProblemReport report;

  @override
  ConsumerState<_ProblemDetailDialog> createState() =>
      _ProblemDetailDialogState();
}

class _ProblemDetailDialogState extends ConsumerState<_ProblemDetailDialog> {
  bool _busy = false;

  Future<void> _emit(String status) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .setProblemReportStatus(id: widget.report.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'resuelto'
            ? Copy.problemsMarkedResolved
            : Copy.problemsMarkedSeen),
      ));
      Navigator.of(context).pop();
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Copy.problemsActionError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.report;
    final detail =
        (r.errorDetail == null || r.errorDetail!.isEmpty) ? null : r.errorDetail;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(Copy.problemsDetailTitle,
                        style: theme.textTheme.displayLarge),
                  ),
                  IconButton(
                    key: const Key('problem-detail-close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _field(theme, Copy.problemsDateLabel, _fmtDateTime(r.createdAt)),
              _field(
                  theme,
                  Copy.problemsUserLabel,
                  (r.handle == null || r.handle!.isEmpty)
                      ? Copy.problemsAnon
                      : r.handle!),
              _field(theme, Copy.problemsStatusLabel,
                  Copy.problemStatus(r.status)),
              _field(theme, Copy.problemsContextLabel, r.context ?? '—'),
              _field(theme, Copy.problemsPlatformLabel, r.platform ?? '—'),
              _field(theme, Copy.problemsVersionLabel, r.appVersion ?? '—'),
              _field(theme, Copy.problemsBrowserLabel, r.userAgent ?? '—'),
              const SizedBox(height: 12),
              Text(Copy.problemsMessageLabel, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              SelectableText(
                (r.message == null || r.message!.isEmpty)
                    ? Copy.problemsNoMessage
                    : r.message!,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(Copy.problemsDetailLabel, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  detail ?? Copy.problemsNoDetail,
                  key: const Key('problem-detail-text'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('problem-detail-seen'),
                    onPressed: (_busy || r.isVisto || r.isResuelto)
                        ? null
                        : () => _emit('visto'),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text(Copy.problemsMarkSeen),
                  ),
                  OutlinedButton.icon(
                    key: const Key('problem-detail-resolved'),
                    onPressed:
                        (_busy || r.isResuelto) ? null : () => _emit('resuelto'),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(Copy.problemsMarkResolved),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(ThemeData theme, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
          ],
        ),
      );
}

/// Chip de color según el estado del reporte.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (status) {
      'resuelto' => theme.colorScheme.tertiary,
      'visto' => theme.colorScheme.secondary,
      _ => theme.colorScheme.primary,
    };
    return Chip(
      label: Text(Copy.problemStatus(status)),
      backgroundColor: color.withValues(alpha: 0.15),
    );
  }
}

/// Texto truncado a una línea con tooltip del valor completo (p. ej. el
/// user_agent largo). Muestra "—" si está vacío.
Widget _truncated(String? text, {required double maxWidth}) {
  final value = (text == null || text.isEmpty) ? '—' : text;
  return Tooltip(
    message: value,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

String _fmtDateTime(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}
