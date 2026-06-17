import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_app/src/api/api_client.dart';
import 'package:mezquite_app/src/services/session_store.dart';
import 'package:mezquite_app/src/services/session_tracker.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/account_screen.dart';
import 'package:mezquite_app/src/ui/screens/evidence_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// CR-010 (carril móvil): registrar institución (#6), evidencia (#7) y
/// rastreo de tiempo de sesión (#7). Las pruebas MOCKEAN la API según el
/// contrato de CR-010 (no dependen del backend corriendo).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Siembra una sesión persistida para que `authProvider` arranque "logueado".
  Future<SessionStore> seededStore() async {
    SharedPreferences.setMockInitialValues({
      'session_handle': 'colibri-azul-42',
      'session_role': 'voluntario',
      'session_token': 'tok-123',
    });
    return SessionStore.create();
  }

  group('CR-010 #6 — Registrar nueva institución', () {
    testWidgets('el flujo POSTea /institutions/request y confirma',
        (tester) async {
      final store = await seededStore();
      http.Request? captured;
      final mock = MockClient((req) async {
        captured = req;
        return http.Response(
          json.encode({
            'id': 'inst-9',
            'name': 'Mi Prepa',
            'status': 'solicitada',
          }),
          201,
        );
      });
      final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

      await tester.pumpWidget(
        wrap(
          const AccountScreen(),
          overrides: [
            sessionStoreProvider.overrideWithValue(store),
            apiClientProvider.overrideWithValue(api),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // El botón abre el diálogo de registro (ya no es solo un SnackBar).
      await tester.tap(find.byKey(const Key('account_request_institution')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('institution_name_field')), findsOneWidget);

      // Nombre vacío → error de validación, sin POST.
      await tester.tap(find.byKey(const Key('institution_request_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('institution_request_error')), findsOneWidget);
      expect(captured, isNull);

      // Con nombre → POST al endpoint del contrato.
      await tester.enterText(
        find.byKey(const Key('institution_name_field')),
        'Mi Prepa',
      );
      await tester.tap(find.byKey(const Key('institution_request_submit')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/institutions/request');
      final body = json.decode(captured!.body) as Map<String, dynamic>;
      expect(body['name'], 'Mi Prepa');
      expect(body['estado'], 'Aguascalientes');

      // Confirmación al usuario (SnackBar).
      expect(find.text(Copy.institutionRequestOk), findsOneWidget);
    });
  });

  group('CR-010 #7 — Evidencia (comprobante de participación)', () {
    testWidgets('la pantalla renderiza capturas + horas + sesiones del API',
        (tester) async {
      final mock = MockClient((req) async {
        expect(req.url.path, '/api/v1/me/evidence');
        return http.Response(
          json.encode({
            'capturas': 7,
            'horas_totales': 3.5,
            'sesiones': 4,
            'primera': '2026-05-01T10:00:00Z',
            'ultima': '2026-06-10T18:00:00Z',
          }),
          200,
        );
      });
      final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

      await tester.pumpWidget(
        wrap(
          const EvidenceScreen(),
          overrides: [apiClientProvider.overrideWithValue(api)],
        ),
      );
      await tester.pumpAndSettle();

      // Conteos del contrato visibles.
      expect(find.text('7'), findsOneWidget); // capturas
      expect(find.text('3.5'), findsOneWidget); // horas
      expect(find.text('4'), findsOneWidget); // sesiones
      // Rango de fechas presente.
      expect(find.byKey(const Key('evidence_rango')), findsOneWidget);
      expect(find.textContaining('01/05/2026'), findsOneWidget);

      // Gate #1: nada de control/manejo en la pantalla.
      expect(find.textContaining('control'), findsNothing);
    });

    testWidgets('sin actividad muestra el aviso de rango vacío', (tester) async {
      final mock = MockClient((req) async {
        return http.Response(
          json.encode({
            'capturas': 0,
            'horas_totales': 0.0,
            'sesiones': 0,
            'primera': null,
            'ultima': null,
          }),
          200,
        );
      });
      final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

      await tester.pumpWidget(
        wrap(
          const EvidenceScreen(),
          overrides: [apiClientProvider.overrideWithValue(api)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Copy.evidenceSinRango), findsOneWidget);
    });
  });

  group('CR-010 #7 — Rastreo de tiempo de sesión (lifecycle)', () {
    testWidgets(
        'al pausar/cerrar cierra el tramo y POSTea {started_at, ended_at}',
        (tester) async {
      // API mock: registra el body enviado a /me/sessions.
      Map<String, dynamic>? sessionBody;
      String? sessionPath;
      final mock = MockClient((req) async {
        sessionPath = req.url.path;
        sessionBody = json.decode(req.body) as Map<String, dynamic>;
        return http.Response('{}', 201);
      });
      final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

      // Reloj inyectado: avanza 1 hora entre abrir y cerrar el tramo.
      final times = <DateTime>[
        DateTime.utc(2026, 6, 1, 9, 0, 0), // start()
        DateTime.utc(2026, 6, 1, 10, 0, 0), // close()
      ];
      var i = 0;
      final tracker = SessionTracker(api, now: () => times[i++]);

      tracker.start();
      expect(tracker.isOpen, isTrue);

      // Simula el ciclo de vida → pausa (cierra y envía el tramo).
      tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(tracker.isOpen, isFalse);
      expect(sessionPath, '/api/v1/me/sessions');
      expect(sessionBody, isNotNull);
      expect(sessionBody!['started_at'], '2026-06-01T09:00:00.000Z');
      expect(sessionBody!['ended_at'], '2026-06-01T10:00:00.000Z');
      // Gate #2: solo tiempos, sin PII.
      expect(sessionBody!.containsKey('account_id'), isFalse);
      expect(sessionBody!.containsKey('handle'), isFalse);

      await tracker.stop();
    });
  });
}
