import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';

/// Rankings por periodo (Q4): individual + por institución. Filtro por periodo.
/// Puramente informativo (gate #3): no gatea funciones.
class RankingsScreen extends ConsumerWidget {
  const RankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(rankingsPeriodProvider);
    final rankingsAsync = ref.watch(rankingsProvider);

    return Scaffold(
      appBar: const BrandedAppBar(title: Copy.rankingsTitle),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              key: const Key('period_selector'),
              segments: Copy.periodLabels.entries
                  .map((e) => ButtonSegment<String>(
                        value: e.key,
                        label: Text(e.value),
                      ),)
                  .toList(),
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(rankingsPeriodProvider.notifier).state = s.first,
            ),
          ),
          Expanded(
            child: rankingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('No se pudieron cargar rankings.')),
              data: (r) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: 'Individual',
                    child: Column(
                      children: r.individual.isEmpty
                          ? [const Text('Sin datos todavía.')]
                          : r.individual
                              .asMap()
                              .entries
                              .map((e) => StatTile(
                                    label:
                                        '${e.key + 1}. ${e.value.handle}',
                                    value: '${e.value.points} pts',
                                  ),)
                              .toList(),
                    ),
                  ),
                  SectionCard(
                    title: 'Por institución',
                    child: Column(
                      children: r.byInstitution.isEmpty
                          ? [const Text('Sin datos todavía.')]
                          : r.byInstitution
                              .asMap()
                              .entries
                              .map((e) => StatTile(
                                    label:
                                        '${e.key + 1}. ${e.value.institution}',
                                    value: '${e.value.points} pts',
                                  ),)
                              .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
