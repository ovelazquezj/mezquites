import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// Recuperación de cuenta por handle + código de respaldo (sin PII).
class RecoverScreen extends ConsumerStatefulWidget {
  const RecoverScreen({super.key});

  @override
  ConsumerState<RecoverScreen> createState() => _RecoverScreenState();
}

class _RecoverScreenState extends ConsumerState<RecoverScreen> {
  final _handle = TextEditingController();
  final _code = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).recover(
            handle: _handle.text.trim(),
            backupCode: _code.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = 'Handle o código inválido.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoNote(Copy.noPiiNote),
          const SizedBox(height: 16),
          TextField(
            key: const Key('recover_handle'),
            controller: _handle,
            decoration: const InputDecoration(labelText: 'Handle'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('recover_code'),
            controller: _code,
            decoration: const InputDecoration(labelText: 'Código de respaldo'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          FilledButton(
            key: const Key('submit_recover'),
            onPressed: _submitting ? null : _recover,
            child: const Text('Recuperar'),
          ),
        ],
      ),
    );
  }
}
