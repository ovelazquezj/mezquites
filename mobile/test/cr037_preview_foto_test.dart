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
import 'package:mezquite_app/src/ui/screens/observation_form.dart';
import 'package:mezquite_app/src/ui/widgets/captura_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// CR-037 — la foto se ve ANTES de enviarla.
///
/// El voluntario nunca veía la fotografía que acababa de tomar: ni al capturar los datos,
/// ni después. El primer humano en mirarla era quien revisaba en la consola, y para
/// entonces ya estaba enviada. Aquí se prueban las dos mitades del arreglo: **verla**
/// (miniatura + lupa) y **rehacerla** sin perder lo ya declarado del mismo árbol.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cuenta = 'cuenta-a';

  const sesion = AuthSession(
    handle: 'colibri-azul-42',
    role: 'voluntario',
    token: 'tok',
    accountId: cuenta,
  );

  /// Bytes de utilería: no son un JPEG válido a propósito. Lo que se prueba es que el
  /// recuadro mide y responde igual **aunque la imagen no se pueda decodificar** — que es
  /// justo la trampa que dejó invisibles las ilustraciones de CR-032.
  final bytes = Uint8List.fromList(List<int>.filled(32, 7));

  CaptureResult capturaCon(Uint8List b) => CaptureResult(
        imageBytes: b,
        lat: 21.8853,
        lon: -102.2916,
        capturedAt: DateTime.utc(2026, 9, 1, 10),
      );

  final captura = capturaCon(bytes);

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

  Future<void> pumpForm(
    WidgetTester tester, {
    void Function(ObservationDraft)? onSubmit,
    EtiquetasCaptura etiquetasIniciales = const EtiquetasCaptura(),
    ValueChanged<EtiquetasCaptura>? onEtiquetasChanged,
    VoidCallback? onRepetirFoto,
  }) async {
    superficieAmplia(tester);
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: ObservationForm(
            capture: captura,
            onSubmit: onSubmit ?? (_) {},
            etiquetasIniciales: etiquetasIniciales,
            onEtiquetasChanged: onEtiquetasChanged,
            onRepetirFoto: onRepetirFoto,
          ),
        ),
      ),
    );
  }

  /// Completa las 3 etiquetas obligatorias (mismo camino que `observation_form_test`).
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

  group('AC1-AC4 — la foto se ve y se puede ampliar', () {
    testWidgets('AC1: el formulario muestra la foto capturada', (tester) async {
      await pumpForm(tester);
      expect(find.byKey(const Key('captura_foto_miniatura')), findsOneWidget);
      expect(find.byType(CapturaPreview), findsOneWidget);
      expect(find.text(Copy.captureFotoTitulo), findsOneWidget);
    });

    testWidgets('AC2: la miniatura tiene alto REAL > 0 aunque la imagen no cargue',
        (tester) async {
      // La lección de CR-029 y del fix de CR-032: un `Image` sin alto explícito mide sus
      // dimensiones intrínsecas, que valen 0 hasta decodificar — queda en el árbol y es
      // invisible. Se afirma MIDIENDO, no comprobando que el widget exista.
      await pumpForm(tester);
      final size = tester.getSize(find.byKey(const Key('captura_foto_miniatura')));
      expect(size.height, greaterThan(0));
      expect(size.width, greaterThan(0));
      expect(size.height, CapturaPreview.ladoMiniatura);
    });

    testWidgets('AC3: tocar la miniatura abre el visor a pantalla completa',
        (tester) async {
      await pumpForm(tester);
      expect(find.byKey(const Key('captura_foto_visor')), findsNothing);

      await tester.tap(find.byKey(const Key('captura_foto_ampliar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('captura_foto_visor')), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('AC4: el visor se cierra y devuelve al formulario', (tester) async {
      await pumpForm(tester);
      await tester.tap(find.byKey(const Key('captura_foto_ampliar')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('captura_foto_visor_cerrar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('captura_foto_visor')), findsNothing);
      expect(find.byKey(const Key('observation_form')), findsOneWidget);
    });
  });

  group('AC5-AC6 — repetir la foto sin perder lo declarado', () {
    testWidgets('AC5: "Repetir foto" avisa a la pantalla', (tester) async {
      var repeticiones = 0;
      await pumpForm(tester, onRepetirFoto: () => repeticiones++);

      await tester.tap(find.byKey(const Key('captura_foto_repetir')));
      await tester.pump();

      expect(repeticiones, 1);
    });

    testWidgets('AC5: sin callback no hay botón, pero la foto se sigue viendo',
        (tester) async {
      await pumpForm(tester);
      expect(find.byKey(const Key('captura_foto_repetir')), findsNothing);
      expect(find.byKey(const Key('captura_foto_miniatura')), findsOneWidget);
    });

    testWidgets('AC6: el formulario arranca con las etiquetas que le siembran',
        (tester) async {
      await pumpForm(
        tester,
        etiquetasIniciales: const EtiquetasCaptura(
          nivelG4: NivelG4.severo,
          cuscuta: true,
          tamanio: Tamanio.grande,
          contexto: Contexto.ripario,
        ),
      );

      // Sin tocar nada: ya se puede registrar, porque las 3 obligatorias venían puestas.
      expect(submitHabilitado(tester), isTrue);
    });

    testWidgets('AC6: cada cambio se espeja hacia la pantalla', (tester) async {
      EtiquetasCaptura? ultimas;
      await pumpForm(tester, onEtiquetasChanged: (e) => ultimas = e);

      await completarEtiquetas(tester);
      await tester.tap(find.byKey(const Key('toggle_cuscuta')));
      await tester.pump();

      expect(ultimas, isNotNull);
      expect(ultimas!.nivelG4, NivelG4.leve);
      expect(ultimas!.tamanio, Tamanio.mediano);
      expect(ultimas!.contexto, Contexto.campoAbierto);
      expect(ultimas!.cuscuta, isTrue);
      expect(ultimas!.danio, isFalse, reason: 'los toggles son independientes');
      expect(ultimas!.completa, isTrue);
    });
  });

  group('AC7-AC8 — el ciclo completo en la pantalla de captura', () {
    Future<PendingCaptureStore> almacen() async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      return store;
    }

    Future<List<Override>> overrides(PendingCaptureStore store) async {
      SharedPreferences.setMockInitialValues({});
      return [
        pendingStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(apiOk()),
        authProvider.overrideWith((ref) => _AuthFijo(sesion)),
        sessionStoreProvider.overrideWithValue(await SessionStore.create()),
      ];
    }

    /// Simula que la cámara entregó otra foto: se invoca el mismo callback que usa el
    /// panel de captura real. Evita inventar un seam de producción solo para la prueba.
    Future<void> recapturar(WidgetTester tester) async {
      final pane = tester.widget<CapturePane>(find.byType(CapturePane));
      pane.onCaptured(capturaCon(Uint8List.fromList(List<int>.filled(32, 3))));
      await tester.pumpAndSettle();
    }

    testWidgets('AC7: repetir la foto CONSERVA las etiquetas del mismo árbol',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        CaptureScreen(initialShot: captura),
        overrides: await overrides(store),
      ),);
      await tester.pumpAndSettle();

      await completarEtiquetas(tester);
      expect(submitHabilitado(tester), isTrue);

      // Repetir: vuelve la cámara y el formulario desaparece.
      await tester.tap(find.byKey(const Key('captura_foto_repetir')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('observation_form')), findsNothing);
      expect(find.byType(CapturePane), findsOneWidget);

      // Nueva foto del MISMO árbol: las etiquetas siguen puestas.
      await recapturar(tester);
      expect(find.byKey(const Key('observation_form')), findsOneWidget);
      expect(submitHabilitado(tester), isTrue,
          reason: 'repetir la foto no debe obligar a redeclarar el mismo árbol',);
      expect(await store.count(), 0, reason: 'repetir NO encola nada');
    });

    testWidgets('AC8: tras registrar, el siguiente árbol empieza en blanco',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacen();
      await tester.pumpWidget(wrap(
        CaptureScreen(initialShot: captura),
        overrides: await overrides(store),
      ),);
      await tester.pumpAndSettle();

      await completarEtiquetas(tester);
      await tester.tap(find.byKey(const Key('submit_observation')));
      await tester.pumpAndSettle();

      expect(find.byType(CapturePane), findsOneWidget);

      // El árbol SIGUIENTE no puede heredar las etiquetas del anterior.
      await recapturar(tester);
      expect(find.byKey(const Key('observation_form')), findsOneWidget);
      expect(submitHabilitado(tester), isFalse,
          reason: 'un árbol nuevo arranca sin etiquetas declaradas',);
    });
  });

  group('gates', () {
    testWidgets('gate #4: repetir es CÁMARA, nunca galería', (tester) async {
      await pumpForm(tester, onRepetirFoto: () {});
      for (final term in ['galería', 'galeria', 'Galería', 'álbum', 'carrete']) {
        expect(find.textContaining(term, findRichText: true), findsNothing,
            reason: 'No debe existir ninguna acción de galería ("$term").',);
      }
      expect(find.text(Copy.captureFotoRepetir), findsOneWidget);
    });

    testWidgets('gate #9: la tarjeta de la foto no insinúa ningún veredicto',
        (tester) async {
      await pumpForm(tester, onRepetirFoto: () {});
      for (final term in ['válida', 'valida', 'ruido', 'rechazada', 'aprobada']) {
        expect(find.textContaining(term, findRichText: true), findsNothing,
            reason: 'No debe aparecer "$term" (estado de validación individual).',);
      }
    });
  });
}

/// Sesión fija para las pruebas (mismo doble que en cr031/cr035; `AuthController` no
/// cambia en CR-037).
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
