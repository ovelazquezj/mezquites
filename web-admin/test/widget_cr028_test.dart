import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/institutions_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';

import 'helpers.dart';

/// CR-028: dar de alta desde la consola una institución que ya existe responde 409, y la pantalla
/// lo explica en vez de sugerir un reintento (reintentar daría el mismo 409).
void main() {
  void big(WidgetTester t) {
    t.view.physicalSize = const Size(1500, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
  }

  ApiClient api({required int altaStatus, List<http.Request>? posts}) {
    final mock = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('/admin/institutions') && req.method == 'POST') {
        posts?.add(req);
        if (altaStatus == 409) {
          return http.Response(
              json.encode({
                'detail': 'Ya existe la institución "Prepa X" (ya aprobada). '
                    'Úsala en vez de crear otra.'
              }),
              409,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
            json.encode(
                {'id': 'i2', 'name': 'Prepa Nueva', 'estado': null, 'status': 'aprobada'}),
            201,
            headers: {'content-type': 'application/json'});
      }
      if (p.endsWith('/admin/institutions') && req.method == 'GET') {
        return http.Response(
            json.encode([
              {'id': 'i1', 'name': 'Prepa X', 'estado': 'Aguascalientes', 'status': 'aprobada'}
            ]),
            200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('[]', 200, headers: {'content-type': 'application/json'});
    });
    return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
  }

  Widget institutionsAs(ApiClient c) => ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(c),
          sessionProvider.overrideWith((ref) {
            final s = SessionController(c);
            s.loginWithToken(fakeJwt(handle: 'obs-admin', role: 'administrador'));
            return s;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: InstitutionsScreen())),
      );

  Future<void> agregar(WidgetTester tester, String nombre) async {
    await tester.enterText(find.byKey(const Key('institution-name')), nombre);
    await tester.tap(find.byKey(const Key('institution-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('un nombre duplicado (409) se explica, no se ofrece reintentar',
      (tester) async {
    big(tester);
    await tester.pumpWidget(institutionsAs(api(altaStatus: 409)));
    await tester.pumpAndSettle();

    await agregar(tester, 'prepa x');

    expect(find.textContaining('Ya existe una institución con ese nombre'), findsOneWidget);
    expect(find.textContaining('Inténtalo de nuevo'), findsNothing);
  });

  testWidgets('un alta normal sigue confirmando como antes', (tester) async {
    big(tester);
    final posts = <http.Request>[];
    await tester.pumpWidget(institutionsAs(api(altaStatus: 201, posts: posts)));
    await tester.pumpAndSettle();

    await agregar(tester, 'Prepa Nueva');

    expect(posts, hasLength(1));
    expect(find.textContaining('Institución aprobada y agregada'), findsOneWidget);
  });
}
