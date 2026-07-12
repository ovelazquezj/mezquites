import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/home_shell.dart';
import 'package:mezquite_web_admin/src/screens/review_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// PNG transparente de 1x1 (bytes válidos) para el visor de imagen de revisión.
final List<int> _kPng1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

/// ApiClient mock que cubre las rutas de revisión + dashboards vacíos.
ApiClient _api() {
  final mock = MockClient((req) async {
    final path = req.url.path;
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
    if (path.endsWith('/review/queue')) {
      return http.Response(
          json.encode([
            {
              'observation_id': 'o1',
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
            }
          ]),
          200,
          headers: {'content-type': 'application/json'});
    }
    // CR-010 #4: imagen de revisión servida como bytes (PNG 1x1) con el header
    // Authorization. Image.network ignora headers en web, por eso se descarga.
    if (path.endsWith('/image')) {
      return http.Response.bytes(_kPng1x1, 200,
          headers: {'content-type': 'image/png'});
    }
    if (path.contains('/review/observations/')) {
      return http.Response(
          json.encode({
            'observation_id': 'o1',
            'handle': 'obs-A',
            'captured_at': '2026-06-15T12:00:00Z',
            'estado_revision': 'aceptada',
            'nivel_g4': 'leve',
            'flag_cuscuta': false,
            'flag_danio': false,
            'tamanio': 'mediano',
            'contexto': 'campo_abierto',
            'estado': 'Ags',
            'municipio': 'Centro',
            'historial': []
          }),
          200,
          headers: {'content-type': 'application/json'});
    }
    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

Widget _shellAs(String role) {
  final api = _api();
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

Widget _detailAs(String role) {
  final api = _api();
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      sessionProvider.overrideWith((ref) {
        final c = SessionController(api);
        c.loginWithToken(fakeJwt(handle: 'obs-$role', role: role));
        return c;
      }),
    ],
    child: const MaterialApp(
        home: Scaffold(body: ReviewDetailDialog(observationId: 'o1'))),
  );
}

void main() {
  setUp(() {
    // No-op: cada test fija el tamaño de vista.
  });

  testWidgets('evaluador ve Revisión y Monitor; NO ve módulos de admin',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_shellAs('evaluador'));
    await tester.pump();

    expect(find.text(Copy.navReview), findsWidgets);
    expect(find.text(Copy.navMonitor), findsOneWidget);
    // Sin módulos de administración del consorcio.
    expect(find.text(Copy.navInstitutions), findsNothing);
    expect(find.text(Copy.navAllies), findsNothing);
    expect(find.text(Copy.navSnapshots), findsNothing);
    // La ubicación exacta es pública: el evaluador también ve el panel (CR-025).
    expect(find.text(Copy.navRestricted), findsWidgets);
  });

  testWidgets('analista ve Monitor pero NO la pestaña de Revisión (solo lectura)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_shellAs('analista'));
    await tester.pump();

    expect(find.text(Copy.navMonitor), findsWidgets);
    // analista no emite veredicto → no se le ofrece la pestaña de Revisión.
    expect(find.text(Copy.navReview), findsNothing);
  });

  testWidgets('admin_consorcio NO ve Revisión ni Monitor', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_shellAs('admin_consorcio'));
    await tester.pump();

    expect(find.text(Copy.navReview), findsNothing);
    expect(find.text(Copy.navMonitor), findsNothing);
    expect(find.text(Copy.navInstitutions), findsOneWidget);
  });

  testWidgets('detalle: evaluador ve los 3 botones de veredicto (CR-010 #4)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_detailAs('evaluador'));
    await tester.pump();
    await tester.pump();

    // Confirmar / Retirar + el nuevo "Volver a aceptada".
    expect(find.byKey(const Key('review-confirm')), findsOneWidget);
    expect(find.byKey(const Key('review-reject')), findsOneWidget);
    expect(find.byKey(const Key('review-reopen')), findsOneWidget);
    expect(find.text(Copy.reviewReopen), findsOneWidget);
  });

  testWidgets(
      'detalle: el visor descarga los bytes y pinta Image.memory (CR-010 #4)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_detailAs('evaluador'));
    // Resuelve el detalle y luego la descarga de bytes de la imagen.
    await tester.pumpAndSettle();

    final imgFinder = find.byKey(const Key('review-image'));
    expect(imgFinder, findsOneWidget);
    // Es Image.memory (no Image.network): los headers de auth sí viajan en web.
    final img = tester.widget<Image>(imgFinder);
    expect(img.image, isA<MemoryImage>());
    // No cayó al estado de error.
    expect(find.byKey(const Key('review-image-error')), findsNothing);
  });

  testWidgets('detalle: analista NO ve botones de veredicto (solo lectura)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_detailAs('analista'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('review-confirm')), findsNothing);
    expect(find.byKey(const Key('review-reject')), findsNothing);
    // Pero sí ve la nota de ubicación protegida / historial.
    expect(find.text(Copy.reviewHistoryTitle), findsOneWidget);
  });
}
