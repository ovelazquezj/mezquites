import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/common.dart';
import '../widgets/disclaimer_dialog.dart';
import 'heat_map_screen.dart';
import 'home_shell.dart';
import 'legal_screen.dart';

/// Pantalla de bienvenida + login (CR-002). Punto de entrada cuando no hay sesión.
///
/// Identidad real con "Entrar con Google" (gate #2 acotado: la app NO guarda email/nombre; el
/// backend solo conserva el `sub` opaco). Se retiró el alta por handle + código de respaldo / QR.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  Institution? _selected;
  List<Institution> _institutions = const [];
  bool _signingIn = false;
  String? _error;
  // CR-011 #5b: institución nueva a registrar desde el login (Option A: se solicita tras el login).
  String? _pendingNewInstitution;

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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _signingIn = true;
      _error = null;
    });
    final outcome = await ref
        .read(authProvider.notifier)
        .signInWithGoogle(institutionId: _selected?.id);
    if (!mounted) return;
    setState(() => _signingIn = false);

    switch (outcome) {
      case GoogleSignInOutcome.success:
        await _registerPendingInstitution();
        await _afterLogin();
        break;
      case GoogleSignInOutcome.cancelled:
        // El usuario cerró el diálogo de Google: sin error, sin navegación.
        break;
      case GoogleSignInOutcome.error:
        setState(() => _error = Copy.loginError);
        break;
    }
  }

  Future<void> _afterLogin() async {
    final store = ref.read(sessionStoreProvider);
    // Disclaimer D1: una sola vez tras iniciar sesión (Q7).
    if (!store.disclaimerSeen) {
      await showDisclaimerDialog(context);
      await store.markDisclaimerSeen();
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  /// CR-011 (decisión A): si el usuario eligió registrar una institución nueva,
  /// se solicita DESPUÉS del login (queda `solicitada` y se asocia a su cuenta).
  Future<void> _registerPendingInstitution() async {
    final name = _pendingNewInstitution;
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(apiClientProvider).requestInstitution(name: name);
    } catch (_) {
      // No bloquea el login; puede reintentarse desde Cuenta.
    }
  }

  Future<void> _promptNewInstitution() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(Copy.institutionRequestTitle),
        content: TextField(
          key: const Key('welcome_new_institution_field'),
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(labelText: Copy.institutionRequestNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(Copy.institutionRequestCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Usar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (name != null && name.isNotEmpty) {
      setState(() {
        _pendingNewInstitution = name;
        _selected = null; // registrar nueva ⇒ no se elige una existente
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Image.asset(
                'assets/branding/logo_horizontal.png',
                height: 84,
                semanticLabel: 'Proyecto Mezquite',
              ),
              const SizedBox(height: 8),
              Text(Copy.welcomeSubtitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const InfoNote(Copy.aboutBoundary),
              const SizedBox(height: 12),
              const InfoNote(Copy.googleSignInNote),
              const SizedBox(height: 16),
              // Afiliación opcional (lista F3); si no hay catálogo, queda "Independiente".
              DropdownButtonFormField<Institution?>(
                key: const Key('institution_dropdown'),
                value: _selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Institución (opcional)',
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
              // CR-011 #5b: registrar una institución que no está en el catálogo.
              if (_pendingNewInstitution == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('welcome_register_institution'),
                    onPressed: _signingIn ? null : _promptNewInstitution,
                    icon: const Icon(Icons.add),
                    label: const Text(Copy.institutionRequestButton),
                  ),
                )
              else
                Row(
                  children: [
                    const Icon(Icons.school_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Registrarás: $_pendingNewInstitution',
                          style: theme.textTheme.bodySmall),
                    ),
                    TextButton(
                      key: const Key('welcome_clear_new_institution'),
                      onPressed: () =>
                          setState(() => _pendingNewInstitution = null),
                      child: const Text('Quitar'),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('sign_in_google'),
                  onPressed: _signingIn ? null : _signInWithGoogle,
                  icon: _signingIn
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text(Copy.signInWithGoogle),
                ),
              ),
              const SizedBox(height: 8),
              // Entrada pública al mapa de calor SIN iniciar sesión (CR-009,
              // gate #3: abre siempre; los datos públicos no requieren auth).
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('open_public_map'),
                  onPressed: () => HeatMapScreen.openPublic(context),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text(Copy.publicMapButton),
                ),
              ),
              const SizedBox(height: 8),
              // Enlace discreto de consentimiento (CR-006 §4.3). Informativo:
              // NO bloquea el inicio de sesión (gate #3).
              Center(
                child: TextButton(
                  key: const Key('legal_consent_link'),
                  onPressed: () => LegalScreen.open(context),
                  child: Text(
                    Copy.legalConsentNote,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
