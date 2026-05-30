import 'package:flutter/material.dart';

import '../copy.dart';

/// Disclaimer D1 (Q7). Se muestra UNA sola vez tras crear cuenta; se descarta
/// con UN tap; persiste tras descartar (la persistencia la hace SessionStore);
/// y es consultable desde Ayuda en todo momento (mismo contenido).
class DisclaimerView extends StatelessWidget {
  const DisclaimerView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('disclaimer_content'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Copy.disclaimerTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(Copy.disclaimerBody, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// Muestra el disclaimer como diálogo descartable con UN tap.
/// Devuelve un Future que completa cuando el usuario lo descarta.
Future<void> showDisclaimerDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      key: const Key('disclaimer_dialog'),
      content: const SingleChildScrollView(child: DisclaimerView()),
      actions: [
        // UN tap descarta (Q7).
        FilledButton(
          key: const Key('disclaimer_dismiss'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text(Copy.disclaimerDismiss),
        ),
      ],
    ),
  );
}
