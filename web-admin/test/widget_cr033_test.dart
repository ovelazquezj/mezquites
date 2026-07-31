import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/review_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';

import 'helpers.dart';

/// CR-033 — dos bugs de la cola de Revisión reportados por el usuario:
/// 1. La pantalla pedía una sola página de 200 al backend, así que con más
///    registros en la base el resto era invisible.
/// 2. Volver del detalle a la lista recargaba la cola y el PagedTable renacía
///    en la página 1 con 10 filas, perdiendo dónde estaba el revisor.

/// PNG transparente de 1x1 (bytes válidos) para el visor de imagen de revisión.
final List<int> _kPng1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

Map<String, dynamic> _fila(int i) => {
      'observation_id': 'o$i',
      'handle': 'obs-A',
      'captured_at': '2026-06-15T12:00:00Z',
      'estado_revision': 'aceptada',
      'nivel_g4': 'leve',
      'flag_cuscuta': false,
      'flag_danio': false,
      'tamanio': 'mediano',
      'contexto': 'campo_abierto',
      'estado': 'Ags',
      'municipio': 'Centro'
    };

/// Mock con [total] filas en la cola, respetando `limit`/`offset` como el
/// backend real (así se prueba que la pantalla SÍ recorre toda la cola).
ApiClient _api(int total) {
  final mock = MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/review/queue')) {
      final limit = int.parse(req.url.queryParameters['limit'] ?? '100');
      final offset = int.parse(req.url.queryParameters['offset'] ?? '0');
      final fin = (offset + limit) > total ? total : (offset + limit);
      return http.Response(
          json.encode([for (var i = offset; i < fin; i++) _fila(i)]), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/image')) {
      return http.Response.bytes(_kPng1x1, 200,
          headers: {'content-type': 'image/png'});
    }
    if (path.contains('/review/observations/')) {
      return http.Response(
          json.encode({..._fila(0), 'historial': <Object>[]}), 200,
          headers: {'content-type': 'application/json'});
    }
    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

Widget _screen(ApiClient api) => ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sessionProvider.overrideWith((ref) {
          final c = SessionController(api);
          c.loginWithToken(fakeJwt(handle: 'obs-ev', role: 'evaluador'));
          return c;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: ReviewScreen())),
    );

void main() {
  testWidgets('la cola muestra MÁS de 200 registros (el tope era del cliente)',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_screen(_api(331)));
    await tester.pumpAndSettle();

    // El total real de la base, no un tope arbitrario.
    expect(find.text('1–10 de 331'), findsOneWidget);
  });

  testWidgets(
      'volver del detalle conserva la página y las filas por página (CR-033)',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_screen(_api(30)));
    await tester.pumpAndSettle();
    expect(find.text('1–10 de 30'), findsOneWidget);

    // 25 filas por página…
    await tester.tap(find.byKey(const Key('paged-per-page')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25').last);
    await tester.pumpAndSettle();
    expect(find.text('1–25 de 30'), findsOneWidget);

    // …y a la página 2.
    await tester.tap(find.byKey(const Key('paged-next')));
    await tester.pumpAndSettle();
    expect(find.text('26–30 de 30'), findsOneWidget);

    // Entrar al detalle de una observación de ESTA página y regresar.
    await tester.tap(find.byKey(const Key('review-open-o25')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review-detail-close')));
    await tester.pumpAndSettle();

    // La lista sigue donde estaba: página 2 y 25 filas por página.
    expect(find.text('26–30 de 30'), findsOneWidget);
    final dropdown =
        tester.widget<DropdownButton<int>>(find.byKey(const Key('paged-per-page')));
    expect(dropdown.value, 25);
  });

  testWidgets('cambiar el filtro SÍ regresa a la página 1 (intencional)',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_screen(_api(30)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paged-next')));
    await tester.pumpAndSettle();
    expect(find.text('11–20 de 30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('review-filter-aceptada')));
    await tester.pumpAndSettle();
    expect(find.text('1–10 de 30'), findsOneWidget);
  });
}
