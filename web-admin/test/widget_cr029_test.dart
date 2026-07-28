import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/institutions_screen.dart';
import 'package:mezquite_web_admin/src/screens/monitor_screen.dart';
import 'package:mezquite_web_admin/src/screens/review_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';

import 'helpers.dart';

/// CR-029 — tres correcciones de la consola:
///   1. el Monitor distingue observaciones revisadas de veredictos emitidos (el "58 vs 61");
///   2. el veredicto que ya es el estado actual no se puede volver a emitir;
///   3. la foto de revisión se puede ampliar;
///   4. las instituciones se pueden editar.
final List<int> _kPng1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

void main() {
  void big(WidgetTester t) {
    t.view.physicalSize = const Size(1500, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
  }

  Widget wrapAs(Widget child, ApiClient api, {String role = 'administrador'}) =>
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionProvider.overrideWith((ref) {
            final c = SessionController(api);
            c.loginWithToken(fakeJwt(handle: 'obs-x', role: role));
            return c;
          }),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  // --- 1. Monitor: dos números que ya no parecen contradecirse ---

  group('CR-029 #1 — el Monitor distingue observaciones de veredictos', () {
    ApiClient statsApi() => ApiClient(
          baseUrl: 'http://localhost:8000/api/v1',
          httpClient: MockClient((req) async => http.Response(
              json.encode({
                'aceptadas': 0,
                'confirmadas': 57,
                'rechazadas': 1,
                'total': 58,
                'pendientes_de_revision': 0,
                'revisiones_totales': 61,
                'observaciones_revisadas': 58,
              }),
              200,
              headers: {'content-type': 'application/json'})),
        );

    testWidgets('pinta el escenario reportado (58 observaciones, 61 veredictos)',
        (tester) async {
      big(tester);
      await tester.pumpWidget(wrapAs(const MonitorScreen(), statsApi()));
      await tester.pumpAndSettle();

      // La tarjeta nueva es la comparable con el total de observaciones.
      expect(find.byKey(const Key('monitor-revisadas')), findsOneWidget);
      expect(
        find.descendant(
            of: find.byKey(const Key('monitor-revisadas')), matching: find.text('58')),
        findsOneWidget,
      );
      // Y la de eventos queda etiquetada como lo que es.
      expect(
        find.descendant(
            of: find.byKey(const Key('monitor-revisiones')), matching: find.text('61')),
        findsOneWidget,
      );
      expect(find.textContaining('Veredictos emitidos'), findsOneWidget);
      expect(find.text('Revisiones registradas'), findsNothing);
    });
  });

  // --- 2 y 3. Revisión: botón del estado vigente + zoom ---

  group('CR-029 #2/#3 — revisión: estado vigente y zoom', () {
    ApiClient reviewApi(String estadoRevision) => ApiClient(
          baseUrl: 'http://localhost:8000/api/v1',
          httpClient: MockClient((req) async {
            final p = req.url.path;
            if (p.endsWith('/image')) {
              return http.Response.bytes(_kPng1x1, 200,
                  headers: {'content-type': 'image/png'});
            }
            if (p.contains('/review/observations/')) {
              return http.Response(
                  json.encode({
                    'observation_id': 'o1',
                    'handle': 'obs-A',
                    'captured_at': '2026-06-15T12:00:00Z',
                    'estado_revision': estadoRevision,
                    'nivel_g4': 'leve',
                    'flag_cuscuta': false,
                    'flag_danio': false,
                    'tamanio': 'mediano',
                    'contexto': 'campo_abierto',
                    'estado': 'Ags',
                    'municipio': 'Centro',
                    'historial': const [],
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }
            return http.Response('[]', 200,
                headers: {'content-type': 'application/json'});
          }),
        );

    Future<void> abrirDetalle(WidgetTester tester, String estado) async {
      big(tester);
      await tester.pumpWidget(wrapAs(
          const ReviewDetailDialog(observationId: 'o1'), reviewApi(estado),
          role: 'evaluador'));
      await tester.pumpAndSettle();
    }

    bool habilitado(WidgetTester tester, String key) {
      final w = tester.widget(find.byKey(Key(key)));
      return (w as dynamic).onPressed != null;
    }

    testWidgets('una observación CONFIRMADA no deja volver a confirmarla',
        (tester) async {
      await abrirDetalle(tester, 'confirmada');
      expect(habilitado(tester, 'review-confirm'), isFalse,
          reason: 'volver a confirmar añadía una fila redundante al log');
      expect(habilitado(tester, 'review-reject'), isTrue);
      expect(habilitado(tester, 'review-reopen'), isTrue);
      expect(find.byKey(const Key('review-current-state')), findsOneWidget);
    });

    testWidgets('una observación ACEPTADA no deja "volver a aceptada"',
        (tester) async {
      await abrirDetalle(tester, 'aceptada');
      expect(habilitado(tester, 'review-reopen'), isFalse);
      expect(habilitado(tester, 'review-confirm'), isTrue);
      expect(habilitado(tester, 'review-reject'), isTrue);
    });

    testWidgets('una observación RECHAZADA no deja volver a retirarla',
        (tester) async {
      await abrirDetalle(tester, 'rechazada');
      expect(habilitado(tester, 'review-reject'), isFalse);
      expect(habilitado(tester, 'review-confirm'), isTrue);
    });

    testWidgets('clic en la foto abre el visor con controles de zoom',
        (tester) async {
      await abrirDetalle(tester, 'aceptada');

      expect(find.byKey(const Key('review-image-zoom')), findsNothing);
      await tester.tap(find.byKey(const Key('review-image-open-zoom')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review-image-zoom')), findsOneWidget);
      for (final k in ['review-zoom-in', 'review-zoom-out', 'review-zoom-reset']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }

      // Acercar cambia la transformación; restablecer la deja en identidad.
      final viewer = tester.widget<InteractiveViewer>(
          find.byKey(const Key('review-image-zoom')));
      final tc = viewer.transformationController!;
      await tester.tap(find.byKey(const Key('review-zoom-in')));
      await tester.pumpAndSettle();
      expect(tc.value.getMaxScaleOnAxis(), greaterThan(1.0));

      await tester.tap(find.byKey(const Key('review-zoom-reset')));
      await tester.pumpAndSettle();
      expect(tc.value.getMaxScaleOnAxis(), closeTo(1.0, 0.001));

      await tester.tap(find.byKey(const Key('review-zoom-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review-image-zoom')), findsNothing);
    });
  });

  // --- 4. Instituciones: editar ---

  group('CR-029 #4 — editar una institución', () {
    ApiClient instApi({required int patchStatus, List<http.Request>? patches}) =>
        ApiClient(
          baseUrl: 'http://localhost:8000/api/v1',
          httpClient: MockClient((req) async {
            final p = req.url.path;
            if (p.contains('/admin/institutions/') && req.method == 'PATCH') {
              patches?.add(req);
              if (patchStatus == 409) {
                return http.Response(
                    json.encode({
                      'detail': 'Ya existe la institución "Otra" (ya aprobada). '
                          'Elige otro nombre.'
                    }),
                    409,
                    headers: {'content-type': 'application/json'});
              }
              return http.Response(
                  json.encode({
                    'id': 'i1',
                    'name': 'Prepa Corregida',
                    'estado': 'Aguascalientes',
                    'status': 'aprobada'
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }
            if (p.endsWith('/admin/institutions') && req.method == 'GET') {
              return http.Response(
                  json.encode([
                    {
                      'id': 'i1',
                      'name': 'Prepa Mal Escrita',
                      'estado': 'Jalisco',
                      'status': 'aprobada'
                    }
                  ]),
                  200,
                  headers: {'content-type': 'application/json'});
            }
            return http.Response('[]', 200,
                headers: {'content-type': 'application/json'});
          }),
        );

    Future<void> abrirEdicion(WidgetTester tester, ApiClient api) async {
      big(tester);
      await tester.pumpWidget(wrapAs(const InstitutionsScreen(), api));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('institution-edit-i1')));
      await tester.pumpAndSettle();
    }

    testWidgets('el diálogo llega precargado y guarda por PATCH', (tester) async {
      final patches = <http.Request>[];
      await abrirEdicion(tester, instApi(patchStatus: 200, patches: patches));

      // Precargado con lo que ya tenía.
      expect(find.widgetWithText(TextField, 'Prepa Mal Escrita'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Jalisco'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('institution-edit-name')), 'Prepa Corregida');
      await tester.enterText(
          find.byKey(const Key('institution-edit-estado')), 'Aguascalientes');
      await tester.tap(find.byKey(const Key('institution-edit-save')));
      await tester.pumpAndSettle();

      expect(patches, hasLength(1));
      final body = json.decode(patches.single.body) as Map<String, dynamic>;
      expect(body['name'], 'Prepa Corregida');
      expect(body['estado'], 'Aguascalientes');
      // El status NO viaja: la edición no puede degradar una aprobada.
      expect(body.containsKey('status'), isFalse);
      expect(find.textContaining('actualizada'), findsOneWidget);
    });

    testWidgets('un nombre ya usado (409) se explica sin cerrar el diálogo',
        (tester) async {
      await abrirEdicion(tester, instApi(patchStatus: 409));

      await tester.enterText(
          find.byKey(const Key('institution-edit-name')), 'Otra');
      await tester.tap(find.byKey(const Key('institution-edit-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('institution-edit-error')), findsOneWidget);
      expect(find.textContaining('Ya existe otra institución'), findsOneWidget);
      // Sigue abierto para corregir en el momento.
      expect(find.byKey(const Key('institution-edit-name')), findsOneWidget);
    });

    testWidgets('el botón Editar está en todas, aprobadas incluidas',
        (tester) async {
      big(tester);
      await tester.pumpWidget(wrapAs(const InstitutionsScreen(), instApi(patchStatus: 200)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('institution-edit-i1')), findsOneWidget);
      // Aprobada ⇒ no se ofrece "Aprobar".
      expect(find.byKey(const Key('institution-approve-i1')), findsNothing);
    });
  });
}
