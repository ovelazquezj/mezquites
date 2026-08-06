import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/capture_service.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/pending_uploads_card.dart';
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
  const CaptureScreen({super.key, @visibleForTesting this.initialShot});

  /// SOLO pruebas (CR-035): arranca con una captura ya hecha para poder ejercitar
  /// el flujo de `_submit` (formulario → SnackBar) sin cámara. En producción
  /// siempre es `null`: la única entrada real sigue siendo la cámara (gate #4).
  final CaptureResult? initialShot;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  late CaptureResult? _shot = widget.initialShot;

  void _onCaptured(CaptureResult result) => setState(() => _shot = result);

  /// Guarda la captura en el dispositivo y **luego** intenta subirla (CR-031).
  ///
  /// Antes esto era fire-and-forget: se mostraba "Observación registrada y
  /// aceptada" **antes** de que el servidor respondiera y `.catchError((_) {})` se
  /// tragaba el fallo, así que una captura sin red se perdía con mensaje de éxito.
  /// Ahora la foto queda **guardada primero** —eso nunca falla estando el
  /// almacenamiento disponible— y el mensaje dice lo que de verdad pasó.
  Future<void> _submit(ObservationDraft draft) async {
    // Libera la vista de inmediato: el voluntario puede seguir capturando aunque
    // la subida tarde (gate #3: nada se bloquea).
    setState(() => _shot = null);
    final queue = ref.read(pendingQueueProvider.notifier);
    try {
      final subida = await queue.registrar(draft);
      if (!mounted) return;
      ref.invalidate(myObservationsProvider);
      // CR-035: si no subió POR la sesión vencida, el texto no puede prometer
      // "se enviará sola" — con 401 no se enviará hasta volver a entrar. Se
      // miran los dos flags (cola y global) porque cualquiera puede encenderse
      // primero según de dónde vino el 401.
      final sesionVencida = ref.read(pendingQueueProvider).sesionExpirada ||
          ref.read(sessionExpiredProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subida
                ? Copy.captureUploaded
                : sesionVencida
                    ? Copy.captureSavedSessionExpired
                    : Copy.captureSavedOffline,
          ),
        ),
      );
    } catch (_) {
      // Ni guardar funcionó (almacenamiento lleno o no disponible). Es lo único
      // que sí debe alarmar: la captura NO está a salvo en ninguna parte.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Copy.captureSaveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shot = _shot;
    return Scaffold(
      appBar: BrandedAppBar(
        title: Copy.captureTitle,
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
      body: Column(
        children: [
          // CR-031: aquí es donde el voluntario está cuando captura sin señal, así
          // que es donde tiene que ver qué falta por subir. Se auto-oculta cuando
          // no hay nada pendiente, para no restar espacio a la cámara.
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: PendingUploadsCard(),
          ),
          Expanded(
            child: shot != null
                ? ObservationForm(capture: shot, onSubmit: _submit)
                : CapturePane(onCaptured: _onCaptured),
          ),
        ],
      ),
    );
  }
}
