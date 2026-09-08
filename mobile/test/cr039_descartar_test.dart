import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_app/src/api/api_client.dart';
import 'package:mezquite_app/src/models/enums.dart';
import 'package:mezquite_app/src/models/models.dart';
import 'package:mezquite_app/src/services/capture_service.dart';
import 'package:mezquite_app/src/services/pending/pending_store.dart';
import 'package:mezquite_app/src/services/session_store.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/capture_pane.dart';
import 'package:mezquite_app/src/ui/screens/capture_screen.dart';
import 'package:mezquite_app/src/ui/screens/home_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// CR-039 — descartar la captura sin enviarla.
///
/// Antes no había salida: con la foto ya tomada, la única manera de salir del formulario
/// era **enviarlo**, así que quien se daba cuenta de que la captura estaba mal terminaba
/// registrando la observación errónea a sabiendas. La única escapatoria real —cambiar de
/// pestaña— tiraba la captura **en silencio** y era indistinguible de un fallo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cuenta = 'cuenta-a';
  const sesion = AuthSession(
    handle: 'colibri-azul-42',
    role: 'voluntario',
    token: 'tok',
    accountId: cuenta,
  );

  final bytes = Uint8List.fromList(List<int>.filled(32, 7));

  final captura = CaptureResult(
    imageBytes: bytes,
    lat: 21.8853,
    lon: -102.2916,
    capturedAt: DateTime.utc(2026, 9, 1, 10),
  );

  ApiClient apiOk() => ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient.streaming((req, body) async {
          const cuerpo = <String, dynamic>{
            'observation_id': 'obs-1',
            'base_points': 5,
            'message': 'ok',
            'ya_existia': false,
          };
          return http.StreamedResponse(
            Stream.value(utf8.encode(json.encode(cuerpo))),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

  void superficieAmplia(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<PendingCaptureStore> almacen() async {
    final store = PendingCaptureStore(InMemoryPendingBackend());
    await store.init();
    return store;
  }

  Future<List<Override>> overrides(
    PendingCaptureStore store, {
    CapturaEnCurso? enCurso,
  }) async {
    SharedPreferences.setMockInitialValues({});
    return [
      pendingStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWithValue(apiOk()),
      authProvider.overrideWith((ref) => _AuthFijo(sesion)),
      sessionStoreProvider.overrideWithValue(await SessionStore.create()),
      if (enCurso != null)
        capturaEnCursoProvider.overrideWith((ref) => enCurso),
    ];
  }

  Future<void> completarEtiquetas(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('g4_option_leve')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dropdown_tamanio')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Tamanio.mediano.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dropdown_contexto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Contexto.campoAbierto.label).last);
    await tester.pumpAndSettle();
  }

  bool submitHabilitado(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.byKey(const Key('submit_observation')))
          .onPressed !=
      null;

  group('AC1-AC5 — descartar pide confirmación y no envía nada', () {
    testWidgets('AC1: el formulario ofrece "Descartar"', (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const CaptureScreen(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('captura_foto_descartar')), findsOneWidget);
    });

    testWidgets('AC2: descartar NO actúa sin confirmar', (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const CaptureScreen(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('captura_foto_descartar')));
      await tester.pumpAndSettle();

      // Sale el diálogo y la captura sigue intacta detrás.
      expect(find.byKey(const Key('captura_descartar_dialogo')), findsOneWidget);
      expect(find.byKey(const Key('observation_form')), findsOneWidget);
    });

    testWidgets('AC3: cancelar conserva la captura y las etiquetas', (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const CaptureScreen(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();

      await completarEtiquetas(tester);
      await tester.tap(find.byKey(const Key('captura_foto_descartar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('captura_descartar_cancelar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('captura_descartar_dialogo')), findsNothing);
      expect(find.byKey(const Key('observation_form')), findsOneWidget);
      expect(submitHabilitado(tester), isTrue,
          reason: 'cancelar no puede costarle nada al voluntario',);
    });

    testWidgets('AC4: confirmar vacía foto Y etiquetas, y vuelve a la cámara',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const CaptureScreen(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();

      await completarEtiquetas(tester);
      await tester.tap(find.byKey(const Key('captura_foto_descartar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('captura_descartar_confirmar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('observation_form')), findsNothing);
      expect(find.byType(CapturePane), findsOneWidget);
      expect(find.text(Copy.captureDescartada), findsOneWidget);

      // Y el árbol siguiente arranca en blanco: las etiquetas se fueron con la foto.
      final pane = tester.widget<CapturePane>(find.byType(CapturePane));
      pane.onCaptured(captura);
      await tester.pumpAndSettle();
      expect(submitHabilitado(tester), isFalse);
    });

    testWidgets('AC5: descartar NO encola ni envía nada', (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const CaptureScreen(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();

      await completarEtiquetas(tester);
      await tester.tap(find.byKey(const Key('captura_foto_descartar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('captura_descartar_confirmar')));
      await tester.pumpAndSettle();

      expect(await store.count(), 0,
          reason: 'descartar ocurre ANTES de enviar: nada llega a la cola',);
    });

    testWidgets('AC6: el aviso distingue "solo la foto" de "foto y datos"',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const CaptureScreen(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();

      // Recién tomada, sin declarar nada: no puede prometer que se pierden datos.
      await tester.tap(find.byKey(const Key('captura_foto_descartar')));
      await tester.pumpAndSettle();
      expect(find.text(Copy.captureDescartarSoloFoto), findsOneWidget);
      expect(find.text(Copy.captureDescartarConDatos), findsNothing);
      await tester.tap(find.byKey(const Key('captura_descartar_cancelar')));
      await tester.pumpAndSettle();

      // Con etiquetas declaradas, el aviso ya nombra los datos.
      await completarEtiquetas(tester);
      await tester.tap(find.byKey(const Key('captura_foto_descartar')));
      await tester.pumpAndSettle();
      expect(find.text(Copy.captureDescartarConDatos), findsOneWidget);
      expect(find.text(Copy.captureDescartarSoloFoto), findsNothing);
    });
  });

  group('AC7-AC8 — la captura sobrevive al cambio de pestaña', () {
    Finder pestania(String label) => find.descendant(
          of: find.byKey(const Key('home_nav')),
          matching: find.text(label),
        );

    testWidgets(
        'AC7: ir a otra pestaña y volver CONSERVA la foto y las etiquetas',
        (tester) async {
      // La regresión que cierra este CR: `HomeShell` monta las pestañas con
      // `_screens[_index]`, así que cambiar de pestaña desmontaba `CaptureScreen` y
      // tiraba la captura sin avisar. Era la única salida del formulario, y era
      // indistinguible de un fallo.
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const HomeShell(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();

      // HomeShell abre en Aprender (CR-032); vamos a Observar.
      await tester.tap(pestania('Observar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('observation_form')), findsOneWidget);

      await completarEtiquetas(tester);
      expect(submitHabilitado(tester), isTrue);

      // Salir a otra pestaña y volver.
      await tester.tap(pestania('Aprender'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('observation_form')), findsNothing);

      await tester.tap(pestania('Observar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('observation_form')), findsOneWidget,
          reason: 'la foto no puede perderse por mirar otra pestaña',);
      expect(submitHabilitado(tester), isTrue,
          reason: 'las etiquetas declaradas tampoco',);
      expect(find.byKey(const Key('captura_foto_miniatura')), findsOneWidget);
    });

    testWidgets('AC8: lo descartado NO resucita al volver a la pestaña',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const HomeShell(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();

      await tester.tap(pestania('Observar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('captura_foto_descartar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('captura_descartar_confirmar')));
      await tester.pumpAndSettle();

      await tester.tap(pestania('Aprender'));
      await tester.pumpAndSettle();
      await tester.tap(pestania('Observar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('observation_form')), findsNothing);
      expect(find.byType(CapturePane), findsOneWidget);
    });
  });

  group('gates', () {
    testWidgets('gate #3: descartar no bloquea nada — se puede volver a capturar',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const CaptureScreen(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('captura_foto_descartar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('captura_descartar_confirmar')));
      await tester.pumpAndSettle();

      final pane = tester.widget<CapturePane>(find.byType(CapturePane));
      pane.onCaptured(captura);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('observation_form')), findsOneWidget);
    });

    testWidgets('gate #9: los textos de descarte no insinúan veredicto',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        const CaptureScreen(),
        overrides: await overrides(store, enCurso: CapturaEnCurso(foto: captura)),
      ),);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('captura_foto_descartar')));
      await tester.pumpAndSettle();

      for (final term in ['válida', 'valida', 'ruido', 'rechazada', 'aprobada']) {
        expect(find.textContaining(term, findRichText: true), findsNothing,
            reason: 'No debe aparecer "$term" (estado de validación individual).',);
      }
    });
  });
}

/// Sesión fija para las pruebas (mismo doble que en cr031/cr035/cr037).
class _AuthFijo extends StateNotifier<AuthSession?> implements AuthController {
  _AuthFijo(super.session);

  @override
  Future<GoogleSignInOutcome> signInWithGoogle({String? institutionId}) async =>
      GoogleSignInOutcome.success;

  @override
  Future<GoogleSignInOutcome> completeGoogleSignIn(
    String idToken, {
    String? institutionId,
  }) async =>
      GoogleSignInOutcome.success;

  @override
  Future<void> logout() async => state = null;
}
