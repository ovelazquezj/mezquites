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

/// Captura cerca de Calvillo. Antes (CR-010 #5) servía para probar la auto-detección por
/// cercanía; ahora sirve para probar que el formulario NO adivina nada — ese "adivinar el
/// municipio más cercano" fue justo lo que etiquetó mal 235 observaciones en producción.
CaptureResult _captureCalvillo() => CaptureResult(
      imagePath: '/tmp/fake.jpg',
      lat: 21.847,
      lon: -102.719,
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
    CaptureResult capture, {
    ResolverLugar? resolverLugar,
  }) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: ObservationForm(
            capture: capture,
            onSubmit: onSubmit,
            resolverLugar: resolverLugar,
          ),
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
    expect(payload['nivel_g4'], 'severo');
    expect(payload['flag_cuscuta'], true);
    expect(payload['flag_danio'], false); // independiente del de cúscuta
    expect(payload['tamanio'], 'grande');
    expect(payload['contexto'], 'ripario');
    // CR-036: estado/municipio ya NO viajan — los deriva el servidor de lat/lon.
    expect(payload.containsKey('estado'), isFalse);
    expect(payload.containsKey('municipio'), isFalse);
    // EXIF real propagado (gate #4).
    expect(payload['lat'], 25.6866);
    expect(payload['lon'], -100.3161);
    expect(payload['captured_at'], '2026-05-30T12:00:00.000Z');
  });

  // --- CR-036: el voluntario ya no declara el lugar ---

  testWidgets('AC13: no hay selector de estado ni de municipio', (tester) async {
    await pumpForm(tester, (_) {}, _captureCalvillo());
    expect(find.byKey(const Key('dropdown_estado')), findsNothing);
    expect(find.byKey(const Key('dropdown_municipio')), findsNothing);
  });

  testWidgets('AC14: con red, muestra el lugar resuelto por el servidor',
      (tester) async {
    await pumpForm(
      tester,
      (_) {},
      _captureCalvillo(),
      resolverLugar: (lat, lon) async => const GeoLugar(
        estado: 'Zacatecas',
        municipio: 'Jalpa',
        cveEnt: '32',
        cveMun: '019',
        resuelto: true,
      ),
    );
    await tester.pumpAndSettle();

    final etiqueta = find.byKey(const Key('captura_lugar'));
    expect(etiqueta, findsOneWidget);
    expect(tester.widget<Text>(etiqueta).data, 'Jalpa, Zacatecas');
    // Las coordenadas siguen visibles debajo, como respaldo verificable.
    expect(find.textContaining('Lat 21.84700'), findsOneWidget);
  });

  testWidgets('AC15: sin red, coordenadas y aviso honesto — nunca un lugar inventado',
      (tester) async {
    await pumpForm(
      tester,
      (_) {},
      _captureCalvillo(),
      // Lo que devuelve `ApiClient.geoResolve` cuando no hay señal.
      resolverLugar: (lat, lon) async => null,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('captura_lugar')), findsNothing);
    expect(find.byKey(const Key('captura_lugar_sin_resolver')), findsOneWidget);
    expect(find.textContaining('Lat 21.84700'), findsOneWidget);
  });

  testWidgets('AC15: sin resolvedor la captura funciona igual (offline puro)',
      (tester) async {
    ObservationDraft? submitted;
    await pumpForm(tester, (d) => submitted = d, _captureCalvillo());
    await tester.tap(find.byKey(const Key('g4_option_leve')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dropdown_tamanio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tamanio.mediano.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dropdown_contexto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Contexto.urbano.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit_observation')));
    await tester.pump();

    expect(submitted, isNotNull,
        reason: 'sin red la captura debe completarse igual (gate #3 / CR-031)',);
  });

  testWidgets('AC16: la precisión del GPS viaja en el payload', (tester) async {
    ObservationDraft? submitted;
    await pumpForm(
      tester,
      (d) => submitted = d,
      CaptureResult(
        imagePath: '/tmp/fake.jpg',
        lat: 21.847,
        lon: -102.719,
        capturedAt: DateTime.utc(2026, 5, 30, 12, 0, 0),
        gpsAccuracyM: 14.25,
      ),
    );
    await tester.tap(find.byKey(const Key('g4_option_leve')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dropdown_tamanio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tamanio.mediano.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dropdown_contexto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Contexto.urbano.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit_observation')));
    await tester.pump();

    expect(submitted!.toPayloadJson()['gps_accuracy_m'], 14.25);
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
