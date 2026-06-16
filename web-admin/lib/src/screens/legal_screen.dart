import 'package:flutter/material.dart';

import '../ui/copy.dart';

/// Legal (CR-006): Términos y Condiciones + Aviso de privacidad, accesibles desde
/// la consola del consorcio. Es un **BORRADOR** (lo marca el badge) sujeto a
/// revisión legal del consorcio; no es asesoría legal. La fuente completa vive en
/// `docs/legal/terminos.md` y `docs/legal/aviso-privacidad.md`; aquí se muestra un
/// resumen accesible de las secciones clave (incluye derechos ARCO y obfuscación
/// a 1 km del gate #5). No introduce PII (gate #2).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.navLegal, style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(Copy.legalIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        _DraftBadge(),
        const SizedBox(height: 16),

        // --- Términos y Condiciones ---
        _LegalCard(
          keyValue: const Key('legal-terms'),
          title: Copy.legalTermsTitle,
          source: 'docs/legal/terminos.md',
          sections: const [
            _Section('Qué es y qué no es',
                'Plataforma de ciencia ciudadana del mezquite y sus parásitos. '
                    'Sirve para documentar y publicar el dato ecológico; no es una '
                    'herramienta de tratamiento de los árboles ni emite '
                    'recomendaciones químicas/mecánicas automáticas. La '
                    'participación es abierta, sin niveles ni certificaciones '
                    'obligatorias.'),
            _Section('Tu cuenta',
                'El voluntario inicia sesión con Google; se guarda solo un '
                    'identificador opaco (sin nombre ni correo) y un usuario '
                    'seudónimo. Las cuentas del equipo las crea el administrador.'),
            _Section('Captura',
                'Solo con la cámara del dispositivo (galería deshabilitada). La '
                    'especie y el nivel de afectación son autodeclarados. Un '
                    'evaluador humano puede confirmar o retirar una observación.'),
            _Section('Privacidad de la ubicación',
                'La ubicación pública nunca es más precisa que ~1 km; las '
                    'coordenadas exactas solo las ven aliados firmantes autorizados.'),
            _Section('Tus derechos (ARCO)',
                'Puedes solicitar la cancelación de tu cuenta: tu identidad se '
                    'elimina y tus observaciones se anonimizan (el dato ecológico se '
                    'conserva). Ver el Aviso de privacidad.'),
          ],
        ),
        const SizedBox(height: 16),

        // --- Aviso de privacidad ---
        _LegalCard(
          keyValue: const Key('legal-privacy'),
          title: Copy.legalPrivacyTitle,
          source: 'docs/legal/aviso-privacidad.md',
          sections: const [
            _Section('Datos que se recaban',
                'Voluntario: solo un identificador opaco del proveedor (sin '
                    'nombre/correo) y un usuario seudónimo. Administrador: usuario y '
                    'correo (solo este rol, para recuperar acceso). Evaluador/Analista: '
                    'usuario y contraseña, sin correo. Contraseñas cifradas (argon2).'),
            _Section('Finalidad',
                'Operar la plataforma de ciencia ciudadana y publicar el dato '
                    'ecológico agregado del mezquite con fines de investigación, '
                    'educación y gestión ambiental. Sin mercadotecnia ni '
                    'perfilamiento comercial.'),
            _Section('No venta ni cesión indebida',
                'El consorcio no vende tus datos ni los cede con fines '
                    'comerciales. El dato abierto va agregado, seudonimizado y con '
                    'la ubicación obfuscada a ~1 km.'),
            _Section('Conservación',
                'La identidad se conserva mientras exista la cuenta; el dato '
                    'ecológico puede conservarse indefinidamente (anonimizado al '
                    'cancelar la cuenta). Las auditorías se guardan sin datos '
                    'personales.'),
            _Section('Derechos ARCO y cómo ejercerlos',
                'Acceso, Rectificación, Cancelación y Oposición. Hoy la '
                    'Cancelación (eliminar cuenta) la ejecuta el administrador desde '
                    'esta consola; el resto se atiende caso por caso. Para ejercerlos, '
                    'contacta al consorcio a través del administrador de la plataforma.'),
            _Section('Contacto',
                'Consorcio del mezquite, a través del administrador de la '
                    'plataforma. El medio de contacto oficial queda pendiente de '
                    'definición por el consorcio.'),
          ],
        ),
      ],
    );
  }
}

class _DraftBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('legal-draft-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_outlined,
              color: theme.colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              Copy.legalDraftBadge,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section {
  const _Section(this.title, this.body);
  final String title;
  final String body;
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({
    required this.keyValue,
    required this.title,
    required this.source,
    required this.sections,
  });

  final Key keyValue;
  final String title;
  final String source;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: keyValue,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Fuente: $source',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 12),
            for (final s in sections) ...[
              Text(s.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(s.body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
