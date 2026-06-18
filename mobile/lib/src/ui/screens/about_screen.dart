import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';

/// Acerca de (CR-013): nombre del proyecto, versión visible (`beta-2606`),
/// aviso de copyright a nombre de la organización responsable ($orgName) y
/// crédito de autoría (desarrollo) con correo de contacto. La autoría/copyright
/// es metadato del proyecto, no PII de una persona voluntaria (gate #2 intacto).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _emailAuthor() async {
    final uri = Uri(scheme: 'mailto', path: Copy.authorEmail);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const BrandedAppBar(title: Copy.aboutTitle),
      body: ListView(
        key: const Key('about_content'),
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/branding/logo_horizontal.png',
                    height: 64,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 16),
                Text(Copy.projectName, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                StatTile(
                  label: Copy.aboutVersionLabel,
                  value: Copy.appVersion,
                ),
                const SizedBox(height: 8),
                Text(
                  Copy.copyrightNotice,
                  key: const Key('about_copyright'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          SectionCard(
            title: Copy.aboutAuthorLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Copy.authorName, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 4),
                InkWell(
                  key: const Key('about_author_email'),
                  onTap: _emailAuthor,
                  child: Text(
                    Copy.authorEmail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: Copy.aboutLicenseLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Copy.aboutLicenseValue, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const InfoNote(Copy.aboutLicenseNote),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('about_licenses'),
                    icon: const Icon(Icons.article_outlined),
                    label: const Text(Copy.aboutLicensesButton),
                    onPressed: () => showLicensePage(
                      context: context,
                      applicationName: Copy.projectName,
                      applicationVersion: Copy.appVersion,
                      applicationLegalese: Copy.copyrightNotice,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
