import 'package:flutter/material.dart';

import '../ui/copy.dart';

/// Acerca de (CR-013): nombre del proyecto, versión visible (`beta-2606`),
/// aviso de copyright a nombre de la organización responsable ($orgName) y
/// crédito de autoría (desarrollo) con correo de contacto. Es metadato del
/// proyecto, no PII de una persona (gate #2 intacto). Visible a toda la consola.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('about-content'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.aboutTitle, style: theme.textTheme.displayLarge),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En el área de contenido (fondo claro) el logo de letras navy es
                // legible; el header navy usa la variante blanca (CR-012).
                Image.asset(
                  'assets/branding/logo_horizontal.png',
                  height: 56,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                Text(Copy.projectName, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _Row(label: Copy.aboutVersionLabel, value: Copy.appVersion),
                const SizedBox(height: 8),
                Text(
                  Copy.copyrightNotice,
                  key: const Key('about-copyright'),
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Copy.aboutAuthorLabel, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(Copy.authorName, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                SelectableText(
                  Copy.authorEmail,
                  key: const Key('about-author-email'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Copy.aboutLicenseLabel, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(Copy.aboutLicenseValue, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(Copy.aboutLicenseNote, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('about-licenses'),
                  icon: const Icon(Icons.article_outlined),
                  label: const Text(Copy.aboutLicensesButton),
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: Copy.projectName,
                    applicationVersion: Copy.appVersion,
                    applicationLegalese: Copy.copyrightNotice,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
