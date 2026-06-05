import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/estado_filter.dart';

/// Dashboard RESTRINGIDO (Q5.B): observaciones con coords **exactas**
/// (GET /restricted/observations). Solo accesible si el token es
/// `aliado_firmante`/autorizado; si no, esta pantalla no se ofrece en la
/// navegación (gate #5). Aun así, defiende contra un 403 del backend.
class RestrictedDashboardScreen extends ConsumerStatefulWidget {
  const RestrictedDashboardScreen({super.key});

  @override
  ConsumerState<RestrictedDashboardScreen> createState() =>
      _RestrictedDashboardScreenState();
}

class _RestrictedDashboardScreenState
    extends ConsumerState<RestrictedDashboardScreen> {
  String? _estado;
  late Future<List<RestrictedObservation>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref
        .read(apiClientProvider)
        .restrictedObservations(estado: _estado, limit: 500);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.navRestricted, style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          'Ubicaciones exactas. Acceso solo para aliados firmantes autorizados '
          '(para proteger los árboles). Vista de solo consulta.',
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
        FutureBuilder<List<RestrictedObservation>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final err = snap.error;
              if (err is ApiException && err.isAuthError) {
                return Card(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Acceso denegado: tu cuenta no tiene permiso para ver '
                      'ubicaciones exactas (requiere ser aliado firmante).',
                      key: const Key('restricted-denied'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              return const Text('No se pudo cargar. Inténtalo de nuevo.');
            }
            final rows = snap.data ?? const <RestrictedObservation>[];
            if (rows.isEmpty) {
              return const Text('Sin observaciones para este filtro.');
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Usuario')),
                      DataColumn(label: Text('Latitud exacta')),
                      DataColumn(label: Text('Longitud exacta')),
                      DataColumn(label: Text('Nivel de paxtle')),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Municipio')),
                      DataColumn(label: Text('Validación')),
                    ],
                    rows: [
                      for (final o in rows)
                        DataRow(cells: [
                          DataCell(Text(o.handle)),
                          DataCell(Text(o.lat.toStringAsFixed(6))),
                          DataCell(Text(o.lon.toStringAsFixed(6))),
                          DataCell(Text(Copy.nivelG4(o.nivelG4))),
                          DataCell(Text(o.estado ?? '—')),
                          DataCell(Text(o.municipio ?? '—')),
                          DataCell(Text(Copy.validationState(o.validationState))),
                        ]),
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
