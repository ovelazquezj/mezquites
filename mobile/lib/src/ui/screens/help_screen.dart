import 'package:flutter/material.dart';

import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';
import '../widgets/disclaimer_dialog.dart';
import 'legal_screen.dart';

/// Ayuda. El disclaimer D1 es CONSULTABLE aquí en todo momento (Q7), con el
/// mismo contenido que se mostró una vez tras crear cuenta. Desde aquí también
/// se consultan los Términos y el Aviso de privacidad (CR-006 §4.3).
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandedAppBar(title: Copy.helpTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionCard(
            title: 'Sobre el proyecto',
            child: Text(Copy.aboutBoundary),
          ),
          const SectionCard(
            title: 'Privacidad',
            child: Text(Copy.noPiiNote),
          ),
          // Enlace a Términos y Aviso de privacidad (CR-006 §4.3, gate #3).
          Card(
            child: ListTile(
              key: const Key('help_legal_link'),
              leading: const Icon(Icons.description_outlined),
              title: const Text(Copy.legalTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => LegalScreen.open(context),
            ),
          ),
          // Disclaimer D1 consultable en todo momento (Q7).
          // DisclaimerView ya renderiza su propio título + cuerpo.
          const SectionCard(
            key: Key('help_disclaimer'),
            child: DisclaimerView(),
          ),
        ],
      ),
    );
  }
}
