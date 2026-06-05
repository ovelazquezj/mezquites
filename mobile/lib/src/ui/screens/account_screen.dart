import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/common.dart';
import 'welcome_screen.dart';

/// Cuenta (Q5.D, Q4): muestra el handle (sin PII), afiliación, y cierre de
/// sesión. La afiliación a institución se elige en el alta; aquí se consulta y
/// se ofrece "solicitar agregar" (ticket).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(Copy.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoNote(Copy.noPiiNote),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Tu usuario',
            child: Text(
              session?.handle ?? '—',
              style: theme.textTheme.titleLarge,
            ),
          ),
          SectionCard(
            title: 'Institución',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La afiliación se elige al crear la cuenta. Si tu institución '
                  'no aparecía, puedes solicitar agregarla.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('account_request_institution'),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Tu solicitud para agregar una institución será revisada '
                        'por el consorcio.',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Solicitar agregar institución'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('logout_button'),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
