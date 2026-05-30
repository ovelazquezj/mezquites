import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/common.dart';

/// Dashboard cliente: observaciones públicas con coords OBFUSCADAS a 1 km
/// (gate #5 — la app nunca muestra más fino), indicadores Q6, y sello "última
/// actualización Qn". La app NO genera PDFs (Q5.B): solo visualiza.
///
/// (El mapa geográfico real se integra en Inc 4 con la lib de mapas; aquí se
/// listan las observaciones públicas ya obfuscadas server-side.)
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obsAsync = ref.watch(publicObservationsProvider);
    final indAsync = ref.watch(publicIndicatorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(Copy.dashboardTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicObservationsProvider);
          ref.invalidate(publicIndicatorsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const InfoNote(Copy.obfuscationNote),
            const SizedBox(height: 8),
            indAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const SizedBox.shrink(),
              data: (ind) => _IndicatorsCard(indicators: ind),
            ),
            const SizedBox(height: 8),
            obsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Text('No se pudieron cargar observaciones.'),
              data: (list) => _PublicList(observations: list),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorsCard extends StatelessWidget {
  const _IndicatorsCard({required this.indicators});

  final Indicators indicators;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final social = indicators.social;
    final eco = indicators.ecologico;
    return SectionCard(
      title: 'Indicadores',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SnapshotStamp(indicators.snapshotQuarter),
          const SizedBox(height: 8),
          StatTile(
            label: 'Registrados',
            value: '${social['registrados'] ?? '-'}',
          ),
          StatTile(
            label: 'Observaciones totales',
            value: '${social['observaciones_totales'] ?? '-'}',
          ),
          StatTile(
            label: 'Árboles únicos',
            value: '${eco['arboles_unicos'] ?? '-'}',
          ),
          const SizedBox(height: 8),
          Text(indicators.caveat, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PublicList extends StatelessWidget {
  const _PublicList({required this.observations});

  final List<PublicObservation> observations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (observations.isEmpty) {
      return const SectionCard(child: Text('Aún no hay observaciones públicas.'));
    }
    return SectionCard(
      title: 'Observaciones (ubicación aproximada ~1 km)',
      child: Column(
        children: observations.take(50).map((o) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.park_outlined),
            title: Text(
              '${o.handle} · ${Copy.nivelG4(o.nivelG4)}',
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Text(
              '${o.municipio ?? '—'}, ${o.estado ?? '—'} · '
              '~${o.lat.toStringAsFixed(2)}, ${o.lon.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall,
            ),
          );
        }).toList(),
      ),
    );
  }
}
