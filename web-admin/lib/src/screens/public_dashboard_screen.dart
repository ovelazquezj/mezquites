import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/paged_table.dart';
import '../widgets/caveat_banner.dart';
import '../widgets/estado_filter.dart';
import '../widgets/paxtle_pie_chart.dart';

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
      // CR-034: trae TODO paginando contra el backend; el limit fijo de 200
      // escondía el resto de las observaciones.
      final observations = await api.publicObservationsAll(estado: _estado);
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
                // CR-034: la distribución de niveles no va como texto en el
                // grupo — la cuenta el pastel de aquí abajo.
                _IndicatorGroup(
                  title: 'Ecológico',
                  data: ind.ecologico,
                  exclude: const {'distribucion_niveles'},
                ),
                _PaxtlePieCard(ecologico: ind.ecologico),
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
  const _IndicatorGroup({
    required this.title,
    required this.data,
    this.exclude = const {},
  });

  final String title;
  final Map<String, dynamic> data;

  /// Claves que esta tarjeta NO pinta (porque las cuenta otro widget, como el
  /// pastel de niveles de paxtle).
  final Set<String> exclude;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entradas =
        data.entries.where((e) => !exclude.contains(e.key)).toList();
    // CR-034: los valores anidados (mapas) se pintaban con toString() y salían
    // como "{leve: 3, moderado: 1}" — ilegibles. Van aparte, como desglose.
    final escalares = entradas.where((e) => e.value is! Map).toList();
    final desgloses = entradas.where((e) => e.value is Map).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (entradas.isEmpty)
              Text('Sin datos.', style: theme.textTheme.bodyMedium)
            else ...[
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final e in escalares)
                    _Metric(label: e.key, value: e.value),
                ],
              ),
              for (final d in desgloses) ...[
                const SizedBox(height: 12),
                _Breakdown(
                  groupKey: d.key,
                  data: (d.value as Map).cast<String, dynamic>(),
                ),
              ],
            ],
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

  /// Las proporciones del backend viajan como fracción (0.1234); mostrarlas
  /// así confundía. Se presentan como porcentaje redondeado (CR-034).
  String get _display => value is num && label.startsWith('proporcion')
      ? '${((value as num) * 100).round()} %'
      : '$value';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_display,
            style: theme.textTheme.titleLarge
                ?.copyWith(color: theme.colorScheme.primary)),
        Text(Copy.indicatorLabel(label), style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Desglose legible de un indicador anidado (CR-034): título traducido + una
/// línea "Etiqueta — n" por entrada, con las claves wire traducidas.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.groupKey, required this.data});

  final String groupKey;
  final Map<String, dynamic> data;

  /// Orden fijo de escala cuando la clave lo tiene; lo demás, como venga.
  static const _ordenes = <String, List<String>>{
    'distribucion_niveles': PaxtlePieChart.nivelesOrdenados,
    'distribucion_identidad_e3': [
      'nuevo_observador',
      'observador',
      'observador_experimentado',
      'veterano_del_mezquite',
    ],
  };

  String _sub(String key) => switch (groupKey) {
        'distribucion_niveles' => Copy.nivelG4(key),
        'distribucion_identidad_e3' => Copy.identidadE3(key),
        _ => Copy.indicatorLabel(key),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orden = _ordenes[groupKey];
    final claves = data.keys.toList();
    if (orden != null) {
      claves.sort((a, b) {
        final ia = orden.indexOf(a);
        final ib = orden.indexOf(b);
        return (ia < 0 ? orden.length : ia) - (ib < 0 ? orden.length : ib);
      });
    }
    return Column(
      key: Key('breakdown-$groupKey'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Copy.indicatorLabel(groupKey), style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        if (claves.isEmpty)
          Text('Sin datos.', style: theme.textTheme.bodyMedium)
        else
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final k in claves)
                Text('${_sub(k)} — ${data[k]}',
                    style: theme.textTheme.bodyMedium),
            ],
          ),
      ],
    );
  }
}

/// Tarjeta del pastel de niveles de paxtle (CR-034). El agregado viene del
/// servidor sobre TODAS las confirmadas (mismo universo que el mapa público);
/// el nivel es autodeclarado por quien observa (gate #8).
class _PaxtlePieCard extends StatelessWidget {
  const _PaxtlePieCard({required this.ecologico});

  final Map<String, dynamic> ecologico;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crudo = ecologico['distribucion_niveles'];
    final conteos = crudo is Map
        ? crudo.cast<String, num>()
        : const <String, num>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nivel de paxtle declarado', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'De las observaciones confirmadas que publica este panel. El '
              'nivel lo declara quien observa, sin validación por expertos.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            PaxtlePieChart(conteos: conteos),
          ],
        ),
      ),
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
