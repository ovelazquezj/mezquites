import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/common.dart';
import '../widgets/disclaimer_dialog.dart';
import 'home_shell.dart';

/// Muestra el código de respaldo UNA sola vez (recuperación sin PII).
/// QR + texto. Tras continuar, dispara el disclaimer D1 (una vez) y entra al app.
class BackupCodeScreen extends ConsumerWidget {
  const BackupCodeScreen({super.key, required this.session});

  final AuthSession session;

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final store = ref.read(sessionStoreProvider);
    // Disclaimer D1: una sola vez tras crear cuenta.
    if (!store.disclaimerSeen) {
      await showDisclaimerDialog(context);
      await store.markDisclaimerSeen();
    }
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final code = session.backupCode ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text(Copy.backupTitle),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoNote(Copy.backupNote),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Tu handle',
            child: SelectableText(
              session.handle,
              key: const Key('handle_value'),
              style: theme.textTheme.titleLarge,
            ),
          ),
          SectionCard(
            title: 'Código de respaldo',
            child: Column(
              children: [
                Center(
                  child: QrImageView(
                    data: 'mezquite://recover?handle=${session.handle}'
                        '&code=$code',
                    size: 180,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  code,
                  key: const Key('backup_code_value'),
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('backup_continue'),
            onPressed: () => _continue(context, ref),
            child: const Text('Ya lo guardé, continuar'),
          ),
        ],
      ),
    );
  }
}
