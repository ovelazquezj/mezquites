import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/models/enums.dart';
import 'package:mezquite_app/src/ui/widgets/g4_selector.dart';

import 'helpers.dart';

/// Q3 / gate #8: selector G4 con EXACTAMENTE 4 opciones + rango % visible.
void main() {
  testWidgets('G4 expone exactamente 4 opciones', (tester) async {
    NivelG4? selected;
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: G4Selector(value: selected, onChanged: (v) => selected = v),
        ),
      ),
    );

    // Exactamente 4 tiles de opción.
    expect(find.byType(RadioListTile<NivelG4>), findsNWidgets(4));
    expect(G4Selector.options.length, 4);

    // Las 4 opciones canónicas presentes por key.
    for (final n in NivelG4.values) {
      expect(find.byKey(Key('g4_option_${n.wire}')), findsOneWidget);
    }
  });

  testWidgets('cada opción muestra su rango % de copa (A2)', (tester) async {
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: G4Selector(value: null, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.byKey(const Key('g4_rango_sano')), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('>0% – 25%'), findsOneWidget);
    expect(find.text('>25% – 50%'), findsOneWidget);
    expect(find.text('>50%'), findsOneWidget);
  });

  test('los wire coinciden con los Literal del backend', () {
    expect(NivelG4.values.map((e) => e.wire).toList(),
        ['sano', 'leve', 'moderado', 'severo'],);
  });

  testWidgets('seleccionar una opción dispara onChanged', (tester) async {
    NivelG4? selected;
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setState) => G4Selector(
              value: selected,
              onChanged: (v) => setState(() => selected = v),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('g4_option_moderado')));
    await tester.pump();
    expect(selected, NivelG4.moderado);
  });
}
