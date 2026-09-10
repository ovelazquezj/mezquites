import 'package:flutter/material.dart';

import 'copy.dart';

/// Resultado del diálogo de confirmación de borrado: solo se construye al
/// confirmar (lleva el motivo capturado). `null` desde `showDialog` significa
/// que se canceló.
class ConfirmDeleteDecision {
  const ConfirmDeleteDecision(this.reason);

  final String reason;
}

/// Diálogo de confirmación para eliminar una cuenta, con motivo para la bitácora
/// de auditoría (gate #7). Lo comparten la pantalla ARCO de cancelación (CR-006)
/// y la de usuarios del equipo (CR-040): son la misma acción sobre el mismo
/// endpoint, así que deben pedir lo mismo y advertir lo mismo.
///
/// Gestiona su propio [TextEditingController] (lo descarta en `dispose`),
/// evitando usarlo tras liberarlo durante la animación de cierre.
///
/// [keyPrefix] compone las `Key`s de la ventana (`<prefijo>-confirm-dialog`,
/// `<prefijo>-reason`, `<prefijo>-confirm-cancel`, `<prefijo>-confirm-ok`) para
/// que cada pantalla conserve las suyas.
class ConfirmDeleteDialog extends StatefulWidget {
  const ConfirmDeleteDialog({
    super.key,
    required this.keyPrefix,
    required this.description,
  });

  final String keyPrefix;

  /// Qué se va a eliminar y qué consecuencias tiene, en texto llano.
  final String description;

  @override
  State<ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<ConfirmDeleteDialog> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.keyPrefix;
    return AlertDialog(
      key: Key('$p-confirm-dialog'),
      title: const Text(Copy.accountsConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            key: Key('$p-reason'),
            controller: _reasonCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: Copy.accountsReasonLabel,
              hintText: Copy.accountsReasonHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: Key('$p-confirm-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Copy.accountsConfirmCancel),
        ),
        FilledButton(
          key: Key('$p-confirm-ok'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          onPressed: () =>
              Navigator.of(context).pop(ConfirmDeleteDecision(_reasonCtrl.text)),
          child: const Text(Copy.accountsConfirmOk),
        ),
      ],
    );
  }
}
