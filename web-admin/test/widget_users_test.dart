import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/home_shell.dart';
import 'package:mezquite_web_admin/src/screens/users_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// CR-002 — AC7: el administrador ve la pantalla de gestión de usuarios; otros roles no.

ApiClient _api({List<Map<String, dynamic>>? users}) {
  final mock = MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/admin/users') && req.method == 'GET') {
      return http.Response(json.encode(users ?? []), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/admin/users') && req.method == 'POST') {
      final body = json.decode(req.body) as Map<String, dynamic>;
      return http.Response(
          json.encode({
            'id': 'u1',
            'handle': 'obs-NEW',
            'username': body['username'],
            'role': body['role'],
            'has_email': body.containsKey('email'),
            'must_change_password': true,
            'temp_password': 'Mzq-AAAA-BBBB',
          }),
          201,
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

Widget _usersScreen(ApiClient api, String role) {
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      sessionProvider.overrideWith((ref) {
        final c = SessionController(api);
        c.loginWithToken(fakeJwt(handle: 'obs-$role', role: role));
        return c;
      }),
    ],
    child: const MaterialApp(home: Scaffold(body: UsersScreen())),
  );
}

void main() {
  testWidgets('administrador ve la pestaña "Usuarios del equipo"', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_shellAs('administrador', _api()));
    await tester.pump();
    expect(find.text(Copy.navUsers), findsOneWidget);
  });

  testWidgets('evaluador NO ve la pestaña de usuarios (solo administrador)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_shellAs('evaluador', _api()));
    await tester.pump();
    expect(find.text(Copy.navUsers), findsNothing);
  });

  testWidgets('admin_consorcio NO ve la pestaña de usuarios (es del administrador)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_shellAs('admin_consorcio', _api()));
    await tester.pump();
    expect(find.text(Copy.navUsers), findsNothing);
  });

  testWidgets('crear usuario muestra la contraseña temporal (una vez)',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_usersScreen(_api(), 'administrador'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('user-username')), 'eva');
    await tester.tap(find.byKey(const Key('user-create')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('user-temp-password')), findsOneWidget);
    expect(find.text('Mzq-AAAA-BBBB'), findsOneWidget);
  });

  testWidgets('el campo de correo solo aparece al elegir rol administrador',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_usersScreen(_api(), 'administrador'));
    await tester.pump();

    // Rol por defecto = evaluador → sin campo de correo (gate #2 acotado).
    expect(find.byKey(const Key('user-email')), findsNothing);

    // Cambiar a administrador → aparece el campo de correo.
    await tester.tap(find.byKey(const Key('user-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrador').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-email')), findsOneWidget);
  });
}
