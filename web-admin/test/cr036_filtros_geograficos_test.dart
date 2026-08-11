// CR-036: la consola filtra por estado y municipio, y el mapa encuadra sobre los datos.
//
// Las tres cosas que estas pruebas fijan tienen la misma raíz: la consola daba por hecho que el
// dataset era de un solo estado. El Panel público ofrecía un campo de texto libre, Datos ni
// siquiera tenía filtro de estado (aunque el backend lo aceptaba desde CR-010), y los dos mapas
// centraban en Aguascalientes con un `const`, así que una observación de otro estado quedaba
// fuera de cuadro sin que nadie lo notara.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/map_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/widgets/geo_filter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Envoltura mínima: solo hace falta el `apiClientProvider` (el filtro no mira la sesión).
Widget envolver(Widget child, ApiClient api) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(home: child),
    );

/// Catálogo mínimo con dos entidades y un homónimo entre ellas.
String _estadosJson() => json.encode([
      {'cve_ent': '01', 'estado': 'Aguascalientes'},
      {'cve_ent': '32', 'estado': 'Zacatecas'},
    ]);

String _municipiosJson(String cveEnt) => json.encode(
      cveEnt == '32'
          ? [
              {
                'cve_ent': '32',
                'cve_mun': '019',
                'estado': 'Zacatecas',
                'municipio': 'Jalpa',
              },
            ]
          : [
              {
                'cve_ent': '01',
                'cve_mun': '001',
                'estado': 'Aguascalientes',
                'municipio': 'Aguascalientes',
              },
              {
                'cve_ent': '01',
                'cve_mun': '005',
                'estado': 'Aguascalientes',
                'municipio': 'Jesús María',
              },
            ],
    );

void main() {
  group('AC18/AC19 — filtro de estado y municipio', () {
    testWidgets('el municipio solo aparece tras elegir estado, y viaja por clave',
        (tester) async {
      final peticiones = <Uri>[];
      final mock = MockClient((req) async {
        peticiones.add(req.url);
        if (req.url.path.endsWith('/geo/estados')) {
          return http.Response(_estadosJson(), 200);
        }
        if (req.url.path.endsWith('/geo/municipios')) {
          return http.Response(
            _municipiosJson(req.url.queryParameters['cve_ent'] ?? '01'),
            200,
          );
        }
        return http.Response('[]', 200);
      });
      final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

      GeoSeleccion seleccion = const GeoSeleccion();
      await tester.pumpWidget(
        envolver(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: GeoFilter(
                value: seleccion,
                onChanged: (v) => setState(() => seleccion = v),
              ),
            ),
          ),
          api,
        ),
      );
      await tester.pumpAndSettle();

      // Sin estado elegido no hay selector de municipio: pedirlo "de todo el país" daría una
      // lista ambigua (los nombres se repiten entre entidades).
      expect(find.byKey(const Key('geo-filter-estado')), findsOneWidget);
      expect(find.byKey(const Key('geo-filter-municipio')), findsNothing);

      await tester.tap(find.byKey(const Key('geo-filter-estado')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zacatecas').last);
      await tester.pumpAndSettle();

      expect(seleccion.cveEnt, '32');
      expect(find.byKey(const Key('geo-filter-municipio')), findsOneWidget);
      expect(
        peticiones.any((u) =>
            u.path.endsWith('/geo/municipios') &&
            u.queryParameters['cve_ent'] == '32'),
        isTrue,
        reason: 'el catálogo de municipios se pide acotado al estado elegido',
      );
    });

    testWidgets('cambiar de estado limpia el municipio', (tester) async {
      final mock = MockClient((req) async {
        if (req.url.path.endsWith('/geo/estados')) {
          return http.Response(_estadosJson(), 200);
        }
        if (req.url.path.endsWith('/geo/municipios')) {
          return http.Response(
            _municipiosJson(req.url.queryParameters['cve_ent'] ?? '01'),
            200,
          );
        }
        return http.Response('[]', 200);
      });
      final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

      GeoSeleccion seleccion = const GeoSeleccion();
      await tester.pumpWidget(
        envolver(
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: GeoFilter(
                value: seleccion,
                onChanged: (v) => setState(() => seleccion = v),
              ),
            ),
          ),
          api,
        ),
      );
      await tester.pumpAndSettle();

      // Aguascalientes → Jesús María
      await tester.tap(find.byKey(const Key('geo-filter-estado')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aguascalientes').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('geo-filter-municipio')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jesús María').last);
      await tester.pumpAndSettle();
      expect(seleccion.cveMun, '005');

      // Cambiar a Zacatecas debe soltar el municipio: conservar "005" filtraría por una clave
      // que no existe en el estado nuevo y la tabla saldría vacía sin explicación.
      await tester.tap(find.byKey(const Key('geo-filter-estado')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zacatecas').last);
      await tester.pumpAndSettle();
      expect(seleccion.cveEnt, '32');
      expect(seleccion.cveMun, isNull);
    });

    testWidgets('si el catálogo falla, el filtro se apaga sin romper la pantalla',
        (tester) async {
      final mock = MockClient((req) async => http.Response('boom', 500));
      final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

      await tester.pumpWidget(
        envolver(
          Scaffold(
            body: GeoFilter(
              value: const GeoSeleccion(),
              onChanged: (_) {},
            ),
          ),
          api,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('no disponible'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AC20 — el filtro viaja en la query', () {
    test('las 4 rutas de analítica reciben cve_ent y cve_mun', () async {
      final urls = <Uri>[];
      final mock = MockClient((req) async {
        urls.add(req.url);
        if (req.url.path.endsWith('.csv')) return http.Response('a,b\n', 200);
        // `observations` devuelve lista; `summary`, objeto.
        final esLista = req.url.path.endsWith('/observations');
        return http.Response(esLista ? '[]' : '{"total":0}', 200);
      });
      final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

      await api.analyticsSummary(cveEnt: '32', cveMun: '019');
      await api.analyticsObservations(cveEnt: '32', cveMun: '019');
      await api.analyticsCsvBytes(cveEnt: '32', cveMun: '019');
      await api.participationCsvBytes(cveEnt: '32', cveMun: '019');

      expect(urls, hasLength(4));
      for (final u in urls) {
        expect(u.queryParameters['cve_ent'], '32', reason: '$u');
        expect(u.queryParameters['cve_mun'], '019', reason: '$u');
      }
    });

    test('publicGrid ya no manda limit (el backend agrega en SQL)', () async {
      Uri? url;
      final mock = MockClient((req) async {
        url = req.url;
        return http.Response('[]', 200);
      });
      final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);
      await api.publicGrid();
      expect(url!.queryParameters.containsKey('limit'), isFalse);
    });
  });

  group('AC22 — el mapa encuadra sobre los datos', () {
    test('sin puntos no hay encuadre (se usa el centro de respaldo)', () {
      expect(encuadreDe(const <LatLng>[]), isNull);
    });

    test('el encuadre contiene todos los puntos, incluido el de otro estado', () {
      final bounds = encuadreDe(const [
        LatLng(21.8853, -102.2916), // Aguascalientes
        LatLng(21.6452, -102.9731), // Jalpa, Zacatecas
      ])!;
      expect(bounds.contains(const LatLng(21.8853, -102.2916)), isTrue);
      expect(bounds.contains(const LatLng(21.6452, -102.9731)), isTrue);
      // Con el centro fijo anterior, el punto de Zacatecas caía fuera del cuadro inicial.
      expect(bounds.west, lessThan(-102.9731));
      expect(bounds.north, greaterThan(21.8853));
    });

    test('un solo punto produce un encuadre usable, no degenerado', () {
      final bounds = encuadreDe(const [LatLng(21.8853, -102.2916)])!;
      expect(bounds.north - bounds.south, greaterThan(0));
      expect(bounds.east - bounds.west, greaterThan(0));
    });
  });
}
