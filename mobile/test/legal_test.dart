import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mezquite_app/src/api/api_client.dart';
import 'package:mezquite_app/src/services/session_store.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/help_screen.dart';
import 'package:mezquite_app/src/ui/screens/legal_screen.dart';
import 'package:mezquite_app/src/ui/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// CR-006 §4.3 — Términos y Aviso de privacidad accesibles en la app del
/// voluntario (AC4): desde Ayuda y con un enlace discreto en la Bienvenida.
/// Es contenido INFORMATIVO (gate #3, no bloquea). Los textos fueron APROBADOS
/// por la organización (CR-020): ya no se muestra el banner de borrador.
/// Gate #2 acotado: el aviso no expone PII.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LegalScreen ya no muestra borrador; sí Términos y Aviso de privacidad',
      (tester) async {
    await tester.pumpWidget(wrap(const LegalScreen()));
    await tester.pumpAndSettle();

    // Textos APROBADOS (CR-020): ya no hay banner de borrador.
    expect(find.textContaining('BORRADOR'), findsNothing);

    // Términos arriba (visible al arranque).
    expect(find.byKey(const Key('legal_terms')), findsOneWidget);
    expect(find.text(Copy.termsTitle), findsOneWidget);

    // El Aviso de privacidad está más abajo: hay que desplazar el ListView.
    await tester.scrollUntilVisible(
      find.byKey(const Key('legal_privacy')),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('legal_privacy')), findsOneWidget);
    expect(find.text(Copy.privacyTitle), findsOneWidget);

    // El Aviso cubre LFPDPPP y los derechos ARCO (CR-006 §4.3).
    expect(find.textContaining('LFPDPPP'), findsOneWidget);
    expect(find.textContaining('Derechos ARCO'), findsOneWidget);
  });

  testWidgets('el aviso no expone PII (gate #2 acotado): id opaco, sin correo/nombre',
      (tester) async {
    // El texto en runtime es el mismo que muestra la app.
    final privacy = Copy.privacyBody.toLowerCase();
    expect(privacy.contains('identificador opaco'), isTrue);
    // No guardamos correo/nombre/teléfono: el texto lo declara en negativo.
    expect(privacy.contains('no guardamos tu correo'), isTrue);
    // El cuerpo no incluye datos personales reales.
    expect(
      Copy.privacyBody.contains('contacto@rescatando-el-mezquite.org'),
      isTrue,
      reason: 'el contacto es del Club (organización responsable), no un dato del voluntario',
    );
  });

  testWidgets('Ayuda enlaza a Términos y privacidad (AC4)', (tester) async {
    await tester.pumpWidget(wrap(const HelpScreen()));
    await tester.pumpAndSettle();

    final link = find.byKey(const Key('help_legal_link'));
    expect(link, findsOneWidget);

    await tester.tap(link);
    await tester.pumpAndSettle();

    // Navegó a la pantalla legal (Términos visible al arranque).
    expect(find.byKey(const Key('legal_content')), findsOneWidget);
    expect(find.text(Copy.termsTitle), findsOneWidget);
  });

  testWidgets('Bienvenida tiene enlace discreto de consentimiento que abre lo legal (AC4)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await SessionStore.create();
    // API mockeada: sin catálogo de instituciones (Bienvenida lo tolera).
    final mock = MockClient((req) async => http.Response('[]', 200));
    final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

    await tester.pumpWidget(
      wrap(
        const WelcomeScreen(),
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(api),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // El copy de consentimiento aparece cerca de "Entrar con Google".
    expect(find.text(Copy.signInWithGoogle), findsOneWidget);
    final consent = find.byKey(const Key('legal_consent_link'));
    expect(consent, findsOneWidget);
    expect(find.text(Copy.legalConsentNote), findsOneWidget);

    await tester.ensureVisible(consent);
    await tester.pumpAndSettle();
    await tester.tap(consent);
    await tester.pumpAndSettle();

    // Abre la pantalla legal (gate #3: informativo, no bloquea el login).
    expect(find.byKey(const Key('legal_content')), findsOneWidget);
    expect(find.text(Copy.termsTitle), findsOneWidget);
  });
}
