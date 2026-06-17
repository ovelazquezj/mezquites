import 'package:flutter/material.dart';

import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';

/// Pantalla legal (CR-006 §4.3): Términos y Condiciones + Aviso de privacidad.
///
/// Es **informativa** (gate #3): no bloquea ninguna funcionalidad de la app y
/// es consultable en todo momento desde Ayuda y desde la Bienvenida. El texto
/// es un **BORRADOR sujeto a revisión legal de la organización responsable** (no asesoría legal);
/// vive en `copy.dart` como copia que la app muestra al voluntario, mientras la
/// fuente canónica se redacta en `docs/legal/`.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  /// Helper de navegación: enlaces discretos abren esta pantalla.
  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LegalScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandedAppBar(title: Copy.legalTitle),
      body: ListView(
        key: const Key('legal_content'),
        padding: const EdgeInsets.all(16),
        children: const [
          // Marca el carácter de borrador, sin condicionar el uso (gate #3).
          InfoNote(Copy.legalDraftBanner),
          SizedBox(height: 12),
          SectionCard(
            key: Key('legal_terms'),
            title: Copy.termsTitle,
            child: Text(Copy.termsBody),
          ),
          SectionCard(
            key: Key('legal_privacy'),
            title: Copy.privacyTitle,
            child: Text(Copy.privacyBody),
          ),
        ],
      ),
    );
  }
}
