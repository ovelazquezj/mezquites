import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../models/municipios.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';
import 'evidence_screen.dart';
import 'welcome_screen.dart';

/// Cuenta (Q5.D, Q4): muestra el handle (sin PII), afiliación, comprobante de
/// participación (CR-010 #7) y cierre de sesión. Desde aquí el voluntario puede
/// **registrar una nueva institución** (CR-010 #6): queda `solicitada` hasta que
/// el consorcio la apruebe.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const BrandedAppBar(title: Copy.accountTitle),
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
            title: Copy.institutionSectionTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Copy.institutionSectionNote,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('account_request_institution'),
                  onPressed: () => _openRequestInstitution(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text(Copy.institutionRequestButton),
                ),
              ],
            ),
          ),
          // Comprobante de participación (CR-010 #7).
          SectionCard(
            title: Copy.evidenceTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Copy.evidenceNote, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('account_open_evidence'),
                  onPressed: () => EvidenceScreen.open(context),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text(Copy.evidenceOpen),
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

  Future<void> _openRequestInstitution(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final registrada = await showDialog<Institution>(
      context: context,
      builder: (_) => const _RequestInstitutionDialog(),
    );
    if (registrada != null && context.mounted) {
      // CR-028: si el backend reusó una institución existente no hubo "solicitud" que revisar;
      // decirlo evita que la persona espere una aprobación que nunca va a llegar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(registrada.yaExistia
              ? Copy.institutionRequestAlreadyExisted
              : Copy.institutionRequestOk),
        ),
      );
    }
  }
}

/// Diálogo de "Registrar nueva institución" (CR-010 #6): nombre + estado →
/// `POST /institutions/request`. Al cerrar devuelve la institución resultante (creada o, si ya
/// existía una con el mismo nombre, la existente a la que quedó afiliada la cuenta — CR-028).
class _RequestInstitutionDialog extends ConsumerStatefulWidget {
  const _RequestInstitutionDialog();

  @override
  ConsumerState<_RequestInstitutionDialog> createState() =>
      _RequestInstitutionDialogState();
}

class _RequestInstitutionDialogState
    extends ConsumerState<_RequestInstitutionDialog> {
  final _nameController = TextEditingController();
  String _estado = kEstadoDefault;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = Copy.institutionRequestNameRequired);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final inst = await ref
          .read(apiClientProvider)
          .requestInstitution(name: name, estado: _estado);
      if (!mounted) return;
      Navigator.of(context).pop(inst);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = Copy.institutionRequestError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text(Copy.institutionRequestTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('institution_name_field'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: Copy.institutionRequestNameLabel,
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('institution_estado_field'),
            value: _estado,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: Copy.institutionRequestEstadoLabel,
            ),
            items: kEstados
                .map((e) =>
                    DropdownMenuItem<String>(value: e, child: Text(e)),)
                .toList(),
            onChanged: (v) => setState(() => _estado = v ?? kEstadoDefault),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const Key('institution_request_error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('institution_request_cancel'),
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text(Copy.institutionRequestCancel),
        ),
        FilledButton(
          key: const Key('institution_request_submit'),
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(Copy.institutionRequestSubmit),
        ),
      ],
    );
  }
}
