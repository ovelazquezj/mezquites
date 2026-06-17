import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/services/session_store.dart';
import 'package:mezquite_app/src/theme/design_tokens.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// CR-003 — Onboarding: 3 páginas con contenido exacto, omitible y una sola vez
/// (gate #3). El flag es un booleano local sin PII (gate #2).
void main() {
  late DesignTokens tokens;

  setUp(() {
    tokens = loadTokensFromDisk();
  });

  Future<SessionStore> storeWith({bool onboardingSeen = false}) async {
    SharedPreferences.setMockInitialValues(
      onboardingSeen ? {'onboarding_seen': true} : {},
    );
    return SessionStore.create();
  }

  Widget app(SessionStore store) => wrap(
        OnboardingScreen(onDone: () {}),
        tokens: tokens,
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          designTokensProvider.overrideWith((ref) async => tokens),
        ],
      );

  testWidgets('muestra las 3 páginas con el contenido EXACTO del CR §5.5',
      (tester) async {
    final store = await storeWith();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();

    // P1 visible al arranque.
    expect(find.text('PASO 1 · MESES 1-6'), findsOneWidget);
    expect(find.text('Concientizar'), findsOneWidget);
    expect(
      find.textContaining('Registra mezquites de tu comunidad'),
      findsOneWidget,
    );

    // Dots: 3 y botón "Siguiente" en la primera.
    expect(find.byKey(const Key('onboarding_dot_0')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_dot_2')), findsOneWidget);
    expect(find.text(Copy.onboardingNext), findsOneWidget);
    expect(find.text(Copy.onboardingStart), findsNothing);

    // Avanza a P2.
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('PASO 2 · MESES 7-14'), findsOneWidget);
    expect(find.text('Capacitar'), findsOneWidget);
    expect(find.textContaining('Toma microcursos'), findsOneWidget);

    // Avanza a P3: el botón pasa a "Comenzar".
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('PASO 3 · MESES 15-24'), findsOneWidget);
    expect(find.text('Combatir'), findsOneWidget);
    expect(find.textContaining('Tu evidencia ciudadana llega'), findsOneWidget);
    expect(find.text(Copy.onboardingStart), findsOneWidget);
    expect(find.text(Copy.onboardingNext), findsNothing);
  });

  testWidgets('"Comenzar" marca el flag (persistente, una sola vez)',
      (tester) async {
    final store = await storeWith();
    expect(store.onboardingSeen, isFalse);

    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();

    // Ir hasta la última página.
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    // "Comenzar".
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();

    expect(store.onboardingSeen, isTrue);
  });

  testWidgets('"Saltar" marca el flag sin recorrer las páginas (omitible)',
      (tester) async {
    final store = await storeWith();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding_skip')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();

    expect(store.onboardingSeen, isTrue);
  });

  testWidgets('el provider del flag refleja el estado persistido',
      (tester) async {
    // Con el flag ya marcado, el provider arranca en true (no se vuelve a mostrar).
    final seenStore = await storeWith(onboardingSeen: true);
    final container = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(seenStore)],
    );
    addTearDown(container.dispose);
    expect(container.read(onboardingSeenProvider), isTrue);

    // Con el flag ausente, arranca en false (se mostrará una vez).
    final freshStore = await storeWith();
    final container2 = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(freshStore)],
    );
    addTearDown(container2.dispose);
    expect(container2.read(onboardingSeenProvider), isFalse);
  });
}
