import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';

/// Comprobante de participación (CR-010 #7). Muestra, como evidencia para el
/// alumno, un resumen AGREGADO de su actividad: nº de capturas, horas
/// acumuladas, nº de sesiones y rango de fechas. Solo pantalla (sin PDF).
///
/// Gate #1: descriptivo (cuenta aportaciones/tiempo; sin acciones de manejo).
/// Gate #2: sin PII (solo conteos y fechas). Gate #3: no bloquea nada.
class EvidenceScreen extends ConsumerWidget {
  const EvidenceScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EvidenceScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evidenceAsync = ref.watch(evidenceProvider);

    return Scaffold(
      appBar: const BrandedAppBar(title: Copy.evidenceTitle),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(evidenceProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const InfoNote(Copy.evidenceNote),
            const SizedBox(height: 8),
            evidenceAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text(Copy.evidenceError),
              ),
              data: (e) => _EvidenceBody(evidence: e),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceBody extends StatelessWidget {
  const _EvidenceBody({required this.evidence});

  final Evidence evidence;

  String _fecha(DateTime d) {
    final local = d.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRango = evidence.primera != null && evidence.ultima != null;
    return SectionCard(
      title: Copy.evidenceTitle,
      child: Column(
        children: [
          StatTile(
            label: Copy.evidenceCapturas,
            value: '${evidence.capturas}',
          ),
          StatTile(
            label: Copy.evidenceHoras,
            value: evidence.horasTotales.toStringAsFixed(1),
          ),
          StatTile(
            label: Copy.evidenceSesiones,
            value: '${evidence.sesiones}',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              hasRango
                  ? '${Copy.evidenceRango}: '
                      '${_fecha(evidence.primera!)} – ${_fecha(evidence.ultima!)}'
                  : Copy.evidenceSinRango,
              key: const Key('evidence_rango'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
