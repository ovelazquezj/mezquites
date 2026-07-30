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
import 'package:mezquite_app/src/services/pending/pending_capture.dart';
import 'package:mezquite_app/src/services/pending/pending_store.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/widgets/pending_uploads_card.dart';

import 'helpers.dart';

/// CR-031 W4 — interfaz honesta.
///
/// Lo que se fija aquí es, sobre todo, que **ningún texto declare "registrada"
/// antes de que el servidor responda** (AC11) y que el contador de pendientes sea
/// visible y accionable (AC12), con la separación de estados que exige el gate #9
/// (AC13).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cuenta = 'cuenta-a';
  final bytes = Uint8List.fromList(List<int>.filled(16, 9));

  PendingCapture captura(String id, {PendingState? state, int minuto = 0}) =>
      PendingCapture(
        id: id,
        accountId: cuenta,
        lat: 21.88,
        lon: -102.29,
        capturedAt: DateTime.utc(2026, 7, 29, 9, minuto),
        nivelG4: 'leve',
        flagCuscuta: false,
        flagDanio: false,
        tamanio: 'mediano',
        contexto: 'campo_abierto',
        state: state ?? PendingState.enCola,
      );

  Future<PendingCaptureStore> almacenCon(
    List<PendingCapture> capturas,
  ) async {
    final store = PendingCaptureStore(InMemoryPendingBackend());
    await store.init();
    for (final c in capturas) {
      await store.save(c, bytes);
    }
    return store;
  }

  ApiClient apiQue(int status, {bool yaExistia = false}) => ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient.streaming((req, body) async {
          final cuerpo = status >= 200 && status < 300
              ? json.encode({
                  'observation_id': 'obs-1',
                  'base_points': 5,
                  'message': 'ok',
                  'ya_existia': yaExistia,
                })
              : 'error';
          return http.StreamedResponse(
            Stream.value(utf8.encode(cuerpo)),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

  const sesion = AuthSession(
    handle: 'colibri-azul-42',
    role: 'voluntario',
    token: 'tok',
    accountId: cuenta,
  );

  /// Overrides comunes: almacén, cliente y **sesión**. La sesión hay que inyectarla
  /// porque `pendingQueueProvider` lee `authProvider` para saber de quién son las
  /// capturas (D8), y sin override eso arrastraría el almacén de sesión real.
  List<Override> overrides(
    PendingCaptureStore store,
    ApiClient api, {
    AuthSession? session = sesion,
  }) =>
      [
        pendingStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(api),
        authProvider.overrideWith((ref) => _AuthFijo(session)),
      ];

  /// Envuelve la tarjeta con el almacén y una sesión inyectados.
  Widget conTarjeta(PendingCaptureStore store, ApiClient api) => wrap(
        const Scaffold(body: PendingUploadsCard()),
        overrides: overrides(store, api),
      );

  group('AC12/AC13 — contador visible y accionable', () {
    testWidgets('muestra cuántas faltan y el botón de subir', (tester) async {
      final store = await almacenCon([captura('a'), captura('b', minuto: 1)]);
      await tester.pumpWidget(conTarjeta(store, apiQue(503)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending_uploads_card')), findsOneWidget);
      expect(find.text(Copy.pendingCount(2)), findsOneWidget);
      expect(find.text('2 observaciones por subir'), findsOneWidget);
      expect(find.byKey(const Key('pending_upload_now')), findsOneWidget);
    });

    testWidgets('el singular está bien escrito', (tester) async {
      final store = await almacenCon([captura('a')]);
      await tester.pumpWidget(conTarjeta(store, apiQue(503)));
      await tester.pumpAndSettle();

      expect(find.text('1 observación por subir'), findsOneWidget);
    });

    testWidgets('sin pendientes la tarjeta no aparece', (tester) async {
      final store = await almacenCon([]);
      await tester.pumpWidget(conTarjeta(store, apiQue(201)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending_uploads_card')), findsNothing);
    });

    testWidgets('"Subir ahora" sube y la tarjeta desaparece', (tester) async {
      final store = await almacenCon([captura('a')]);
      await tester.pumpWidget(conTarjeta(store, apiQue(201)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pending_upload_now')));
      await tester.pumpAndSettle();

      expect(await store.count(), 0);
      expect(find.byKey(const Key('pending_uploads_card')), findsNothing);
    });

    testWidgets('el texto habla de SUBIR, nunca de revisar (gate #9)',
        (tester) async {
      final store = await almacenCon([captura('a')]);
      await tester.pumpWidget(conTarjeta(store, apiQue(503)));
      await tester.pumpAndSettle();

      expect(find.textContaining('por subir'), findsOneWidget);
      expect(find.textContaining('revisión'), findsNothing);
      expect(find.textContaining('confirmada'), findsNothing);
      expect(find.textContaining('válida'), findsNothing);
    });
  });

  group('AC19 — aviso por acumulación (D2), sin bloquear', () {
    testWidgets('por debajo del umbral no hay aviso', (tester) async {
      final store = await almacenCon([
        for (var i = 0; i < 3; i++) captura('c$i', minuto: i),
      ]);
      await tester.pumpWidget(conTarjeta(store, apiQue(503)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending_warning')), findsNothing);
    });

    testWidgets('al llegar al umbral aparece el aviso', (tester) async {
      final store = await almacenCon([
        for (var i = 0; i < Copy.pendingWarnAt; i++) captura('c$i', minuto: i),
      ]);
      await tester.pumpWidget(conTarjeta(store, apiQue(503)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending_warning')), findsOneWidget);
      expect(
        find.textContaining('${Copy.pendingWarnAt} observaciones sin subir'),
        findsOneWidget,
      );
    });

    testWidgets('el aviso NO impide nada: sigue habiendo botón de subir',
        (tester) async {
      final store = await almacenCon([
        for (var i = 0; i < Copy.pendingWarnAt; i++) captura('c$i', minuto: i),
      ]);
      await tester.pumpWidget(conTarjeta(store, apiQue(503)));
      await tester.pumpAndSettle();

      final boton = tester.widget<TextButton>(
        find.byKey(const Key('pending_upload_now')),
      );
      expect(boton.onPressed, isNotNull, reason: 'gate #3: nada se bloquea');
    });
  });

  group('AC17 — 401 avisa sin perder nada; 410 vacía', () {
    testWidgets('401 muestra que la sesión expiró y conserva la cola',
        (tester) async {
      final store = await almacenCon([captura('a')]);
      await tester.pumpWidget(conTarjeta(store, apiQue(401)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pending_upload_now')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending_session_expired')), findsOneWidget);
      expect(await store.count(), 1, reason: 'no se pierde ninguna');
      expect(find.textContaining('no se ha perdido ninguna'), findsOneWidget);
    });

    testWidgets('410 vacía la cola local (D6)', (tester) async {
      final store = await almacenCon([captura('a')]);
      await tester.pumpWidget(conTarjeta(store, apiQue(410)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pending_upload_now')));
      await tester.pumpAndSettle();

      expect(await store.count(), 0);
    });
  });

  group('necesita atención: se encamina al reporte de problemas (D5/AC21)', () {
    testWidgets('avisa de las que no se pudieron enviar', (tester) async {
      final store = await almacenCon([
        captura('a', state: PendingState.necesitaAtencion),
      ]);
      await tester.pumpWidget(conTarjeta(store, apiQue(503)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending_needs_attention')), findsOneWidget);
      expect(find.textContaining('Reportar un problema'), findsOneWidget);
    });
  });

  group('AC11 — ningún texto declara éxito antes de tiempo', () {
    test('los dos mensajes existen y dicen cosas distintas', () {
      expect(Copy.captureSavedOffline, isNot(Copy.captureUploaded));
      // El de "guardada" no puede sugerir que ya llegó al servidor.
      expect(Copy.captureSavedOffline.toLowerCase(), contains('tu teléfono'));
      expect(
        Copy.captureSavedOffline.toLowerCase(),
        isNot(contains('registrada')),
      );
    });

    test('registrar() dice si el servidor la confirmó o no', () async {
      final store = await almacenCon([]);
      final container = ProviderContainer(
        overrides: overrides(store, apiQue(201), session: null),
      );
      addTearDown(container.dispose);

      final draft = ObservationDraft(
        lat: 21.88,
        lon: -102.29,
        capturedAt: DateTime.utc(2026, 7, 29, 9),
        nivelG4: NivelG4.leve,
        flagCuscuta: false,
        flagDanio: false,
        tamanio: Tamanio.mediano,
        contexto: Contexto.campoAbierto,
        imageBytes: bytes,
      );

      // Sin sesión no hay a quién atribuirla: se guarda y NO se declara subida.
      final subida = await container
          .read(pendingQueueProvider.notifier)
          .registrar(draft);
      expect(subida, isFalse);
      expect(await store.count(), 1, reason: 'la captura está a salvo en local');
    });

    test('con sesión y servidor OK, la captura se sube y se borra', () async {
      final store = await almacenCon([]);
      final container = ProviderContainer(
        overrides: overrides(store, apiQue(201)),
      );
      addTearDown(container.dispose);

      final draft = ObservationDraft(
        lat: 21.88,
        lon: -102.29,
        capturedAt: DateTime.utc(2026, 7, 29, 9),
        nivelG4: NivelG4.leve,
        flagCuscuta: false,
        flagDanio: false,
        tamanio: Tamanio.mediano,
        contexto: Contexto.campoAbierto,
        imageBytes: bytes,
      );

      final subida = await container
          .read(pendingQueueProvider.notifier)
          .registrar(draft);

      expect(subida, isTrue);
      expect(await store.count(), 0);
    });
  });

  group('account_id desde el JWT', () {
    test('lee el `sub` sin verificar firma y tolera basura', () {
      // {"sub":"abc-123","handle":"x"} en base64url sin relleno.
      final payload = base64Url
          .encode(utf8.encode('{"sub":"abc-123","handle":"x"}'))
          .replaceAll('=', '');
      expect(accountIdFromJwt('cabecera.$payload.firma'), 'abc-123');

      expect(accountIdFromJwt('no-es-un-jwt'), isNull);
      expect(accountIdFromJwt(''), isNull);
      expect(accountIdFromJwt('a.!!!.c'), isNull);
    });
  });
}

/// Sesión fija para las pruebas (evita montar el flujo de Google).
class _AuthFijo extends StateNotifier<AuthSession?> implements AuthController {
  _AuthFijo(AuthSession? session) : super(session);

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
