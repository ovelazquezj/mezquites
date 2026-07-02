import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/data_screen.dart';
import 'package:mezquite_web_admin/src/screens/home_shell.dart';
import 'package:mezquite_web_admin/src/screens/map_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// ApiClient mock que cubre el mapa (/public/grid) y la analítica del analista
/// (/admin/analytics/*). Registra las rutas pedidas para aserciones.
ApiClient _api(RequestRecorder rec) {
  final mock = MockClient((req) async {
    rec.requests.add(req);
    final path = req.url.path;
    if (path.endsWith('/public/grid')) {
      return http.Response(
          json.encode([
            {
              'lat': 21.88,
              'lon': -102.29,
              'n': 3,
              'n_paxtle': 2,
              'n_cuscuta': 1,
              'g4_indice': 1.5,
              'snapshot_quarter': 'Q2-2026'
            }
          ]),
          200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/admin/analytics/summary')) {
      return http.Response(
          json.encode({
            'total': 7,
            'por_estado_revision': {'aceptada': 5, 'confirmada': 1, 'rechazada': 1},
            'por_nivel_g4': {'leve': 4, 'severo': 3},
            'por_municipio': {'Centro': 7},
            'snapshot_quarter': 'Q2-2026'
          }),
          200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/admin/analytics/observations.csv')) {
      return http.Response(
          'handle,fecha,estado_revision\nobs-A,2026-06-15,aceptada\n', 200,
          headers: {'content-type': 'text/csv'});
    }
    if (path.endsWith('/admin/analytics/observations')) {
      return http.Response(
          json.encode([
            {
              'observation_id': 'o1',
              'handle': 'obs-A',
              'captured_at': '2026-06-15T12:00:00Z',
              'estado_revision': 'aceptada',
              'nivel_g4': 'leve',
              'flag_cuscuta': false,
              'flag_danio': true,
              'estado': 'Ags',
              'municipio': 'Centro'
            }
          ]),
          200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/public/indicators')) {
      return http.Response(
          json.encode({
            'snapshot_quarter': 'Q2-2026',
            'caveat': 'caveat',
            'social': {},
            'educativo': {},
            'ecologico': {},
            'organizacional': {}
          }),
          200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/review/stats')) {
      return http.Response(
          json.encode({
            'aceptadas': 1,
            'confirmadas': 0,
            'rechazadas': 0,
            'total': 1,
            'pendientes_de_revision': 1,
            'revisiones_totales': 0
          }),
          200,
          headers: {'content-type': 'application/json'});
    }
    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

Widget _shellAs(String role, RequestRecorder rec) {
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
    child: const MaterialApp(home: HomeShell()),
  );
}

Widget _dataAs(String role, RequestRecorder rec) {
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
    child: const MaterialApp(home: Scaffold(body: DataScreen())),
  );
}

void main() {
  void big(WidgetTester tester) {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('el header muestra el logo del Club Rotario (CR-010 #1)',
      (tester) async {
    big(tester);
    await tester.pumpWidget(_shellAs('administrador', RequestRecorder()));
    await tester.pump();

    expect(find.byKey(const Key('appbar-logo')), findsOneWidget);
    expect(find.text(Copy.orgName), findsWidgets);
  });

  for (final role in [
    'evaluador',
    'analista',
    'administrador',
    'admin_consorcio'
  ]) {
    testWidgets('Mapa es visible para $role (CR-010 #2)', (tester) async {
      big(tester);
      await tester.pumpWidget(_shellAs(role, RequestRecorder()));
      await tester.pump();
      expect(find.text(Copy.navMap), findsWidgets,
          reason: 'El rol $role debe ver la pestaña Mapa');
    });
  }

  testWidgets('Datos visible para analista (CR-010 #3)', (tester) async {
    big(tester);
    await tester.pumpWidget(_shellAs('analista', RequestRecorder()));
    await tester.pump();
    expect(find.text(Copy.navData), findsWidgets);
  });

  testWidgets('Datos visible para administrador (CR-010 #3)', (tester) async {
    big(tester);
    await tester.pumpWidget(_shellAs('administrador', RequestRecorder()));
    await tester.pump();
    expect(find.text(Copy.navData), findsWidgets);
  });

  testWidgets('Datos NO visible para evaluador (CR-010 #3)', (tester) async {
    big(tester);
    await tester.pumpWidget(_shellAs('evaluador', RequestRecorder()));
    await tester.pump();
    expect(find.text(Copy.navData), findsNothing);
  });

  testWidgets('analista ve tabla de datos + botón Descargar CSV (CR-010 #3)',
      (tester) async {
    big(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_dataAs('analista', rec));
    await tester.pumpAndSettle();

    // Botón de descarga + tarjetas de resumen + tabla.
    expect(find.byKey(const Key('data-download-csv')), findsOneWidget);
    expect(find.byKey(const Key('data-summary')), findsOneWidget);
    // La tabla renderó la observación devuelta por el mock: su handle aparece en
    // una celda (la `key` de un DataRow no es localizable con find.byKey).
    expect(find.text('obs-A'), findsWidgets);
    // Pidió el resumen y las observaciones.
    expect(rec.hitPathContaining('/admin/analytics/summary'), isTrue);
    expect(rec.hitPathContaining('/admin/analytics/observations'), isTrue);
  });

  testWidgets('analista ve el aviso de CSV con coords exactas (CR-023)',
      (tester) async {
    big(tester);
    await tester.pumpWidget(_dataAs('analista', RequestRecorder()));
    await tester.pumpAndSettle();
    // La nota original de privacidad sigue presente (no la rompemos).
    expect(find.byKey(const Key('data-location-note')), findsOneWidget);
    // Y el aviso extra de CR-023 (coords exactas en el CSV).
    expect(find.byKey(const Key('data-exact-note')), findsOneWidget);
  });

  testWidgets('evaluador NO ve el aviso de coords exactas del CSV (CR-023)',
      (tester) async {
    big(tester);
    await tester.pumpWidget(_dataAs('evaluador', RequestRecorder()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('data-location-note')), findsOneWidget);
    expect(find.byKey(const Key('data-exact-note')), findsNothing);
  });

  testWidgets('Descargar CSV baja el CSV por fetch autenticado (CR-010 #3)',
      (tester) async {
    big(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_dataAs('analista', rec));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('data-download-csv')));
    await tester.pumpAndSettle();

    expect(rec.hitPathContaining('/admin/analytics/observations.csv'), isTrue);
    expect(find.text(Copy.dataDownloadDone), findsOneWidget);
  });

  testWidgets('mapa: la pestaña Mapa carga la grilla pública (gate #5, ~300 m)',
      (tester) async {
    big(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_api(rec))],
        child: const MaterialApp(home: Scaffold(body: MapScreen())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('heat_map')), findsOneWidget);
    expect(find.byKey(const Key('heat_legend')), findsOneWidget);
    expect(rec.hitPathContaining('/public/grid'), isTrue);
  });
}
