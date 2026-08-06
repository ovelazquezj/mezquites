import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../copy.dart';
import '../screens/welcome_screen.dart';

/// Tarjeta de "capturas por subir" (CR-031 W4).
///
/// Decisión **D5**: solo un **contador** y el botón "Subir ahora" — sin lista por
/// foto ni miniaturas. El contador incluye TODO lo que falta, también lo que quedó
/// marcado para atención, así que el número nunca miente.
///
/// ⚠️ Gate #9 / Q5.A-D1: todo el texto habla de **subir**, nunca de revisar. El
/// voluntario tiene que poder distinguir tres cosas: *en tu teléfono* (esta
/// tarjeta) → *subida, en revisión* (CR-030, tarjeta "Tu aporte") → *confirmada*.
///
/// Se auto-oculta cuando no hay nada pendiente: en el caso normal no estorba.
class PendingUploadsCard extends ConsumerWidget {
  const PendingUploadsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(pendingQueueProvider);
    final theme = Theme.of(context);

    if (!estado.hayPendientes && !estado.sesionExpirada) {
      return const SizedBox.shrink();
    }

    final avisoAlto = estado.pendientes >= Copy.pendingWarnHighAt;
    final aviso = estado.pendientes >= Copy.pendingWarnAt;

    return Card(
      key: const Key('pending_uploads_card'),
      color: avisoAlto ? theme.colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  estado.subiendo
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_off_outlined,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Copy.pendingCount(estado.pendientes),
                    key: const Key('pending_count'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(Copy.pendingNote, style: theme.textTheme.bodySmall),

            // Aviso por acumulación (D2). NUNCA impide capturar (gate #3): esto es
            // texto, no un bloqueo.
            if (aviso)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  avisoAlto
                      ? Copy.pendingWarningHigh(estado.pendientes)
                      : Copy.pendingWarning(estado.pendientes),
                  key: const Key('pending_warning'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),

            // La sesión venció: la cola NO se perdió, solo hay que volver a entrar.
            // CR-035: esta tarjeta (flag de la cola, tras un 401 del motor) y el
            // banner global (flag `sessionExpiredProvider`) son dos vistas del
            // MISMO hecho y se apagan juntos: cualquier cambio de sesión limpia
            // ambos (ver el listen de `pendingQueueProvider`).
            if (estado.sesionExpirada) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  Copy.pendingSessionExpired,
                  key: const Key('pending_session_expired'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('pending_relogin'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WelcomeScreen(),
                    ),
                  ),
                  child: const Text(Copy.sessionExpiredRelogin),
                ),
              ),
            ],

            // Alguna no se pudo enviar por su contenido: con solo el contador (D5),
            // "Reportar un problema" es la vía para que el equipo la recupere.
            if (estado.necesitanAtencion > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  Copy.pendingNeedsAttention(estado.necesitanAtencion),
                  key: const Key('pending_needs_attention'),
                  style: theme.textTheme.bodySmall,
                ),
              ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('pending_upload_now'),
                onPressed: estado.subiendo
                    ? null
                    : () => ref.read(pendingQueueProvider.notifier).subirAhora(),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  estado.subiendo ? Copy.pendingUploading : Copy.pendingUploadNow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
