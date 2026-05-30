import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../copy.dart';

/// Selector de nivel G4 (Q3, A2) — EXACTAMENTE 4 opciones discretas
/// (sano/leve/moderado/severo), cada una con su RANGO % de copa visible.
///
/// Gate #8: el nivel es AUTODECLARADO; este widget NO afirma que se valida.
/// Q3: SIN foto de referencia en el selector (las fotos viven en Aprendizaje).
class G4Selector extends StatelessWidget {
  const G4Selector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final NivelG4? value;
  final ValueChanged<NivelG4> onChanged;

  /// Las 4 opciones canónicas, en orden ordinal. Clave de los tests.
  static const options = NivelG4.values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('g4_selector'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Copy.captureNivelLabel, style: theme.textTheme.titleLarge),
        Text(Copy.captureNivelHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        // Exactamente 4 opciones; cada tile expone label + rango %.
        ...options.map(
          (n) => RadioListTile<NivelG4>(
            key: Key('g4_option_${n.wire}'),
            value: n,
            groupValue: value,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            title: Text(n.label),
            // Rango % de copa colonizada (A2) — requisito de aceptación.
            subtitle: Text(
              n.rango,
              key: Key('g4_rango_${n.wire}'),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
