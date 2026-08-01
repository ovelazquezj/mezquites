import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/public_dashboard_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/widgets/paxtle_pie_chart.dart';

import 'helpers.dart';

/// CR-034 — tres peticiones del usuario sobre la consola:
/// 1. El tope silencioso de las listas (mismo defecto que CR-033) en el panel
///    público, el restringido, Datos y el mapa exacto.
/// 2. El panel público pintaba indicadores anidados como "{leve: 3, ...}".
/// 3. Pastel del nivel de paxtle declarado en el panel público.

Map<String, dynamic> _obs(int i) => {
      'handle': 'obs-A',
      'lat': 21.88,
      'lon': -102.29,
      'nivel_g4': 'leve',
      'flag_cuscuta': false,
      'flag_danio': false,
      'estado': 'Aguascalientes',
      'municipio': 'Centro',
      'captured_at': '2026-06-15T12:00:00Z',
      'snapshot_quarter': 'Q2-2026',
    };

ApiClient _client(RequestRecorder rec,
    {http.Response Function(http.BaseRequest req)? responder}) {
  final mock = MockClient((req) async {
    rec.requests.add(req);
    if (responder != null) return responder(req);
    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

void main() {
  group('Listas completas (lazo de offset, CR-034)', () {
    test('publicObservationsAll recorre offsets hasta la página corta',
        () async {
      final rec = RequestRecorder();
      // 5002 filas: página llena (5000) + página corta (2).
      final api = _client(rec, responder: (req) {
        final offset = int.parse(req.url.queryParameters['offset'] ?? '0');
        final n = offset == 0 ? 5000 : 2;
        return http.Response(
            json.encode([for (var i = 0; i < n; i++) _obs(offset + i)]), 200,
            headers: {'content-type': 'application/json'});
      });
      final rows = await api.publicObservationsAll(estado: 'Aguascalientes');
      expect(rows.length, 5002);
      expect(rec.requests.length, 2);
      expect(rec.requests[0].url.queryParameters['limit'], '5000');
      expect(rec.requests[1].url.queryParameters['offset'], '5000');
      // El filtro viaja en TODAS las páginas.
      expect(rec.requests[1].url.queryParameters['estado'], 'Aguascalientes');
    });

    test('restrictedObservationsAll pide el tope del backend con offset',
        () async {
      final rec = RequestRecorder();
      final api = _client(rec);
      await api.restrictedObservationsAll(estadoRevision: 'confirmada');
      final req = rec.requests.single;
      expect(req.url.path, '/api/v1/restricted/observations');
      expect(req.url.queryParameters['limit'], '20000');
      expect(req.url.queryParameters['offset'], '0');
      expect(req.url.queryParameters['estado_revision'], 'confirmada');
    });

    test('analyticsObservationsAll pide el tope del backend con offset',
        () async {
      final rec = RequestRecorder();
      final api = _client(rec);
      await api.analyticsObservationsAll(nivelG4: 'leve');
      final req = rec.requests.single;
      expect(req.url.path, '/api/v1/admin/analytics/observations');
      expect(req.url.queryParameters['limit'], '5000');
      expect(req.url.queryParameters['offset'], '0');
      expect(req.url.queryParameters['nivel_g4'], 'leve');
    });
  });

  group('Panel público (claridad + pastel, CR-034)', () {
    /// Mock del panel: indicadores con mapas anidados (los que salían como
    /// "{...}") y una cola de observaciones de [total] filas que respeta
    /// limit/offset como el backend real.
    ApiClient api(int total) {
      final mock = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/public/indicators')) {
          return http.Response(
              json.encode({
                'snapshot_quarter': 'Q2-2026',
                'caveat': 'caveat',
                'social': {'registrados': 12},
                'educativo': {
                  'distribucion_identidad_e3': {
                    'nuevo_observador': 3,
                    'observador': 1,
                  },
                  'proporcion_confirmada': 0.5,
                },
                'ecologico': {
                  'arboles_unicos': 4,
                  'distribucion_niveles': {'leve': 3, 'moderado': 1},
                },
                'organizacional': {},
              }),
              200,
              headers: {'content-type': 'application/json'});
        }
        if (path.endsWith('/public/observations')) {
          final limit = int.parse(req.url.queryParameters['limit'] ?? '500');
          final offset = int.parse(req.url.queryParameters['offset'] ?? '0');
          final fin = (offset + limit) > total ? total : (offset + limit);
          return http.Response(
              json.encode([for (var i = offset; i < fin; i++) _obs(i)]), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      });
      return ApiClient(
          baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
    }

    Widget screen(ApiClient api) => ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const MaterialApp(
              home: Scaffold(body: PublicDashboardScreen())),
        );

    testWidgets('muestra MÁS de 200 observaciones (el tope era del cliente)',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(screen(api(331)));
      await tester.pumpAndSettle();

      // El rango puede quedar fuera de pantalla, pero el árbol ya lo tiene.
      expect(find.text('1–10 de 331'), findsOneWidget);
    });

    testWidgets('ningún indicador se pinta como mapa crudo "{...}"',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(screen(api(4)));
      await tester.pumpAndSettle();

      expect(find.textContaining('{'), findsNothing);
      // Los desgloses salen legibles y traducidos.
      expect(find.byKey(const Key('breakdown-distribucion_identidad_e3')),
          findsOneWidget);
      expect(find.text('Nuevo observador — 3'), findsOneWidget);
      expect(find.text('Observador — 1'), findsOneWidget);
      // La proporción sale como porcentaje, no como fracción.
      expect(find.text('50 %'), findsOneWidget);
      expect(find.text('0.5'), findsNothing);
    });

    testWidgets('el pastel de nivel de paxtle pinta rebanadas y leyenda',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(screen(api(4)));
      await tester.pumpAndSettle();

      final pie = find.byKey(const Key('paxtle-pie'));
      expect(pie, findsOneWidget);
      // Visible de verdad (la trampa de CR-029/CR-032: estar en el árbol no
      // es ser visible).
      expect(tester.getSize(pie).height, greaterThan(0));
      // Leyenda con conteo y porcentaje: legible sin depender del color.
      expect(find.text('Leve — 3 (75 %)'), findsOneWidget);
      expect(find.text('Moderado — 1 (25 %)'), findsOneWidget);
      expect(find.text('Total: 4 observaciones confirmadas'), findsOneWidget);
    });
  });

  group('PaxtlePieChart (unidad)', () {
    testWidgets('sin datos muestra el vacío honesto, no un círculo vacío',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: PaxtlePieChart(conteos: {}))));
      expect(find.byKey(const Key('paxtle-pie-empty')), findsOneWidget);
      expect(find.byKey(const Key('paxtle-pie')), findsNothing);
    });

    testWidgets('un solo nivel = círculo completo con su leyenda al 100 %',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: PaxtlePieChart(conteos: {'severo': 7}))));
      expect(find.byKey(const Key('paxtle-pie')), findsOneWidget);
      expect(find.text('Severo — 7 (100 %)'), findsOneWidget);
    });

    testWidgets('los niveles en cero no aparecen en la leyenda',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: PaxtlePieChart(conteos: {'sano': 0, 'leve': 2}))));
      expect(find.byKey(const Key('paxtle-pie-legend-sano')), findsNothing);
      expect(find.text('Leve — 2 (100 %)'), findsOneWidget);
    });
  });
}
