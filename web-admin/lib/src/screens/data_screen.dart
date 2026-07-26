import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../services/download.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/paged_table.dart';

/// Pantalla **Datos y descargas** del analista (CR-010 #3). Visible para
/// `analista` y `administrador`. Muestra:
///  - Tarjetas de resumen desde `GET /admin/analytics/summary`.
///  - Tabla de observaciones con filtros (estado de revisión, municipio, nivel,
///    fecha) desde `GET /admin/analytics/observations`.
///  - Botón "Descargar CSV" que baja `GET /admin/analytics/observations.csv`
///    por fetch autenticado y lo entrega al navegador.
///
/// Gate #5: NUNCA muestra ni descarga coords exactas; solo estado/municipio.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  // Filtros aplicados (los que viajan a la API).
  String? _estadoRevision;
  final _municipioCtrl = TextEditingController();
  String? _nivelG4;
  final _desdeCtrl = TextEditingController();
  final _hastaCtrl = TextEditingController();

  bool _downloading = false;
  bool _downloadingParticipation = false; // CR-026
  late Future<_DataBundle> _future;

  static const _estadoRevisionItems = <String, String>{
    'aceptada': 'Aceptadas',
    'confirmada': 'Confirmadas',
    'rechazada': 'Retiradas',
  };
  static const _nivelItems = <String, String>{
    'sano': 'Sano',
    'leve': 'Leve',
    'moderado': 'Moderado',
    'severo': 'Severo',
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _municipioCtrl.dispose();
    _desdeCtrl.dispose();
    _hastaCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    final api = ref.read(apiClientProvider);
    final mun = _municipioCtrl.text.trim();
    final desde = _desdeCtrl.text.trim();
    final hasta = _hastaCtrl.text.trim();
    _future = () async {
      final summary = await api.analyticsSummary(
        estadoRevision: _estadoRevision,
        municipio: mun,
        nivelG4: _nivelG4,
        desde: desde,
        hasta: hasta,
      );
      final rows = await api.analyticsObservations(
        estadoRevision: _estadoRevision,
        municipio: mun,
        nivelG4: _nivelG4,
        desde: desde,
        hasta: hasta,
        limit: 1000,
      );
      return _DataBundle(summary, rows);
    }();
  }

  void _clearFilters() {
    setState(() {
      _estadoRevision = null;
      _nivelG4 = null;
      _municipioCtrl.clear();
      _desdeCtrl.clear();
      _hastaCtrl.clear();
      _reload();
    });
  }

  Future<void> _downloadCsv() async {
    setState(() => _downloading = true);
    try {
      final bytes = await ref.read(apiClientProvider).analyticsCsvBytes(
            estadoRevision: _estadoRevision,
            municipio: _municipioCtrl.text.trim(),
            nivelG4: _nivelG4,
            desde: _desdeCtrl.text.trim(),
            hasta: _hastaCtrl.text.trim(),
          );
      downloadBytes(bytes, 'observaciones_mezquite.csv');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Copy.dataDownloadDone)),
      );
    } on ApiException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Copy.dataDownloadError)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Copy.dataDownloadError)),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// CR-026: descarga la participación por día × voluntario (sesiones y horas
  /// frente al resultado de revisión). Usa solo los filtros que ese reporte
  /// entiende: municipio y rango de fechas.
  Future<void> _downloadParticipationCsv() async {
    setState(() => _downloadingParticipation = true);
    try {
      final bytes = await ref.read(apiClientProvider).participationCsvBytes(
            municipio: _municipioCtrl.text.trim(),
            desde: _desdeCtrl.text.trim(),
            hasta: _hastaCtrl.text.trim(),
          );
      downloadBytes(bytes, 'participacion_mezquite.csv');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Copy.dataDownloadDone)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Copy.dataDownloadError)),
      );
    } finally {
      if (mounted) setState(() => _downloadingParticipation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // CR-023: roles con ubicación exacta ven un aviso extra sobre el CSV.
    final canSeeExact = ref.watch(sessionProvider).canSeeRestricted;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.navData, style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          Copy.dataIntro,
          key: const Key('data-location-note'),
          style: theme.textTheme.bodySmall,
        ),
        if (canSeeExact) ...[
          const SizedBox(height: 8),
          Card(
            key: const Key('data-exact-note'),
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Copy.dataExactNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Filters(
          estadoRevision: _estadoRevision,
          estadoRevisionItems: _estadoRevisionItems,
          nivelG4: _nivelG4,
          nivelItems: _nivelItems,
          municipioCtrl: _municipioCtrl,
          desdeCtrl: _desdeCtrl,
          hastaCtrl: _hastaCtrl,
          onEstadoRevision: (v) => setState(() => _estadoRevision = v),
          onNivel: (v) => setState(() => _nivelG4 = v),
          onApply: () => setState(_reload),
          onClear: _clearFilters,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              key: const Key('data-download-csv'),
              onPressed: _downloading ? null : _downloadCsv,
              icon: _downloading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: const Text(Copy.dataDownloadCsv),
            ),
            // CR-026: segundo reporte, pedido por las universidades.
            OutlinedButton.icon(
              key: const Key('data-download-participation-csv'),
              onPressed:
                  _downloadingParticipation ? null : _downloadParticipationCsv,
              icon: _downloadingParticipation
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.groups_outlined),
              label: const Text(Copy.dataDownloadParticipationCsv),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          Copy.dataParticipationNote,
          key: const Key('data-participation-note'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        FutureBuilder<_DataBundle>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return const Text('No se pudieron cargar los datos. Inténtalo de nuevo.');
            }
            final bundle = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryCards(summary: bundle.summary),
                const SizedBox(height: 16),
                _ObservationsTable(rows: bundle.rows),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DataBundle {
  _DataBundle(this.summary, this.rows);
  final AnalyticsSummary summary;
  final List<AnalyticsObservation> rows;
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.estadoRevision,
    required this.estadoRevisionItems,
    required this.nivelG4,
    required this.nivelItems,
    required this.municipioCtrl,
    required this.desdeCtrl,
    required this.hastaCtrl,
    required this.onEstadoRevision,
    required this.onNivel,
    required this.onApply,
    required this.onClear,
  });

  final String? estadoRevision;
  final Map<String, String> estadoRevisionItems;
  final String? nivelG4;
  final Map<String, String> nivelItems;
  final TextEditingController municipioCtrl;
  final TextEditingController desdeCtrl;
  final TextEditingController hastaCtrl;
  final ValueChanged<String?> onEstadoRevision;
  final ValueChanged<String?> onNivel;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                key: const Key('data-filter-estado-revision'),
                value: estadoRevision,
                decoration:
                    const InputDecoration(labelText: Copy.dataFilterEstadoRevision),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  for (final e in estadoRevisionItems.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: onEstadoRevision,
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                key: const Key('data-filter-nivel'),
                value: nivelG4,
                decoration: const InputDecoration(labelText: Copy.dataFilterNivel),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  for (final e in nivelItems.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: onNivel,
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                key: const Key('data-filter-municipio'),
                controller: municipioCtrl,
                decoration:
                    const InputDecoration(labelText: Copy.dataFilterMunicipio),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                key: const Key('data-filter-desde'),
                controller: desdeCtrl,
                decoration: const InputDecoration(labelText: Copy.dataFilterDesde),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                key: const Key('data-filter-hasta'),
                controller: hastaCtrl,
                decoration: const InputDecoration(labelText: Copy.dataFilterHasta),
              ),
            ),
            FilledButton(
              key: const Key('data-apply-filters'),
              onPressed: onApply,
              child: const Text(Copy.dataApplyFilters),
            ),
            OutlinedButton(
              key: const Key('data-clear-filters'),
              onPressed: onClear,
              child: const Text(Copy.dataClearFilters),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      key: const Key('data-summary'),
      spacing: 16,
      runSpacing: 16,
      children: [
        _SummaryCard(
          title: Copy.dataSummaryTotal,
          child: Text(
            '${summary.total}',
            style: theme.textTheme.displayLarge
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        _SummaryCard(
          title: Copy.dataSummaryByRevision,
          child: _Breakdown(
            data: summary.porEstadoRevision,
            labelOf: Copy.estadoRevision,
          ),
        ),
        _SummaryCard(
          title: Copy.dataSummaryByNivel,
          child: _Breakdown(data: summary.porNivelG4, labelOf: Copy.nivelG4),
        ),
        _SummaryCard(
          title: Copy.dataSummaryByMunicipio,
          child: _Breakdown(data: summary.porMunicipio, labelOf: (k) => k),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.data, required this.labelOf});

  final Map<String, int> data;
  final String Function(String) labelOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.isEmpty) {
      return Text('Sin datos.', style: theme.textTheme.bodyMedium);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in data.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(labelOf(e.key), style: theme.textTheme.bodyMedium),
                ),
                const SizedBox(width: 12),
                Text('${e.value}', style: theme.textTheme.titleLarge),
              ],
            ),
          ),
      ],
    );
  }
}

class _ObservationsTable extends StatelessWidget {
  const _ObservationsTable({required this.rows});

  final List<AnalyticsObservation> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(Copy.dataEmpty,
              key: const Key('data-empty'), style: theme.textTheme.bodyMedium),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PagedTable<AnalyticsObservation>(
          items: rows,
          columns: const [
            DataColumn(label: Text('Usuario')),
            DataColumn(label: Text('Fecha')),
            DataColumn(label: Text('Estado de revisión')),
            DataColumn(label: Text('Nivel de paxtle')),
            DataColumn(label: Text('Cúscuta')),
            DataColumn(label: Text('Daño')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Municipio')),
          ],
          rowBuilder: (o) => DataRow(
            key: ValueKey('data-row-${o.observationId}'),
            cells: [
              DataCell(Text(o.handle)),
              DataCell(Text(_fmtDate(o.capturedAt))),
              DataCell(Text(Copy.estadoRevision(o.estadoRevision))),
              DataCell(Text(Copy.nivelG4(o.nivelG4))),
              DataCell(Text(o.flagCuscuta ? 'sí' : 'no')),
              DataCell(Text(o.flagDanio ? 'sí' : 'no')),
              DataCell(Text(o.estado ?? '—')),
              DataCell(Text(o.municipio ?? '—')),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
