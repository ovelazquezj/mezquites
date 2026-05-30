import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/ui/screens/help_screen.dart';
import 'package:mezquite_app/src/ui/widgets/disclaimer_dialog.dart';

import 'helpers.dart';

/// Q7: disclaimer una vez tras crear cuenta; descarte con 1 tap; persiste tras
/// descartar; consultable desde Ayuda en todo momento.
void main() {
  testWidgets('el disclaimer se descarta con un solo tap', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await showDisclaimerDialog(context);
                  dismissed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // El diálogo se muestra.
    expect(find.byKey(const Key('disclaimer_dialog')), findsOneWidget);
    expect(find.byKey(const Key('disclaimer_content')), findsOneWidget);

    // UN solo tap lo descarta.
    await tester.tap(find.byKey(const Key('disclaimer_dismiss')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('disclaimer_dialog')), findsNothing);
    expect(dismissed, isTrue);
  });

  testWidgets('el disclaimer es consultable desde Ayuda', (tester) async {
    await tester.pumpWidget(wrap(const HelpScreen()));
    await tester.pumpAndSettle();

    // Mismo contenido del disclaimer disponible siempre en Ayuda.
    expect(find.byKey(const Key('help_disclaimer')), findsOneWidget);
    expect(find.byKey(const Key('disclaimer_content')), findsOneWidget);
  });
}
