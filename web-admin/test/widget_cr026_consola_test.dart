import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/data_screen.dart';
import 'package:mezquite_web_admin/src/screens/map_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// CR-026 (solicitud de las universidades participantes), carril consola:
///
/// - **G1:** el mapa de la consola arranca mostrando lo mismo que el público
///   (confirmadas) pero conserva un selector para ver la cola de revisión y las
///   rechazadas. Si solo pudiera ver lo confirmado, el evaluador perdería de
///   vista justo lo que le falta revisar.
/// - **F:** la pantalla Datos ofrece el reporte de participación por día.

const _obs = {
  'handle': 'obs-A',
  'lat': 21.885,
  'lon': -102.291,
  'nivel_g4': 'severo',
  'flag_cuscuta': true,
  'flag_danio': true,
  'estado': 'Aguascalientes',
  'municipio': 'Aguascalientes',
  'captured_at': '2026-06-15T12:00:00Z',
  'estado_revision': 'confirmada',
};

ApiClient _api(RequestRecorder rec) {
  final mock = MockClient((req) async {
    rec.requests.add(req);
    final path = req.url.path;
    if (path.endsWith('/restricted/observations')) {
      return http.Response(json.encode([_obs]), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/public/grid')) {
      return http.Response('[]', 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('participation.csv')) {
      return http.Response('fecha,handle\n2026-06-17,obs-A\n', 200,
          headers: {'content-type': 'text/csv'});
    }
    if (path.endsWith('observations.csv')) {
      return http.Response('observation_id\n', 200,
          headers: {'content-type': 'text/csv'});
    }
    if (path.endsWith('/admin/analytics/summary')) {
      return http.Response(
          json.encode({
            'por_estado_revision': {'confirmada': 1},
            'por_municipio': {'Aguascalientes': 1},
            'por_nivel_g4': {'severo': 1},
            'total': 1,
          }),
          200,
          headers: {'content-type': 'application/json'});
    }
    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

Widget _screenAs(String role, RequestRecorder rec, Widget child) {
  final api = _api(rec);
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      sessionProvider.overrideWith((ref) {
        final c = SessionController(api);
        c.loginWithToken(fakeJwt(handle: 'obs-$role', role: role));
        return c;
      }),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Query string de la última petición a una ruta dada.
Map<String, String> _lastQueryFor(RequestRecorder rec, String fragment) =>
    rec.requests.lastWhere((r) => r.url.path.contains(fragment)).url
        .queryParameters;

void main() {
  void big(WidgetTester tester) {
    tester.view.physicalSize = const Size(1500, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> goExact(WidgetTester tester) async {
    await tester.tap(find.text(Copy.mapModeExact));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('CR-026 G1 — filtro de estado de revisión en el mapa de la consola', () {
    testWidgets('el modo exacto arranca en confirmadas (lo que ve el público)',
        (tester) async {
      big(tester);
      final rec = RequestRecorder();
      await tester.pumpWidget(
          _screenAs('evaluador', rec, const MapScreen()));
      await tester.pump();
      await goExact(tester);

      expect(find.byKey(const Key('map_review_filter')), findsOneWidget);
      expect(find.byKey(const Key('map_filter_note')), findsOneWidget);
      expect(
        _lastQueryFor(rec, '/restricted/observations')['estado_revision'],
        'confirmada',
      );
    });

    testWidgets('se puede ver la cola de revisión sin salir del mapa',
        (tester) async {
      big(tester);
      final rec = RequestRecorder();
      await tester.pumpWidget(
          _screenAs('evaluador', rec, const MapScreen()));
      await tester.pump();
      await goExact(tester);

      await tester.tap(find.byKey(const Key('map_review_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Copy.mapFilterPendientes).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        _lastQueryFor(rec, '/restricted/observations')['estado_revision'],
        'aceptada',
      );
    });

    testWidgets('"Todas" no manda filtro: el backend devuelve todo',
        (tester) async {
      big(tester);
      final rec = RequestRecorder();
      await tester.pumpWidget(
          _screenAs('administrador', rec, const MapScreen()));
      await tester.pump();
      await goExact(tester);

      await tester.tap(find.byKey(const Key('map_review_filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Copy.mapFilterTodas).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final q = _lastQueryFor(rec, '/restricted/observations');
      expect(q.containsKey('estado_revision'), isFalse);
    });

    testWidgets('el filtro no aparece en modo calor', (tester) async {
      big(tester);
      await tester.pumpWidget(
          _screenAs('analista', RequestRecorder(), const MapScreen()));
      await tester.pump();
      expect(find.byKey(const Key('map_review_filter')), findsNothing);
    });
  });

  group('CR-026 F — reporte de participación por día', () {
    testWidgets('la pantalla Datos ofrece la descarga y advierte qué miden las horas',
        (tester) async {
      big(tester);
      final rec = RequestRecorder();
      await tester.pumpWidget(
          _screenAs('analista', rec, const DataScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('data-download-participation-csv')),
          findsOneWidget);
      // La nota evita que el evaluador lea las horas como constancia de campo.
      expect(find.byKey(const Key('data-participation-note')), findsOneWidget);

      await tester.tap(
          find.byKey(const Key('data-download-participation-csv')));
      await tester.pumpAndSettle();

      expect(rec.hitPathContaining('/admin/analytics/participation.csv'),
          isTrue);
    });

    testWidgets('sigue existiendo la descarga de observaciones', (tester) async {
      big(tester);
      final rec = RequestRecorder();
      await tester.pumpWidget(
          _screenAs('analista', rec, const DataScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('data-download-csv')));
      await tester.pumpAndSettle();

      expect(rec.hitPathContaining('/admin/analytics/observations.csv'), isTrue);
    });
  });
}
