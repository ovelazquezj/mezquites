import 'package:flutter/material.dart';

/// Banner del **caveat de origen ciudadano** (Q5.B / Q5.D / gate del caveat).
///
/// El texto lo provee el backend (`/public/indicators.caveat`,
/// `indicators.CAVEAT`). Debe ser visible en todo dashboard que exponga datos
/// ciudadanos. Si el backend no entrega caveat, se usa un placeholder marcado.
class CaveatBanner extends StatelessWidget {
  const CaveatBanner({super.key, required this.caveat});

  /// Texto del caveat tal cual lo entrega el backend. Si viene vacío, se marca
  /// como placeholder pendiente (no se inventa contenido).
  final String caveat;

  static const String _placeholder =
      '[PLACEHOLDER — caveat de origen ciudadano no recibido del backend] '
      'Datos de origen ciudadano, sin validación por expertos.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = caveat.trim().isEmpty ? _placeholder : caveat;
    return Card(
      color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                key: const Key('caveat-text'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sello "última actualización: Q[N]" (Q5.B: toda vista muestra el snapshot).
class SnapshotStamp extends StatelessWidget {
  const SnapshotStamp({super.key, required this.quarter});

  final String quarter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = quarter.trim().isEmpty ? '—' : quarter;
    return Chip(
      key: const Key('snapshot-stamp'),
      avatar: Icon(Icons.update, size: 18, color: theme.colorScheme.primary),
      label: Text('Última actualización: $label'),
    );
  }
}
