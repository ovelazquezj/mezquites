import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/accounts_screen.dart';
import 'package:mezquite_web_admin/src/screens/home_shell.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// CR-006 — ARCO Cancelación de cuenta (web-admin).
/// AC: solo `administrador` ve y usa la pantalla; buscar → eliminar con
/// confirmación + motivo → muestra el resultado (nº observaciones anonimizadas).

ApiClient _api({List<Map<String, dynamic>>? accounts, RequestRecorder? rec}) {
  final mock = MockClient((req) async {
    rec?.requests.add(req);
    final path = req.url.path;
    if (path.endsWith('/admin/accounts') && req.method == 'GET') {
      return http.Response(json.encode(accounts ?? []), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/admin/accounts/') && req.method == 'DELETE') {
      final id = path.split('/').last;
      return http.Response(
          json.encode({
            'deleted_account_id': id,
            'observations_anonymized': 3,
            'message':
                'Cuenta eliminada y observaciones anonimizadas. El dato ecológico se conserva.',
          }),
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
    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

Widget _shellAs(String role, ApiClient api) {
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

Widget _accountsScreen(ApiClient api, String role) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      sessionProvider.overrideWith((ref) {
        final c = SessionController(api);
        c.loginWithToken(fakeJwt(handle: 'obs-$role', role: role));
        return c;
      }),
    ],
    child: const MaterialApp(home: Scaffold(body: AccountsScreen())),
  );
}

const _accounts = [
  {
    'id': 'a1',
    'handle': 'obs-juan',
    'role': 'voluntario',
    'auth_provider': 'social_google',
    'has_email': false,
    'observations': 3,
  },
];

void main() {
  testWidgets('administrador ve la pestaña "Eliminar cuenta"', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_shellAs('administrador', _api()));
    await tester.pump();
    expect(find.text(Copy.navAccounts), findsOneWidget);
  });

  testWidgets('evaluador NO ve la pestaña "Eliminar cuenta" (solo administrador)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_shellAs('evaluador', _api()));
    await tester.pump();
    expect(find.text(Copy.navAccounts), findsNothing);
  });

  testWidgets('admin_consorcio NO ve la pestaña "Eliminar cuenta"',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_shellAs('admin_consorcio', _api()));
    await tester.pump();
    expect(find.text(Copy.navAccounts), findsNothing);
  });

  testWidgets('buscar muestra la cuenta y el conteo de observaciones',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
        _accountsScreen(_api(accounts: _accounts), 'administrador'));
    await tester.pump();

    await tester.enterText(
        find.byKey(const Key('accounts-search-field')), 'juan');
    await tester.tap(find.byKey(const Key('accounts-search')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-row-obs-juan')), findsOneWidget);
    expect(find.byKey(const Key('account-delete-obs-juan')), findsOneWidget);
  });

  testWidgets(
      'eliminar con confirmación + motivo llama al DELETE y muestra el resultado',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final rec = RequestRecorder();
    await tester.pumpWidget(
        _accountsScreen(_api(accounts: _accounts, rec: rec), 'administrador'));
    await tester.pump();

    // Buscar.
    await tester.enterText(
        find.byKey(const Key('accounts-search-field')), 'juan');
    await tester.tap(find.byKey(const Key('accounts-search')));
    await tester.pumpAndSettle();

    // Abrir el diálogo de confirmación.
    await tester.tap(find.byKey(const Key('account-delete-obs-juan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accounts-confirm-dialog')), findsOneWidget);

    // Escribir motivo y confirmar.
    await tester.enterText(
        find.byKey(const Key('accounts-reason')), 'solicitud del titular');
    await tester.tap(find.byKey(const Key('accounts-confirm-ok')));
    await tester.pumpAndSettle();

    // Se llamó al DELETE con el motivo.
    expect(rec.requests.any((r) => r.method == 'DELETE'), isTrue);
    final del = rec.requests.firstWhere((r) => r.method == 'DELETE');
    expect(del.url.path, '/api/v1/admin/accounts/a1');
    final body = json.decode((del as http.Request).body) as Map<String, dynamic>;
    expect(body['reason'], 'solicitud del titular');

    // Se muestra el resultado con el nº de observaciones anonimizadas (3).
    expect(find.byKey(const Key('accounts-result')), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('cancelar el diálogo NO elimina', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final rec = RequestRecorder();
    await tester.pumpWidget(
        _accountsScreen(_api(accounts: _accounts, rec: rec), 'administrador'));
    await tester.pump();

    await tester.enterText(
        find.byKey(const Key('accounts-search-field')), 'juan');
    await tester.tap(find.byKey(const Key('accounts-search')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-delete-obs-juan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accounts-confirm-cancel')));
    await tester.pumpAndSettle();

    expect(rec.requests.any((r) => r.method == 'DELETE'), isFalse);
    expect(find.byKey(const Key('accounts-result')), findsNothing);
  });
}
