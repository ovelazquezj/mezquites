import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/models/enums.dart';
import 'package:mezquite_app/src/models/models.dart';
import 'package:mezquite_app/src/services/capture_service.dart';
import 'package:mezquite_app/src/ui/screens/observation_form.dart';

import 'helpers.dart';

CaptureResult _fakeCapture() => CaptureResult(
      imagePath: '/tmp/fake.jpg',
      lat: 25.6866,
      lon: -100.3161,
      capturedAt: DateTime.utc(2026, 5, 30, 12, 0, 0),
    );

/// Q2/Q3: submit con 8 campos, dropdowns obligatorios, toggles independientes,
/// y fire-and-forget (el callback recibe el draft completo).
void main() {
  // Surface alta para que el ListView del formulario quede totalmente laid out
  // (los tiles/dropdowns/submit no quedan fuera de pantalla en el test).
  Future<void> pumpForm(
    WidgetTester tester,
    void Function(ObservationDraft) onSubmit,
    CaptureResult capture,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: ObservationForm(capture: capture, onSubmit: onSubmit),
        ),
      ),
    );
  }

  testWidgets('el formulario reúne las 8 etiquetas y emite el draft',
      (tester) async {
    ObservationDraft? submitted;
    await pumpForm(tester, (d) => submitted = d, _fakeCapture());

    // El submit está deshabilitado hasta completar los campos obligatorios.
    final submitBtn = tester.widget<FilledButton>(
      find.byKey(const Key('submit_observation')),
    );
    expect(submitBtn.onPressed, isNull);

    // 4: nivel G4.
    await tester.tap(find.byKey(const Key('g4_option_severo')));
    await tester.pump();

    // 5-6: toggles binarios independientes.
    await tester.tap(find.byKey(const Key('toggle_cuscuta')));
    await tester.pump();
    // flag_danio se deja en false a propósito: independencia.

    // 7: tamaño.
    await tester.tap(find.byKey(const Key('dropdown_tamanio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tamanio.grande.label).last);
    await tester.pumpAndSettle();

    // 8: contexto.
    await tester.tap(find.byKey(const Key('dropdown_contexto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Contexto.ripario.label).last);
    await tester.pumpAndSettle();

    // Ahora el submit está habilitado.
    await tester.tap(find.byKey(const Key('submit_observation')));
    await tester.pump();

    expect(submitted, isNotNull);
    final payload = submitted!.toPayloadJson();
    // Exactamente 8 campos en el payload.
    expect(payload.keys.length, 8);
    expect(payload['nivel_g4'], 'severo');
    expect(payload['flag_cuscuta'], true);
    expect(payload['flag_danio'], false); // independiente del de cúscuta
    expect(payload['tamanio'], 'grande');
    expect(payload['contexto'], 'ripario');
    // EXIF real propagado (gate #4).
    expect(payload['lat'], 25.6866);
    expect(payload['lon'], -100.3161);
    expect(payload['captured_at'], '2026-05-30T12:00:00.000Z');
  });

  testWidgets('toggles son independientes', (tester) async {
    ObservationDraft? submitted;
    await pumpForm(tester, (d) => submitted = d, _fakeCapture());

    await tester.tap(find.byKey(const Key('g4_option_sano')));
    await tester.pump();
    // Solo daño en true.
    await tester.tap(find.byKey(const Key('toggle_danio')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('dropdown_tamanio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tamanio.pequeno.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dropdown_contexto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Contexto.urbano.label).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('submit_observation')));
    await tester.pump();

    expect(submitted!.flagCuscuta, false);
    expect(submitted!.flagDanio, true);
  });

  testWidgets('el formulario NO muestra estado de validación individual',
      (tester) async {
    await pumpForm(tester, (_) {}, _fakeCapture());

    // Gate #9: ningún texto de veredicto por observación.
    for (final term in ['válida', 'valida', 'ruido', 'rechazada', 'aprobada']) {
      expect(find.textContaining(term, findRichText: true), findsNothing,
          reason: 'No debe aparecer "$term" (estado de validación individual).',);
    }
  });
}
