import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mezquite_web_admin/src/screens/legal_screen.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

/// CR-006 — AC4: Términos y Aviso de privacidad accesibles y marcados BORRADOR.

void main() {
  testWidgets('la pantalla Legal muestra Términos, Aviso y el sello de BORRADOR',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LegalScreen())),
    );
    await tester.pumpAndSettle();

    // Ambos documentos presentes.
    expect(find.byKey(const Key('legal-terms')), findsOneWidget);
    expect(find.byKey(const Key('legal-privacy')), findsOneWidget);
    expect(find.text(Copy.legalTermsTitle), findsOneWidget);
    expect(find.text(Copy.legalPrivacyTitle), findsOneWidget);

    // Marcado claramente como BORRADOR sujeto a revisión legal.
    expect(find.byKey(const Key('legal-draft-badge')), findsOneWidget);
    expect(find.text(Copy.legalDraftBadge), findsOneWidget);

    // Menciona derechos ARCO (cómo ejercerlos).
    expect(find.textContaining('ARCO'), findsWidgets);
  });
}
