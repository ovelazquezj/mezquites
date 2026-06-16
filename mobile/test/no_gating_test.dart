import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/ui/screens/learning_screen.dart';

import 'helpers.dart';

/// Gate #3 / Q5.C: sin gating. Ningún módulo de Aprendizaje se bloquea por
/// nivel/capacitación; no hay tiers/certificados que bloqueen funciones.
void main() {
  testWidgets('todos los módulos de Aprendizaje son abribles (sin bloqueo)',
      (tester) async {
    // Superficie alta: la lista (lazy) renderiza los 7 módulos sin recortar.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrap(const LearningScreen()));
    await tester.pumpAndSettle();

    // Los 7 módulos (CR-007) aparecen y ninguno está deshabilitado.
    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(7));

    for (var i = 0; i < 7; i++) {
      final tile = tester.widget<ListTile>(tiles.at(i));
      expect(tile.onTap, isNotNull,
          reason: 'Ningún módulo debe estar bloqueado (gate #3).',);
      // Sin candado en el leading (no hay tier locks).
      expect(tile.enabled, isTrue);
    }

    // No hay texto de "bloqueado" / "certificado" / "nivel requerido".
    for (final term in ['bloquead', 'certificad', 'nivel requerido', 'desbloque']) {
      expect(find.textContaining(term), findsNothing);
    }
  });
}
