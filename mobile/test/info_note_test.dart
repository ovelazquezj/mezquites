import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mezquite_app/src/ui/widgets/common.dart';

/// CR-021 — los avisos informativos (`InfoNote`) son DESCARTABLES (botón "X") y
/// recuerdan el descarte. Cerrarlos no bloquea nada (gate #3, es informativo).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('InfoNote es descartable: la "X" lo oculta', (tester) async {
    await tester.pumpWidget(wrap(const InfoNote('Aviso de prueba')));
    await tester.pumpAndSettle();

    expect(find.text('Aviso de prueba'), findsOneWidget);
    expect(find.byKey(const Key('info_note_dismiss')), findsOneWidget);

    await tester.tap(find.byKey(const Key('info_note_dismiss')));
    await tester.pumpAndSettle();

    expect(find.text('Aviso de prueba'), findsNothing);
  });

  testWidgets('InfoNote(dismissible: false) no muestra la "X"', (tester) async {
    await tester.pumpWidget(wrap(const InfoNote('Aviso fijo', dismissible: false)));
    await tester.pumpAndSettle();

    expect(find.text('Aviso fijo'), findsOneWidget);
    expect(find.byKey(const Key('info_note_dismiss')), findsNothing);
  });

  testWidgets('InfoNote recuerda el descarte al volver a montarse', (tester) async {
    await tester.pumpWidget(wrap(const InfoNote('Recordado', id: 'nota_test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('info_note_dismiss')));
    await tester.pumpAndSettle();

    // Re-montar un InfoNote con el mismo id debe arrancar oculto.
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(wrap(const InfoNote('Recordado', id: 'nota_test')));
    await tester.pumpAndSettle();

    expect(find.text('Recordado'), findsNothing);
  });
}
