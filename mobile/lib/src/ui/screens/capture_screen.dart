import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/capture_service.dart';
import '../../state/providers.dart';
import '../copy.dart';
import 'capture_pane.dart';
import 'help_screen.dart';
import 'observation_form.dart';

/// Pantalla de captura (gate #4, Q5.A): SOLO cámara.
///
/// NO existe botón/acción de galería en ninguna parte. La captura se delega a
/// [CapturePane], que por **import condicional** es:
///   - móvil nativo: cámara nativa con preview + EXIF real;
///   - web (teléfono/tablet): cámara del navegador (`image_picker`), por bytes.
///
/// El submit es fire-and-forget: encola localmente como "pendiente" y dispara el
/// POST sin bloquear la UI. NUNCA muestra estado de validación individual (gate #9).
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CaptureResult? _shot;

  void _onCaptured(CaptureResult result) => setState(() => _shot = result);

  /// Fire-and-forget: encola pendiente, dispara POST, no espera (Q5.A).
  void _submit(ObservationDraft draft) {
    final pending = MineObservation(
      observationId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      capturedAt: draft.capturedAt,
      nivelG4: draft.nivelG4.wire,
      flagCuscuta: draft.flagCuscuta,
      flagDanio: draft.flagDanio,
      tamanio: draft.tamanio.wire,
      contexto: draft.contexto.wire,
      pending: true,
    );
    ref.read(pendingQueueProvider.notifier).add(pending);

    // Dispara sin await (no bloquea la UI). Al confirmar, retira de pendientes.
    ref.read(apiClientProvider).submitObservation(draft).then((serverId) {
      ref.read(pendingQueueProvider.notifier).remove(pending.observationId);
      ref.invalidate(myObservationsProvider);
    }).catchError((_) {
      // Permanece "pendiente" para reintento; NO es estado de validación.
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Copy.captureQueued)),
    );
    setState(() => _shot = null); // listo para la siguiente
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot;
    return Scaffold(
      appBar: AppBar(
        title: const Text(Copy.captureTitle),
        actions: [
          IconButton(
            key: const Key('help_button'),
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
            ),
          ),
        ],
      ),
      body: shot != null
          ? ObservationForm(capture: shot, onSubmit: _submit)
          : CapturePane(onCaptured: _onCaptured),
    );
  }
}
