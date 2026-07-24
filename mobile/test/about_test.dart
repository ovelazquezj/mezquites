import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/about_screen.dart';

import 'helpers.dart';

/// CR-013 — Acerca de en la app del voluntario: nombre del proyecto, versión
/// visible (`beta-2606`), copyright del Club y crédito de autoría con correo.
/// La autoría/copyright es metadato del proyecto, no PII de una persona (gate #2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Acerca de muestra proyecto, versión, copyright del Club y autoría',
      (tester) async {
    await tester.pumpWidget(wrap(const AboutScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about_content')), findsOneWidget);

    // Nombre del proyecto y versión visible.
    expect(find.text(Copy.projectName), findsOneWidget);
    expect(find.text('beta-2606'), findsOneWidget);
    expect(find.text(Copy.appVersion), findsOneWidget);

    // Copyright a nombre de la organización responsable (el Club).
    final copyright = find.byKey(const Key('about_copyright'));
    expect(copyright, findsOneWidget);
    expect(find.textContaining('Club Rotario Bosques Aguascalientes'),
        findsWidgets);

    // Autoría: nombre + correo de contacto del autor.
    expect(find.text('Omar Velázquez'), findsOneWidget);
    expect(find.byKey(const Key('about_author_email')), findsOneWidget);
    expect(find.text('contacto@rescatando-el-mezquite.org'), findsOneWidget);

    // Licencia MIT declarada.
    expect(find.text('MIT'), findsOneWidget);
    expect(find.byKey(const Key('about_licenses')), findsOneWidget);
  });
}
