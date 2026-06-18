import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/home_shell.dart';
import 'package:mezquite_web_admin/src/screens/institutions_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// CR-011 #5a: el `administrador` (no solo `admin_consorcio`) ve y usa la consola
/// (Instituciones/Aliados/…) y puede **aprobar** una institución solicitada.
void main() {
  void big(WidgetTester t) {
    t.view.physicalSize = const Size(1500, 1200);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
  }

  ApiClient api(List<String> approved, {String status = 'solicitada'}) {
    final mock = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('/admin/institutions/i1/approve') && req.method == 'POST') {
        approved.add('i1');
        return http.Response(
            json.encode({'id': 'i1', 'name': 'Prepa X', 'estado': 'Aguascalientes', 'status': 'aprobada'}),
            200,
            headers: {'content-type': 'application/json'});
      }
      if (p.endsWith('/admin/institutions') && req.method == 'GET') {
        return http.Response(
            json.encode([
              {'id': 'i1', 'name': 'Prepa X', 'estado': 'Aguascalientes', 'status': status}
            ]),
            200,
            headers: {'content-type': 'application/json'});
      }
      if (p.endsWith('/public/indicators')) {
        return http.Response(
            json.encode({
              'snapshot_quarter': 'Q2-2026', 'caveat': 'c',
              'social': {}, 'educativo': {}, 'ecologico': {}, 'organizacional': {}
            }),
            200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('[]', 200, headers: {'content-type': 'application/json'});
    });
    return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
  }

  Widget shellAs(String role, ApiClient c) => ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(c),
          sessionProvider.overrideWith((ref) {
            final s = SessionController(c);
            s.loginWithToken(fakeJwt(handle: 'obs-$role', role: role));
            return s;
          }),
        ],
        child: const MaterialApp(home: HomeShell()),
      );

  Widget institutionsAs(String role, ApiClient c) => ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(c),
          sessionProvider.overrideWith((ref) {
            final s = SessionController(c);
            s.loginWithToken(fakeJwt(handle: 'obs-$role', role: role));
            return s;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: InstitutionsScreen())),
      );

  testWidgets('administrador ve la consola (Instituciones/Aliados)', (tester) async {
    big(tester);
    await tester.pumpWidget(shellAs('administrador', api([])));
    await tester.pump();
    expect(find.text(Copy.navInstitutions), findsWidgets);
    expect(find.text(Copy.navAllies), findsWidgets);
  });

  testWidgets('aprobar una solicitada llama a POST /approve', (tester) async {
    big(tester);
    final approved = <String>[];
    await tester.pumpWidget(institutionsAs('administrador', api(approved)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-approve-i1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('institution-approve-i1')));
    await tester.pumpAndSettle();
    expect(approved, contains('i1'));
  });
}
