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
import 'package:mezquite_app/src/services/pending/pending_capture.dart';
import 'package:mezquite_app/src/services/pending/pending_store.dart';
import 'package:mezquite_app/src/services/session_store.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/capture_screen.dart';
import 'package:mezquite_app/src/ui/screens/home_shell.dart';
import 'package:mezquite_app/src/ui/screens/welcome_screen.dart';
import 'package:mezquite_app/src/ui/widgets/pending_uploads_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// CR-035 — la sesión vencida se ve y se cura sin forzar logout.
///
/// Lo central: el aviso es **global y no descartable**, pero JAMÁS bloquea nada
/// (gate #3: un voluntario sin señal sigue capturando a su cola local), y todo
/// texto habla de entrar/guardar/enviar, nunca de revisión (gate #9).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cuenta = 'cuenta-a';
  final bytes = Uint8List.fromList(List<int>.filled(16, 9));

  const sesion = AuthSession(
    handle: 'colibri-azul-42',
    role: 'voluntario',
    token: 'tok',
    accountId: cuenta,
  );

  /// JWT de utilería (firma falsa: la verifica el backend, no la app).
  String jwtCon(Map<String, dynamic> claims) {
    final payload = base64Url
        .encode(utf8.encode(json.encode(claims)))
        .replaceAll('=', '');
    return 'cabecera.$payload.firma';
  }

  PendingCapture captura(String id) => PendingCapture(
        id: id,
        accountId: cuenta,
        lat: 21.88,
        lon: -102.29,
        capturedAt: DateTime.utc(2026, 8, 1, 9),
        nivelG4: 'leve',
        flagCuscuta: false,
        flagDanio: false,
        tamanio: 'mediano',
        contexto: 'campo_abierto',
      );

  Future<PendingCaptureStore> almacenCon(List<PendingCapture> capturas) async {
    final store = PendingCaptureStore(InMemoryPendingBackend());
    await store.init();
    for (final c in capturas) {
      await store.save(c, bytes);
    }
    return store;
  }

  /// API multipart-capaz con estado mutable (patrón `apiQue` de cr031, pero el
  /// status se lee en cada petición para poder simular el re-login).
  ApiClient apiQue(int Function() status) => ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient.streaming((req, body) async {
          final s = status();
          final cuerpo = s >= 200 && s < 300
              ? json.encode({
                  'observation_id': 'obs-1',
                  'base_points': 5,
                  'message': 'ok',
                  'ya_existia': false,
                })
              : 'error';
          return http.StreamedResponse(
            Stream.value(utf8.encode(cuerpo)),
            s,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

  /// API que responde 200 a todo y NUNCA 401 (para probar el disparador
  /// proactivo aislado del reactivo).
  ApiClient apiSin401() => ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient((req) async => http.Response('[]', 200)),
      );

  const celda = GridCell(
    lat: 21.8853,
    lon: -102.2916,
    n: 3,
    nPaxtle: 2,
    nCuscuta: 1,
    g4Indice: 1.5,
    snapshotQuarter: '2026-Q3',
  );

  final obsPublica = PublicObservation(
    handle: 'h1',
    lat: 21.8853,
    lon: -102.2916,
    nivelG4: 'leve',
    flagCuscuta: false,
    flagDanio: true,
    estado: 'AGU',
    municipio: 'Aguascalientes',
    capturedAt: DateTime.utc(2026, 7, 1, 9),
    snapshotQuarter: '2026-Q3',
  );

  const indicadores = Indicators(
    snapshotQuarter: '2026-Q3',
    caveat: 'Datos de origen ciudadano.',
    social: {},
    educativo: {},
    ecologico: {},
    organizacional: {},
  );

  /// Overrides para montar el `HomeShell` completo: cola, API, sesión y los
  /// datos públicos del mapa (para que la pestaña Mapa no toque la red).
  Future<List<Override>> overridesShell({
    required PendingCaptureStore store,
    required ApiClient api,
    AuthSession? session = sesion,
    bool? expirada,
  }) async {
    SharedPreferences.setMockInitialValues({});
    return [
      pendingStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWithValue(api),
      authProvider.overrideWith((ref) => _AuthFijo(session)),
      sessionStoreProvider.overrideWithValue(await SessionStore.create()),
      publicGridProvider.overrideWith((ref) async => [celda]),
      publicObservationsProvider.overrideWith((ref) async => [obsPublica]),
      publicIndicatorsProvider.overrideWith((ref) async => indicadores),
      if (expirada != null)
        sessionExpiredProvider.overrideWith((ref) => expirada),
    ];
  }

  void superficieAmplia(WidgetTester tester,
      [Size size = const Size(1200, 2400),]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Finder pestania(String label) => find.descendant(
        of: find.byKey(const Key('home_nav')),
        matching: find.text(label),
      );

  group('banner global de sesión vencida', () {
    testWidgets('con el flag encendido se ve en las 4 pestañas',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacenCon([]);
      await tester.pumpWidget(wrap(
        const HomeShell(),
        overrides: await overridesShell(
          store: store,
          api: apiSin401(),
          expirada: true,
        ),
      ),);
      await tester.pumpAndSettle();

      for (final label in ['Observar', 'Aprender', 'Mapa', 'Perfil']) {
        await tester.tap(pestania(label));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('session_expired_banner')),
          findsOneWidget,
          reason: 'el banner debe verse en la pestaña $label',
        );
        expect(find.byKey(const Key('session_relogin')), findsOneWidget);
      }
    });

    testWidgets('con el flag apagado no hay banner', (tester) async {
      superficieAmplia(tester);
      final store = await almacenCon([]);
      await tester.pumpWidget(wrap(
        const HomeShell(),
        overrides: await overridesShell(store: store, api: apiSin401()),
      ),);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('session_expired_banner')), findsNothing);
    });

    testWidgets('NO tiene botón de cerrar: no es descartable', (tester) async {
      superficieAmplia(tester);
      final store = await almacenCon([]);
      await tester.pumpWidget(wrap(
        const HomeShell(),
        overrides: await overridesShell(
          store: store,
          api: apiSin401(),
          expirada: true,
        ),
      ),);
      await tester.pumpAndSettle();

      final banner = find.byKey(const Key('session_expired_banner'));
      expect(banner, findsOneWidget);
      expect(
        find.descendant(of: banner, matching: find.byIcon(Icons.close)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: banner,
          matching: find.byType(CloseButton),
        ),
        findsNothing,
      );
    });

    testWidgets('con banner, capturar y navegar siguen posibles (gate #3)',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacenCon([]);
      await tester.pumpWidget(wrap(
        const HomeShell(),
        overrides: await overridesShell(
          store: store,
          api: apiSin401(),
          expirada: true,
        ),
      ),);
      await tester.pumpAndSettle();

      // La navegación no se bloquea…
      final nav = tester.widget<NavigationBar>(find.byKey(const Key('home_nav')));
      expect(nav.onDestinationSelected, isNotNull);
      // …y la pantalla de captura sigue operable (el botón de cámara está ahí).
      await tester.tap(pestania('Observar'));
      await tester.pumpAndSettle();
      final abrirCamara = tester.widget<FilledButton>(
        find.byKey(const Key('open_camera')),
      );
      expect(abrirCamara.onPressed, isNotNull, reason: 'gate #3: nada se bloquea');
    });

    testWidgets('"Volver a entrar" navega a la Bienvenida y atrás conserva todo',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacenCon([]);
      await tester.pumpWidget(wrap(
        const HomeShell(),
        overrides: await overridesShell(
          store: store,
          api: apiSin401(),
          expirada: true,
        ),
      ),);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('session_relogin')));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Es un push, no un reemplazo: "atrás" regresa a donde estaba, con el
      // banner aún encendido (la sesión sigue vencida).
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byKey(const Key('session_expired_banner')), findsOneWidget);
    });

    testWidgets(
        'sesión restaurada con JWT vencido ⇒ banner al primer frame, sin ningún 401',
        (tester) async {
      superficieAmplia(tester);
      final store = await almacenCon([]);
      // exp = 2025-06-15, muy en el pasado; la API de este test NUNCA responde
      // 401: el disparador es la lectura local del `exp` en el HomeShell.
      final vencida = AuthSession(
        handle: 'colibri-azul-42',
        role: 'voluntario',
        token: jwtCon({'sub': cuenta, 'exp': 1750000000}),
        accountId: cuenta,
      );
      await tester.pumpWidget(wrap(
        const HomeShell(),
        overrides: await overridesShell(
          store: store,
          api: apiSin401(),
          session: vencida,
        ),
      ),);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('session_expired_banner')), findsOneWidget);
    });
  });

  group('re-login y logout apagan el aviso', () {
    test('un AuthSession nuevo apaga el flag y la cola pausada se sube',
        () async {
      final store = await almacenCon([captura('a')]);
      var status = 401;
      final auth = _AuthFijo(sesion);
      final container = ProviderContainer(overrides: [
        pendingStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(apiQue(() => status)),
        authProvider.overrideWith((ref) => auth),
      ],);
      addTearDown(container.dispose);

      // El 401 pausa la cola y la conserva (CR-031).
      await container.read(pendingQueueProvider.notifier).subirAhora();
      expect(container.read(pendingQueueProvider).sesionExpirada, isTrue);
      expect(await store.count(), 1);
      container.read(sessionExpiredProvider.notifier).state = true;

      // Re-login: MISMA cuenta pero objeto AuthSession nuevo — suficiente para
      // que el listener lo note y llame a sesionRenovada().
      status = 201;
      auth.simular(const AuthSession(
        handle: 'colibri-azul-42',
        role: 'voluntario',
        token: 'tok-nuevo',
        accountId: cuenta,
      ),);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(sessionExpiredProvider), isFalse);
      expect(container.read(pendingQueueProvider).sesionExpirada, isFalse);
      expect(await store.count(), 0, reason: 'la pendiente se subió sola');
    });

    test('el logout apaga el flag (solo apaga: no reintenta nada)', () async {
      final store = await almacenCon([]);
      final auth = _AuthFijo(sesion);
      final container = ProviderContainer(overrides: [
        pendingStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(apiQue(() => 503)),
        authProvider.overrideWith((ref) => auth),
      ],);
      addTearDown(container.dispose);

      container.read(pendingQueueProvider); // activa el listener
      container.read(sessionExpiredProvider.notifier).state = true;

      auth.simular(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(container.read(sessionExpiredProvider), isFalse);
    });
  });

  group('captura con la sesión vencida: el texto no promete envío automático',
      () {
    testWidgets('el SnackBar dice "vuelve a entrar", no "se enviará sola"',
        (tester) async {
      superficieAmplia(tester, const Size(1080, 4000));
      final store = await almacenCon([]);
      SharedPreferences.setMockInitialValues({});
      final shot = CaptureResult(
        imageBytes: bytes,
        lat: 21.88,
        lon: -102.29,
        capturedAt: DateTime.utc(2026, 8, 1, 9),
      );
      await tester.pumpWidget(wrap(
        CaptureScreen(initialShot: shot),
        overrides: [
          pendingStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(apiQue(() => 401)),
          authProvider.overrideWith((ref) => _AuthFijo(sesion)),
          sessionStoreProvider.overrideWithValue(await SessionStore.create()),
        ],
      ),);
      await tester.pumpAndSettle();

      // Completa las etiquetas obligatorias (mismo camino que observation_form_test).
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

      await tester.tap(find.byKey(const Key('submit_observation')));
      await tester.pumpAndSettle();

      expect(find.text(Copy.captureSavedSessionExpired), findsOneWidget);
      expect(find.text(Copy.captureSavedOffline), findsNothing);
      expect(await store.count(), 1, reason: 'la captura quedó a salvo local');
    });
  });

  group('tarjeta de pendientes con sesión vencida', () {
    testWidgets('muestra el botón de re-login y navega a la Bienvenida',
        (tester) async {
      final store = await almacenCon([captura('a')]);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(wrap(
        const Scaffold(body: PendingUploadsCard()),
        overrides: [
          pendingStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(apiQue(() => 401)),
          authProvider.overrideWith((ref) => _AuthFijo(sesion)),
          sessionStoreProvider.overrideWithValue(await SessionStore.create()),
        ],
      ),);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pending_upload_now')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending_session_expired')), findsOneWidget);
      expect(find.byKey(const Key('pending_relogin')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pending_relogin')));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('gate #9 — los textos de sesión no hablan de revisión', () {
    test('ninguno de los 3 textos nuevos insinúa veredictos', () {
      for (final texto in [
        Copy.sessionExpiredBanner,
        Copy.sessionExpiredRelogin,
        Copy.captureSavedSessionExpired,
      ]) {
        final t = texto.toLowerCase();
        expect(t, isNot(contains('revisión')), reason: texto);
        expect(t, isNot(contains('revisad')), reason: texto);
        expect(t, isNot(contains('confirmad')), reason: texto);
      }
    });
  });
}

/// Sesión fija para las pruebas (patrón de cr031_ui_test; AuthController NO
/// cambió en CR-035). [simular] permite fingir el re-login/logout sin montar
/// el flujo de Google.
class _AuthFijo extends StateNotifier<AuthSession?> implements AuthController {
  _AuthFijo(super.session);

  void simular(AuthSession? session) => state = session;

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
