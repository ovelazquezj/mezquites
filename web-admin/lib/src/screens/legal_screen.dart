import 'package:flutter/material.dart';

import '../ui/copy.dart';

/// Legal (CR-006): Términos y Condiciones + Aviso de privacidad, accesibles desde
/// la consola de administración. **APROBADOS** por la organización responsable
/// (Aviso de privacidad 2026-06-25, Términos 2026-06-27; CR-020): ya no llevan
/// sello de borrador. La fuente completa vive en `docs/legal/terminos.md` y
/// `docs/legal/aviso-privacidad.md`; aquí se muestra un resumen accesible de las
/// secciones clave (incluye derechos ARCO y obfuscación a 300 m del gate #5,
/// enmendado por CR-009). No introduce PII (gate #2).
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
                'La ubicación pública nunca es más precisa que ~300 m; las '
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
                'El ${Copy.orgName} no vende tus datos ni los cede con fines '
                    'comerciales. El dato abierto va agregado, seudonimizado y con '
                    'la ubicación obfuscada a ~300 m.'),
            _Section('Conservación',
                'La identidad se conserva mientras exista la cuenta; el dato '
                    'ecológico puede conservarse indefinidamente (anonimizado al '
                    'cancelar la cuenta). Las auditorías se guardan sin datos '
                    'personales.'),
            _Section('Derechos ARCO y cómo ejercerlos',
                'Acceso, Rectificación, Cancelación y Oposición. Hoy la '
                    'Cancelación (eliminar cuenta) la ejecuta el administrador desde '
                    'esta consola; el resto se atiende caso por caso. Para ejercerlos, '
                    'contacta al ${Copy.orgName} a través del administrador de la plataforma.'),
            _Section('Contacto',
                'Para dudas de privacidad o ejercer tus derechos, escribe al '
                    '${Copy.orgName} (Paseo de la Asunción #305, Jardines de '
                    'Aguascalientes, C.P. 20270, Aguascalientes, México): '
                    'contacto@rescatando-el-mezquite.org.'),
          ],
        ),
      ],
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
