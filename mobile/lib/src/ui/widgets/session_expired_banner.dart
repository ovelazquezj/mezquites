import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../copy.dart';
import '../screens/welcome_screen.dart';

/// Banner global de sesión vencida (CR-035).
///
/// Vive en el `HomeShell`, por ENCIMA de los AppBar internos de cada pestaña,
/// para que el aviso se vea desde las 4 pestañas sin repetirlo en cada una.
/// NO es descartable a propósito (por eso no usa `InfoNote`): mientras la
/// sesión siga vencida el hecho no cambia y ocultarlo devolvería el fallo
/// silencioso que este CR viene a quitar. Tampoco bloquea nada (gate #3): el
/// voluntario puede seguir capturando a su cola local y volver a entrar cuando
/// tenga señal — el botón hace `push` (no reemplaza la pila) para que "atrás"
/// regrese a donde estaba sin perder nada.
class SessionExpiredBanner extends ConsumerWidget {
  const SessionExpiredBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expirada = ref.watch(sessionExpiredProvider);
    if (!expirada) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // Misma paleta de aviso que la tarjeta de pendientes acumuladas
    // (`pending_uploads_card`): errorContainer = "atiéndelo", sin alarmar.
    return Material(
      key: const Key('session_expired_banner'),
      color: theme.colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_clock_outlined,
                    size: 20,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      Copy.sessionExpiredBanner,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  key: const Key('session_relogin'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WelcomeScreen(),
                    ),
                  ),
                  child: const Text(Copy.sessionExpiredRelogin),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
