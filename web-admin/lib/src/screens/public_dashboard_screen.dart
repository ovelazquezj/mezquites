import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/paged_table.dart';
import '../widgets/caveat_banner.dart';
import '../widgets/estado_filter.dart';

/// Dashboard PÚBLICO (Q5.B). Indicadores Q6 + observaciones abiertas. Muestra
/// el caveat de origen ciudadano y el sello "última actualización Qn". Filtro
/// geográfico por estado (Q8).
///
/// Boundary (Q5.B / gate #1): dashboards como pieza única. NO hay botón de
/// exportar PDF ni generación de reportes narrativos.
class PublicDashboardScreen extends ConsumerStatefulWidget {
  const PublicDashboardScreen({super.key});

  @override
  ConsumerState<PublicDashboardScreen> createState() =>
      _PublicDashboardScreenState();
}

class _PublicDashboardScreenState
    extends ConsumerState<PublicDashboardScreen> {
  String? _estado;
  late Future<_PublicData> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = ref.read(apiClientProvider);
    _future = () async {
      final indicators = await api.publicIndicators(estado: _estado);
      final observations =
          await api.publicObservations(estado: _estado, limit: 200);
      return _PublicData(indicators, observations);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.navPublic, style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          'Datos abiertos de las observaciones. Vista de solo consulta.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        EstadoFilter(
          value: _estado,
          onChanged: (v) => setState(() {
            _estado = v;
            _reload();
          }),
        ),
        const SizedBox(height: 16),
        FutureBuilder<_PublicData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return const Text('No se pudo cargar el panel. Inténtalo de nuevo.');
            }
            final data = snap.data!;
            final ind = data.indicators;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SnapshotStamp(quarter: ind.snapshotQuarter),
                ),
                const SizedBox(height: 12),
                CaveatBanner(caveat: ind.caveat),
                const SizedBox(height: 16),
                _IndicatorGroup(title: 'Social', data: ind.social),
                _IndicatorGroup(title: 'Educativo', data: ind.educativo),
                _IndicatorGroup(title: 'Ecológico', data: ind.ecologico),
                _IndicatorGroup(
                    title: 'Organizacional', data: ind.organizacional),
                const SizedBox(height: 16),
                _ObservationsTable(rows: data.observations),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PublicData {
  _PublicData(this.indicators, this.observations);
  final Indicators indicators;
  final List<PublicObservation> observations;
}

class _IndicatorGroup extends StatelessWidget {
  const _IndicatorGroup({required this.title, required this.data});

  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (data.isEmpty)
              Text('Sin datos.', style: theme.textTheme.bodyMedium)
            else
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final e in data.entries)
                    _Metric(label: e.key, value: e.value),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value',
            style: theme.textTheme.titleLarge
                ?.copyWith(color: theme.colorScheme.primary)),
        Text(Copy.indicatorLabel(label), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ObservationsTable extends StatelessWidget {
  const _ObservationsTable({required this.rows});
  final List<PublicObservation> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Sin observaciones públicas para este filtro.',
              style: theme.textTheme.bodyMedium),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Observaciones',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            PagedTable<PublicObservation>(
              items: rows,
              columns: const [
                DataColumn(label: Text('Usuario')),
                DataColumn(label: Text('Latitud')),
                DataColumn(label: Text('Longitud')),
                DataColumn(label: Text('Nivel de paxtle')),
                DataColumn(label: Text('Cúscuta')),
                DataColumn(label: Text('Daño')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Municipio')),
              ],
              rowBuilder: (o) => DataRow(cells: [
                DataCell(Text(o.handle)),
                DataCell(Text(o.lat.toStringAsFixed(2))),
                DataCell(Text(o.lon.toStringAsFixed(2))),
                DataCell(Text(Copy.nivelG4(o.nivelG4))),
                DataCell(Text(o.flagCuscuta ? 'sí' : 'no')),
                DataCell(Text(o.flagDanio ? 'sí' : 'no')),
                DataCell(Text(o.estado ?? '—')),
                DataCell(Text(o.municipio ?? '—')),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
