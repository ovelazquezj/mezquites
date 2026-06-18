import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mezquite_web_admin/src/screens/about_screen.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

/// CR-013 — Acerca de en la consola: nombre del proyecto, versión visible
/// (`beta-2606`), copyright del Club y crédito de autoría con correo. Es
/// metadato del proyecto, no PII de una persona (gate #2 intacto).
void main() {
  testWidgets('Acerca de muestra proyecto, versión, copyright del Club y autoría',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AboutScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about-content')), findsOneWidget);

    // Nombre del proyecto y versión visible.
    expect(find.text(Copy.projectName), findsOneWidget);
    expect(find.text('beta-2606'), findsOneWidget);

    // Copyright a nombre de la organización responsable (el Club).
    expect(find.byKey(const Key('about-copyright')), findsOneWidget);
    expect(find.textContaining('Club Rotario Bosques Aguascalientes'),
        findsWidgets);

    // Autoría: nombre + correo de contacto del autor.
    expect(find.text('Omar Velázquez'), findsOneWidget);
    expect(find.byKey(const Key('about-author-email')), findsOneWidget);
    expect(find.text('ovelazquezj@gmail.com'), findsOneWidget);

    // Licencia MIT declarada.
    expect(find.text('MIT'), findsOneWidget);
    expect(find.byKey(const Key('about-licenses')), findsOneWidget);
  });
}
