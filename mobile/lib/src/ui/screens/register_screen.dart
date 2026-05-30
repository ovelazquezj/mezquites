import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/common.dart';
import 'backup_code_screen.dart';

/// Alta de cuenta seudonimizada (gate #2, Q5.D): SOLO handle, sin email/teléfono/
/// nombre. Sin verificación de tutor (menores M1: registro abierto).
///
/// El usuario puede elegir institución (lista F3) o quedar "Independiente".
/// La lista solo está disponible si el backend expone un catálogo accesible;
/// de lo contrario, "Independiente" + "solicitar agregar" (ticket).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  Institution? _selected;
  bool _submitting = false;
  String? _error;
  List<Institution> _institutions = const [];

  @override
  void initState() {
    super.initState();
    _loadInstitutions();
  }

  Future<void> _loadInstitutions() async {
    try {
      final list = await ref.read(apiClientProvider).listInstitutions();
      if (mounted) setState(() => _institutions = list);
    } catch (_) {
      // Sin catálogo accesible: queda "Independiente".
    }
  }

  Future<void> _register() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await ref
          .read(authProvider.notifier)
          .register(institutionId: _selected?.id);
      if (!mounted) return;
      // Muestra el código de respaldo (una vez) y, tras él, el disclaimer D1.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BackupCodeScreen(session: session),
        ),
      );
    } catch (e) {
      setState(() => _error = 'No se pudo crear la cuenta. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoNote(Copy.noPiiNote),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Afiliación (opcional)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<Institution?>(
                  key: const Key('institution_dropdown'),
                  value: _selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Institución',
                  ),
                  items: [
                    const DropdownMenuItem<Institution?>(
                      value: null,
                      child: Text('Independiente'),
                    ),
                    ..._institutions.map(
                      (i) => DropdownMenuItem<Institution?>(
                        value: i,
                        child: Text(i.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selected = v),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('request_institution'),
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
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          FilledButton(
            key: const Key('submit_register'),
            onPressed: _submitting ? null : _register,
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Crear handle y continuar'),
          ),
        ],
      ),
    );
  }
}
