import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/map_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// Dos árboles cerca del centro de Aguascalientes (para que caigan en el
/// viewport inicial del mapa y sus marcadores rendericen en el test).
const _obsA = {
  'handle': 'obs-A',
  'lat': 21.885,
  'lon': -102.291,
  'nivel_g4': 'severo',
  'flag_cuscuta': true,
  'flag_danio': true,
  'estado': 'Aguascalientes',
  'municipio': 'Aguascalientes',
  'captured_at': '2026-06-15T12:00:00Z',
  'estado_revision': 'aceptada',
};
const _obsB = {
  'handle': 'obs-B',
  'lat': 21.886,
  'lon': -102.292,
  'nivel_g4': 'leve',
  'flag_cuscuta': false,
  'flag_danio': false,
  'estado': 'Aguascalientes',
  'municipio': 'Aguascalientes',
  'captured_at': '2026-06-16T12:00:00Z',
  'estado_revision': 'confirmada',
};

/// ApiClient mock que sirve el mapa de calor (/public/grid) y las ubicaciones
/// exactas (/restricted/observations) con dos observaciones conocidas.
ApiClient _api(RequestRecorder rec) {
  final mock = MockClient((req) async {
    rec.requests.add(req);
    final path = req.url.path;
    if (path.endsWith('/restricted/observations')) {
      return http.Response(json.encode([_obsA, _obsB]), 200,
          headers: {'content-type': 'application/json'});
    }
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
    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

Widget _mapAs(String role, RequestRecorder rec) {
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
    child: const MaterialApp(home: Scaffold(body: MapScreen())),
  );
}

void main() {
  void big(WidgetTester tester) {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  // CR-025: la ubicación exacta es pública → TODOS los roles de la consola
  // (incluido evaluador) ven el toggle calor ⇄ exacto.
  for (final role in [
    'administrador',
    'analista',
    'admin_consorcio',
    'evaluador'
  ]) {
    testWidgets('el toggle de modo aparece para $role (CR-025)',
        (tester) async {
      big(tester);
      await tester.pumpWidget(_mapAs(role, RequestRecorder()));
      await tester.pump();
      expect(find.byKey(const Key('map_mode_toggle')), findsOneWidget,
          reason: '$role puede conmutar a ubicaciones exactas');
      // Sí ve el mapa de calor base.
      expect(find.byKey(const Key('heat_map')), findsOneWidget);
    });
  }

  testWidgets('el toggle NO aparece sin sesión (público)', (tester) async {
    big(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(_api(rec))],
      child: const MaterialApp(home: Scaffold(body: MapScreen())),
    ));
    await tester.pump();
    expect(find.byKey(const Key('map_mode_toggle')), findsNothing);
  });

  testWidgets(
      'modo exacto: renderiza un marcador por observación, sin banner (CR-025)',
      (tester) async {
    big(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_mapAs('administrador', rec));
    await tester.pump();

    // Conmuta a "Ubicaciones exactas".
    await tester.tap(find.text(Copy.mapModeExact));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Pidió las coords exactas.
    expect(rec.hitPathContaining('/restricted/observations'), isTrue);
    // Mapa exacto montado; sin banner de "uso interno" (la ubicación es pública).
    expect(find.byKey(const Key('exact_map')), findsOneWidget);
    expect(find.byKey(const Key('map_exact_banner')), findsNothing);
    // Un marcador por cada una de las 2 observaciones devueltas.
    expect(find.byKey(const Key('exact_marker_21.885_-102.291')),
        findsOneWidget);
    expect(find.byKey(const Key('exact_marker_21.886_-102.292')),
        findsOneWidget);
  });
}
