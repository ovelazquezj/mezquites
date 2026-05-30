import 'package:flutter/material.dart';

/// Tarjeta de sección minimalista (baja densidad). Usa solo tokens del tema.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Fila de estadística clave/valor.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// Banner informativo (usa color semántico `info` del tema vía secondary/tertiary).
class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.tertiary, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Sello de "última actualización Qn" para vistas de datos.
class SnapshotStamp extends StatelessWidget {
  const SnapshotStamp(this.quarter, {super.key});

  final String quarter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Última actualización: $quarter',
      key: const Key('snapshot_stamp'),
      style: theme.textTheme.bodySmall,
    );
  }
}
