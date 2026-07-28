import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';

/// Sección MONITOR (CR-001): métricas de la revisión de observaciones
/// (GET /review/stats). Solo lectura — visible para evaluador/analista/
/// administrador. SIN umbrales ni semáforos (U1).
class MonitorScreen extends ConsumerStatefulWidget {
  const MonitorScreen({super.key});

  @override
  ConsumerState<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends ConsumerState<MonitorScreen> {
  late Future<ReviewStats> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).reviewStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.navMonitor, style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(Copy.monitorIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        FutureBuilder<ReviewStats>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || snap.data == null) {
              return const Text('No se pudieron cargar las métricas.');
            }
            final s = snap.data!;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                    keyId: 'monitor-total',
                    label: 'Observaciones (no retiradas + retiradas)',
                    value: s.total),
                _MetricCard(
                    keyId: 'monitor-aceptadas',
                    label: 'Aceptadas (sin revisar aún)',
                    value: s.aceptadas),
                _MetricCard(
                    keyId: 'monitor-confirmadas',
                    label: 'Confirmadas',
                    value: s.confirmadas),
                _MetricCard(
                    keyId: 'monitor-rechazadas',
                    label: 'Retiradas',
                    value: s.rechazadas),
                _MetricCard(
                    keyId: 'monitor-pendientes',
                    label: 'Pendientes de revisión',
                    value: s.pendientesDeRevision),
                // CR-029: estas dos tarjetas cuentan cosas distintas y antes se leía como un
                // descuadre ("58 observaciones pero 61 revisiones"). Ahora el par observaciones
                // revisadas / veredictos emitidos deja explícito de dónde sale la diferencia.
                _MetricCard(
                    keyId: 'monitor-revisadas',
                    label: 'Observaciones revisadas',
                    value: s.observacionesRevisadas),
                _MetricCard(
                    keyId: 'monitor-revisiones',
                    label: 'Veredictos emitidos (incluye re-revisiones)',
                    value: s.revisionesTotales),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.keyId, required this.label, required this.value});

  final String keyId;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        key: Key(keyId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: theme.textTheme.displayLarge),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
