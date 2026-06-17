import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/caveat_banner.dart';

/// Snapshots trimestrales (Q5.B). Dispara un snapshot (POST /admin/snapshots) y
/// muestra el trimestre/"Qn" vigente (derivado del último snapshot, vía
/// /public/indicators.snapshot_quarter).
class SnapshotsScreen extends ConsumerStatefulWidget {
  const SnapshotsScreen({super.key});

  @override
  ConsumerState<SnapshotsScreen> createState() => _SnapshotsScreenState();
}

class _SnapshotsScreenState extends ConsumerState<SnapshotsScreen> {
  bool _busy = false;
  SnapshotResult? _last;
  String _currentQuarter = '';

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    try {
      final ind = await ref.read(apiClientProvider).publicIndicators();
      if (mounted) setState(() => _currentQuarter = ind.snapshotQuarter);
    } catch (_) {
      // El sello es informativo; un fallo no bloquea la acción de snapshot.
    }
  }

  Future<void> _createSnapshot() async {
    setState(() => _busy = true);
    try {
      final res = await ref.read(apiClientProvider).createSnapshot();
      setState(() {
        _last = res;
        _currentQuarter = res.quarter;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Corte ${res.quarter} publicado.')),
        );
      }
    } on ApiException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo publicar el corte. Inténtalo de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.navSnapshots, style: theme.textTheme.displayLarge),
        const SizedBox(height: 12),
        SnapshotStamp(quarter: _currentQuarter),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cada trimestre se publica un corte con el estado vigente de '
                  'los datos públicos (ubicaciones aproximadas ~300 m).',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('snapshot-create'),
                  onPressed: _busy ? null : _createSnapshot,
                  icon: const Icon(Icons.camera_outlined),
                  label: const Text('Publicar el corte del trimestre'),
                ),
                if (_last != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Último: ${_last!.quarter} · '
                    '${_last!.observationsTotal} observaciones · '
                    '${_last!.createdAt.toIso8601String()}',
                    key: const Key('snapshot-last'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
