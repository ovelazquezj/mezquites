import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../copy.dart';

/// Onboarding del primer arranque (CR-003 §5.5).
///
/// PageView de 3 páginas con dots, "Saltar" (omitible) y botón inferior
/// ("Siguiente" → "Comenzar"). Es informativo, NO bloquea funcionalidad ni
/// implica certificación (gate #3) y se muestra UNA sola vez: al "Saltar" o
/// "Comenzar" se marca el flag local (sin PII, gate #2) y se invoca [onDone].
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  /// Se llama cuando el usuario termina u omite el onboarding.
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = OnboardingPageData.pages;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    widget.onDone();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = ref.watch(designTokensProvider).valueOrNull;

    Color accentOf(String token) =>
        tokens != null ? Color(tokens.color(token)) : theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // "Saltar" (esquina superior derecha) — onboarding omitible (gate #3).
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: TextButton(
                  key: const Key('onboarding_skip'),
                  onPressed: _finish,
                  child: const Text(Copy.onboardingSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const Key('onboarding_pageview'),
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return _OnboardingPage(
                    data: page,
                    accent: accentOf(page.accentToken),
                  );
                },
              ),
            ),
            // Indicador de puntos.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    key: Key('onboarding_dot_$i'),
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onboarding_next'),
                  onPressed: _next,
                  child: Text(
                    _isLast ? Copy.onboardingStart : Copy.onboardingNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una página del onboarding: ilustración en widgets (sin SVG), eyebrow, título
/// con acento de marca y cuerpo. Texto y controles son widgets nativos (CR-003).
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.accent});

  final OnboardingPageData data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Illustration(accent: accent),
          const SizedBox(height: 40),
          Text(
            data.eyebrow,
            key: Key('onboarding_eyebrow_${data.title}'),
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.title,
            key: Key('onboarding_title_${data.title}'),
            style: theme.textTheme.displayLarge?.copyWith(color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            key: Key('onboarding_body_${data.title}'),
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Ilustración decorativa en widgets Flutter (sin assets/SVG). Un emblema
/// circular con un ícono de naturaleza teñido con el acento de la página.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Image.asset('assets/branding/emblema.png', width: 128),
        ),
      ),
    );
  }
}
