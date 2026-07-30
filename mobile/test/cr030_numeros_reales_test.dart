import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_app/src/api/api_client.dart';
import 'package:mezquite_app/src/models/models.dart';
import 'package:mezquite_app/src/services/pending/pending_store.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/evidence_screen.dart';
import 'package:mezquite_app/src/ui/screens/profile_screen.dart';

import 'helpers.dart';

/// CR-030 — el voluntario ve números reales.
///
/// Origen: voluntarios reportaron que la app "solo deja registrar 20 mezquites".
/// El registro nunca tuvo tope (producción tenía cuentas con 22, 27, 31 y 37);
/// lo que se congelaba en 20 era el resumen de `/me/feedback`, y el perfil solo
/// mostraba lo confirmado (CR-026), así que quien subió 31 leía "3" y ningún
/// número que reconociera.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// CR-031: Perfil incluye la tarjeta de capturas por subir, que lee el almacén
  /// de pendientes. Se inyecta uno vacío (así la tarjeta se auto-oculta y estas
  /// pruebas siguen midiendo solo lo de CR-030).
  Future<PendingCaptureStore> almacenVacio() async {
    final store = PendingCaptureStore(InMemoryPendingBackend());
    await store.init();
    return store;
  }

  http.Client mockApi(
    Map<String, Object?> profile,
    Map<String, Object?> feedback,
  ) =>
      MockClient((req) async {
        final body = req.url.path.endsWith('/me/profile') ? profile : feedback;
        return http.Response(
          json.encode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

  group('AC-6 — Perfil muestra subidas y confirmadas por separado', () {
    testWidgets('con 31 subidas y 3 confirmadas pinta AMBOS números',
        (tester) async {
      final api = ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: mockApi(
          {
            'handle': 'colibri-azul-42',
            'identity_label': 'observador',
            'institution': 'Universidad Autónoma de Aguascalientes',
            'lifelist_trees': 3,
            'total_observations': 3,
            'total_uploaded': 31,
            'en_revision': 28,
            'total_points': 45,
            'badges': ['primera_observacion'],
          },
          {
            'window': 31,
            'total_considered': 31,
            'validas': 3,
            'en_revision': 28,
            'message': 'Subiste 31 observaciones. 3 ya están confirmadas y '
                '28 siguen en revisión.',
          },
        ),
      );

      await tester.pumpWidget(
        wrap(
          const ProfileScreen(),
          overrides: [
            apiClientProvider.overrideWithValue(api),
            pendingStoreProvider.overrideWithValue(await almacenVacio()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // El número que el voluntario cuenta en campo: presente y etiquetado.
      expect(find.byKey(const Key('activity_subidas')), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.text(Copy.activitySubidas), findsOneWidget);

      // CR-026 sigue al lado, con etiqueta propia: son dos cifras distintas.
      expect(find.byKey(const Key('activity_confirmadas')), findsOneWidget);
      expect(find.text(Copy.activityConfirmadas), findsOneWidget);

      // La brecha se explica como cola de revisión, nunca como rechazo (Q5.A-D1).
      expect(find.byKey(const Key('activity_en_revision')), findsOneWidget);
      expect(
        find.textContaining('28 de tus observaciones siguen en revisión'),
        findsOneWidget,
      );

      // "Tu aporte" queda más abajo en la lista: se baja como haría el usuario.
      await tester.scrollUntilVisible(
        find.byKey(const Key('feedback_message')),
        200,
      );
      await tester.pumpAndSettle();

      // El mensaje del servidor abre con el total real y ya no dice "últimas 20".
      expect(find.textContaining('Subiste 31 observaciones'), findsOneWidget);
      expect(find.textContaining('últimas'), findsNothing);
      expect(find.textContaining('20'), findsNothing);
    });

    testWidgets('con todo revisado no aparece la nota de brecha',
        (tester) async {
      final api = ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: mockApi(
          {
            'handle': 'colibri-azul-42',
            'identity_label': 'observador_experimentado',
            'institution': null,
            'lifelist_trees': 37,
            'total_observations': 37,
            'total_uploaded': 37,
            'en_revision': 0,
            'total_points': 555,
            'badges': ['primera_observacion', 'explorador'],
          },
          {
            'window': 37,
            'total_considered': 37,
            'validas': 37,
            'en_revision': 0,
            'message': 'Subiste 37 observaciones. 37 ya están confirmadas y '
                '0 siguen en revisión.',
          },
        ),
      );

      await tester.pumpWidget(
        wrap(
          const ProfileScreen(),
          overrides: [
            apiClientProvider.overrideWithValue(api),
            pendingStoreProvider.overrideWithValue(await almacenVacio()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Nada en cola ⇒ ninguna nota de brecha que explicar.
      expect(find.byKey(const Key('activity_en_revision')), findsNothing);

      // Este era el caso más confuso: 37 subidas y el resumen decía 20.
      await tester.scrollUntilVisible(
        find.byKey(const Key('feedback_message')),
        200,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Subiste 37 observaciones'), findsOneWidget);
      expect(find.textContaining('últimas 20'), findsNothing);
    });
  });

  group('AC-7 — Mi participación usa el en_revision del servidor', () {
    testWidgets('una rechazada NO se cuenta como "sigue en revisión"',
        (tester) async {
      // El caso real del usuario: 13 subidas, 12 confirmadas, 1 rechazada.
      // Antes la pantalla restaba (13 − 12) y decía "1 sigue en revisión".
      final api = ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient(
          (req) async => http.Response(
            json.encode({
              'capturas': 12,
              'capturas_totales': 13,
              'en_revision': 0,
              'horas_totales': 4.0,
              'sesiones': 4,
              'primera': '2026-06-28T18:00:00Z',
              'ultima': '2026-07-08T17:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        wrap(
          const EvidenceScreen(),
          overrides: [
            apiClientProvider.overrideWithValue(api),
            pendingStoreProvider.overrideWithValue(await almacenVacio()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // El total subido, como cifra propia y visible (CR-030).
      expect(find.byKey(const Key('evidence_subidas')), findsOneWidget);
      expect(find.text(Copy.evidenceSubidas), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      // Nada en cola ⇒ ninguna nota de pendientes que contradiga los números.
      expect(find.byKey(const Key('evidence_pendientes')), findsNothing);
    });
  });

  group('AC-8 — los modelos toleran un backend anterior a CR-030', () {
    test('Profile sin total_uploaded cae al confirmado, no a cero', () {
      final p = Profile.fromJson({
        'handle': 'h',
        'identity_label': 'observador',
        'institution': null,
        'lifelist_trees': 2,
        'total_observations': 2,
        'total_points': 30,
        'badges': <String>[],
      });
      expect(p.totalUploaded, 2);
      expect(p.enRevision, 0);
    });

    test('Evidence sin en_revision cae a la resta antigua', () {
      final e = Evidence.fromJson({
        'capturas': 7,
        'capturas_totales': 10,
        'horas_totales': 1.0,
        'sesiones': 2,
        'primera': null,
        'ultima': null,
      });
      expect(e.pendientes, 3);
    });

    test('Evidence con en_revision usa el valor del servidor', () {
      final e = Evidence.fromJson({
        'capturas': 12,
        'capturas_totales': 13,
        'en_revision': 0,
        'horas_totales': 1.0,
        'sesiones': 2,
        'primera': null,
        'ultima': null,
      });
      expect(e.pendientes, 0);
    });

    test('FeedbackAggregate sin en_revision no revienta', () {
      final f = FeedbackAggregate.fromJson({
        'window': 5,
        'total_considered': 5,
        'validas': 5,
        'message': 'Subiste 5 observaciones.',
      });
      expect(f.enRevision, 0);
      expect(f.totalConsidered, 5);
    });
  });

  test('ningún texto del voluntario promete un tope de 20', () {
    final textos = [
      Copy.activitySubidas,
      Copy.activityConfirmadas,
      Copy.activityArboles,
      Copy.evidenceSubidas,
      Copy.evidenceCapturas,
      Copy.evidenceCapturasNota,
      Copy.feedbackNote,
      Copy.evidenceNote,
    ];
    for (final t in textos) {
      expect(t.contains('20'), isFalse, reason: '"$t" no debe fijar un tope.');
      expect(t.toLowerCase().contains('últimas'), isFalse,
          reason: '"$t" no debe hablar de una ventana de las últimas N.',);
    }
  });
}
