import 'package:flutter/material.dart';

import '../copy.dart';
import '../widgets/common.dart';
import '../widgets/disclaimer_dialog.dart';

/// Ayuda. El disclaimer D1 es CONSULTABLE aquí en todo momento (Q7), con el
/// mismo contenido que se mostró una vez tras crear cuenta.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Copy.helpTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SectionCard(
            title: 'Sobre el proyecto',
            child: Text(Copy.aboutBoundary),
          ),
          SectionCard(
            title: 'Privacidad',
            child: Text(Copy.noPiiNote),
          ),
          // Disclaimer D1 consultable en todo momento (Q7).
          // DisclaimerView ya renderiza su propio título + cuerpo.
          SectionCard(
            key: Key('help_disclaimer'),
            child: DisclaimerView(),
          ),
        ],
      ),
    );
  }
}
