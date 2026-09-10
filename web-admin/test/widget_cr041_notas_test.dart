import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/home_shell.dart';
import 'package:mezquite_web_admin/src/screens/review_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// CR-041 — notas escritas sobre una observación.
///
/// Dos cosas que el analista no podía hacer y ahora sí: **abrir** el detalle (el menú
/// Revisión se gateaba por `canEmitVerdict`, no por `canReview`) y **anotar** sin emitir
/// un veredicto. Lo que NO cambia: sigue sin botones de veredicto, y escribir una nota
/// no toca `estado_revision` (gate #9; eso lo prueba el backend).
final List<int> _kPng1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

/// Detalle de `o1` con las notas indicadas. `notas: null` simula un backend ANTERIOR a
/// CR-041, que no manda el campo (la consola se despliega después del backend, pero un
/// bundle en caché puede hablar con cualquiera de los dos).
Map<String, dynamic> _detalle({List<Map<String, dynamic>>? notas}) => {
      'observation_id': 'o1',
      'handle': 'obs-A',
      'captured_at': '2026-06-15T12:00:00Z',
      'estado_revision': 'aceptada',
      'nivel_g4': 'leve',
      'flag_cuscuta': false,
      'flag_danio': false,
      'tamanio': 'mediano',
      'contexto': 'campo_abierto',
      'estado': 'Aguascalientes',
      'municipio': 'Jesús María',
      'historial': const [],
      if (notas != null) 'notas': notas,
    };

ApiClient _api({
  List<Map<String, dynamic>>? notas = const [],
  List<http.Request>? posts,
  int postStatus = 201,
}) {
  final mock = MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/notas') && req.method == 'POST') {
      posts?.add(req);
      if (postStatus != 201) {
        return http.Response(json.encode({'detail': 'no'}), postStatus,
            headers: {'content-type': 'application/json'});
      }
      final texto =
          (json.decode(req.body) as Map<String, dynamic>)['texto'] as String;
      return http.Response(
          json.encode({
            'id': 'n-nueva',
            'texto': texto,
            'autor_handle': 'obs-analista',
            'created_at': '2026-09-10T10:00:00Z',
          }),
          201,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/image')) {
      return http.Response.bytes(_kPng1x1, 200,
          headers: {'content-type': 'image/png'});
    }
    if (path.contains('/review/observations/')) {
      return http.Response(json.encode(_detalle(notas: notas)), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/public/indicators')) {
      return http.Response(
          json.encode({
            'snapshot_quarter': 'Q3-2026',
            'caveat': 'caveat',
            'social': {},
            'educativo': {},
            'ecologico': {},
            'organizacional': {},
          }),
          200,
          headers: {'content-type': 'application/json'});
    }
    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

Widget _wrapAs(Widget child, ApiClient api, String role) => ProviderScope(
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

void main() {
  void big(WidgetTester t) {
    t.view.physicalSize = const Size(1400, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
  }

  bool habilitado(WidgetTester t, String key) =>
      (t.widget(find.byKey(Key(key))) as dynamic).onPressed != null;

  Future<void> abrirDetalle(WidgetTester tester, ApiClient api, String role) async {
    big(tester);
    await tester.pumpWidget(
        _wrapAs(const ReviewDetailDialog(observationId: 'o1'), api, role));
    await tester.pumpAndSettle();
  }

  // --- AC1: el menú Revisión se gatea por `canReview` ---

  group('CR-041 AC1 — el analista entra a Revisión', () {
    for (final role in ['analista', 'evaluador', 'administrador']) {
      testWidgets('$role ve "Revisión" en el menú', (tester) async {
        big(tester);
        await tester.pumpWidget(_wrapAs(const HomeShell(), _api(), role));
        await tester.pump();
        expect(find.text(Copy.navReview), findsWidgets,
            reason: '$role tiene canReview, así que debe ver el módulo');
      });
    }

    testWidgets('admin_consorcio (sin revisión) sigue sin verla', (tester) async {
      big(tester);
      await tester.pumpWidget(_wrapAs(const HomeShell(), _api(), 'admin_consorcio'));
      await tester.pump();
      expect(find.text(Copy.navReview), findsNothing);
    });
  });

  // --- AC2/AC3: abre el detalle, pero sin voto ---

  group('CR-041 AC3 — el analista mira, no vota', () {
    testWidgets('el analista abre el detalle SIN botones de veredicto',
        (tester) async {
      await abrirDetalle(tester, _api(), 'analista');

      // Ve la observación (foto + historial + notas).
      expect(find.byKey(const Key('review-image')), findsOneWidget);
      expect(find.text(Copy.reviewHistoryTitle), findsOneWidget);
      expect(find.byKey(const Key('review-notas-lista')), findsOneWidget);
      // Pero no puede decidir.
      expect(find.byKey(const Key('review-confirm')), findsNothing);
      expect(find.byKey(const Key('review-reject')), findsNothing);
      expect(find.byKey(const Key('review-reopen')), findsNothing);
    });

    testWidgets('el evaluador sí los ve, y conserva su campo de nota del veredicto',
        (tester) async {
      await abrirDetalle(tester, _api(), 'evaluador');

      expect(find.byKey(const Key('review-confirm')), findsOneWidget);
      expect(find.byKey(const Key('review-reject')), findsOneWidget);
      expect(find.byKey(const Key('review-reopen')), findsOneWidget);
      // El campo viejo (viaja con el veredicto) NO se tocó, y el nuevo es otro.
      expect(find.byKey(const Key('review-nota')), findsOneWidget);
      expect(find.byKey(const Key('review-nota-nueva')), findsOneWidget);
    });
  });

  // --- AC8: las notas del backend se pintan con su autor ---

  group('CR-041 AC8 — la lista de notas', () {
    testWidgets('pinta las notas que devuelve el backend, con su autor',
        (tester) async {
      await abrirDetalle(
        tester,
        _api(notas: [
          {
            'id': 'n1',
            'texto': 'El tronco se ve dañado en la base.',
            'autor_handle': 'obs-ANALISTA',
            'created_at': '2026-09-01T08:00:00Z',
          },
          {
            'id': 'n2',
            'texto': 'Coincido, conviene volver a fotografiarlo.',
            'autor_handle': 'obs-EVAL',
            'created_at': '2026-09-02T08:00:00Z',
          },
        ]),
        'analista',
      );

      final lista = find.byKey(const Key('review-notas-lista'));
      expect(
          find.descendant(
              of: lista, matching: find.textContaining('El tronco se ve dañado')),
          findsOneWidget);
      expect(find.descendant(of: lista, matching: find.textContaining('obs-ANALISTA')),
          findsOneWidget);
      expect(find.descendant(of: lista, matching: find.textContaining('obs-EVAL')),
          findsOneWidget);
      // Con notas no se anuncia el vacío.
      expect(find.byKey(const Key('review-notas-vacio')), findsNothing);
    });

    testWidgets('sin notas explica el vacío en texto llano', (tester) async {
      await abrirDetalle(tester, _api(), 'analista');
      expect(find.byKey(const Key('review-notas-vacio')), findsOneWidget);
      expect(find.text(Copy.notesEmpty), findsOneWidget);
    });

    testWidgets('un detalle SIN el campo `notas` no rompe la pantalla',
        (tester) async {
      // Backend anterior a CR-041: la clave ni aparece en el JSON.
      await abrirDetalle(tester, _api(notas: null), 'analista');

      expect(find.text('No se pudo cargar el detalle.'), findsNothing);
      expect(find.byKey(const Key('review-notas-lista')), findsOneWidget);
      expect(find.byKey(const Key('review-notas-vacio')), findsOneWidget);
      expect(find.byKey(const Key('review-nota-nueva')), findsOneWidget);
    });
  });

  // --- AC4: escribir una nota ---

  group('CR-041 AC4 — escribir una nota', () {
    testWidgets('hace POST a /notas con el texto y la nota aparece en la lista',
        (tester) async {
      final posts = <http.Request>[];
      await abrirDetalle(tester, _api(posts: posts), 'analista');

      expect(habilitado(tester, 'review-nota-agregar'), isFalse,
          reason: 'con el campo vacío no hay nada que guardar');

      await tester.enterText(
          find.byKey(const Key('review-nota-nueva')), 'Se ve paxtle en la copa.');
      await tester.pump();
      expect(habilitado(tester, 'review-nota-agregar'), isTrue);

      await tester.ensureVisible(find.byKey(const Key('review-nota-agregar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-nota-agregar')));
      await tester.pumpAndSettle();

      // Fue al endpoint nuevo, con el cuerpo del contrato.
      expect(posts, hasLength(1));
      expect(posts.single.url.path, endsWith('/review/observations/o1/notas'));
      expect(json.decode(posts.single.body),
          {'texto': 'Se ve paxtle en la copa.'});

      // Y quedó a la vista sin cerrar el diálogo.
      expect(
        find.descendant(
            of: find.byKey(const Key('review-notas-lista')),
            matching: find.textContaining('Se ve paxtle en la copa.')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('review-notas-vacio')), findsNothing);
      expect(find.text(Copy.notesAdded), findsOneWidget);
      // El diálogo sigue abierto: anotar no es despedirse de la observación.
      expect(find.byKey(const Key('review-nota-nueva')), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 5)); // timers del SnackBar
    });

    testWidgets('solo espacios NO habilita el botón', (tester) async {
      await abrirDetalle(tester, _api(), 'analista');
      await tester.enterText(find.byKey(const Key('review-nota-nueva')), '    ');
      await tester.pump();
      expect(habilitado(tester, 'review-nota-agregar'), isFalse);
    });

    testWidgets('un 422 se explica en texto llano y no borra lo escrito',
        (tester) async {
      await abrirDetalle(tester, _api(postStatus: 422), 'analista');

      await tester.enterText(
          find.byKey(const Key('review-nota-nueva')), 'x' * 10);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('review-nota-agregar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-nota-agregar')));
      await tester.pumpAndSettle();

      expect(find.text(Copy.notesInvalid), findsOneWidget);
      // Sin códigos internos ni "422" en pantalla.
      expect(find.textContaining('422'), findsNothing);
      expect(habilitado(tester, 'review-nota-agregar'), isTrue,
          reason: 'se puede reintentar tras corregir');

      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  // --- AC13: el aviso de datos personales (gate #2) ---

  testWidgets('CR-041 AC13 — el campo lleva el aviso de no escribir datos personales',
      (tester) async {
    await abrirDetalle(tester, _api(), 'analista');

    expect(find.byKey(const Key('review-notas-aviso')), findsOneWidget);
    expect(find.text(Copy.notesPrivacyWarning), findsOneWidget);
    expect(find.textContaining('datos personales'), findsWidgets);
  });
}
