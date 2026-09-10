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
/// CR-040: desde esa misma pantalla cambia el rol y elimina cuentas del equipo,
/// salvo la propia y la cuenta principal.

ApiClient _api({List<Map<String, dynamic>>? users, RequestRecorder? rec}) {
  final mock = MockClient((req) async {
    rec?.requests.add(req);
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
    // CR-040: cambio de rol.
    if (path.contains('/admin/users/') && req.method == 'PATCH') {
      final body = json.decode(req.body) as Map<String, dynamic>;
      return http.Response(
          json.encode({
            'id': path.split('/').last,
            'handle': 'obs-eva',
            'username': 'eva',
            'role': body['role'],
            'has_email': false,
            'must_change_password': false,
            'protected': false,
          }),
          200,
          headers: {'content-type': 'application/json'});
    }
    // CR-040: eliminar (mismo endpoint que la cancelación ARCO).
    if (path.contains('/admin/accounts/') && req.method == 'DELETE') {
      return http.Response(
          json.encode({
            'deleted_account_id': path.split('/').last,
            'observations_anonymized': 0,
            'message': 'Cuenta eliminada.',
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

/// Una evaluadora cualquiera. **Sin `protected`** a propósito: comprueba que la
/// consola tolera el JSON anterior a CR-040 (el campo se asume falso).
const _unaEvaluadora = [
  {
    'id': 'u-eva',
    'handle': 'obs-eva',
    'username': 'eva',
    'role': 'evaluador',
    'has_email': false,
    'must_change_password': false,
  },
];

/// La propia cuenta de quien mira (handle == el del token) y la cuenta principal.
const _cuentasIntocables = [
  {
    'id': 'u-yo',
    'handle': 'obs-administrador',
    'username': 'jefa',
    'role': 'administrador',
    'has_email': true,
    'must_change_password': false,
    'protected': false,
  },
  {
    'id': 'u-root',
    'handle': 'obs-root',
    'username': 'root',
    'role': 'administrador',
    'has_email': true,
    'must_change_password': false,
    'protected': true,
  },
];

void _pantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
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
    await tester.tap(find.text('Administrador general').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-email')), findsOneWidget);
  });

  // --- CR-040 ---

  testWidgets('CR-040: cambiar el rol envía el PATCH tras confirmar',
      (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(
        _usersScreen(_api(users: _unaEvaluadora, rec: rec), 'administrador'));
    await tester.pumpAndSettle();

    // Elegir "Analista" en el menú del renglón.
    await tester.tap(find.byKey(const Key('user-role-eva')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analista').last);
    await tester.pumpAndSettle();

    // Pide confirmación ANTES de tocar nada.
    expect(find.byKey(const Key('user-role-confirm-dialog')), findsOneWidget);
    expect(rec.requests.any((r) => r.method == 'PATCH'), isFalse);

    await tester.tap(find.byKey(const Key('user-role-confirm-ok')));
    await tester.pumpAndSettle();

    final patch = rec.requests.firstWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, '/api/v1/admin/users/u-eva');
    final body = json.decode((patch as http.Request).body) as Map<String, dynamic>;
    expect(body['role'], 'analista');

    // Deja el SnackBar sin temporizadores pendientes.
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('CR-040: cancelar el cambio de rol NO envía nada', (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(
        _usersScreen(_api(users: _unaEvaluadora, rec: rec), 'administrador'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('user-role-eva')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analista').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-role-confirm-cancel')));
    await tester.pumpAndSettle();

    expect(rec.requests.any((r) => r.method == 'PATCH'), isFalse);
  });

  testWidgets('CR-040: eliminar envía el DELETE con el motivo tras confirmar',
      (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(
        _usersScreen(_api(users: _unaEvaluadora, rec: rec), 'administrador'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('user-delete-eva')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-delete-confirm-dialog')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('user-delete-reason')), 'dejó el proyecto');
    await tester.tap(find.byKey(const Key('user-delete-confirm-ok')));
    await tester.pumpAndSettle();

    final del = rec.requests.firstWhere((r) => r.method == 'DELETE');
    expect(del.url.path, '/api/v1/admin/accounts/u-eva');
    final body = json.decode((del as http.Request).body) as Map<String, dynamic>;
    expect(body['reason'], 'dejó el proyecto');

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('CR-040: cancelar el diálogo de borrado NO elimina', (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(
        _usersScreen(_api(users: _unaEvaluadora, rec: rec), 'administrador'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('user-delete-eva')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-delete-confirm-cancel')));
    await tester.pumpAndSettle();

    expect(rec.requests.any((r) => r.method == 'DELETE'), isFalse);
  });

  testWidgets(
      'CR-040: la propia cuenta y la principal no se cambian ni se eliminan',
      (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(
        _usersScreen(_api(users: _cuentasIntocables), 'administrador'));
    await tester.pumpAndSettle();

    // Propia cuenta (handle == el del token).
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const Key('user-role-jefa')))
            .onChanged,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('user-delete-jefa')))
            .onPressed,
        isNull);
    expect(find.textContaining(Copy.userTagSelf), findsWidgets);

    // Cuenta principal (protected).
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const Key('user-role-root')))
            .onChanged,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('user-delete-root')))
            .onPressed,
        isNull);
    expect(find.textContaining(Copy.userTagProtected), findsWidgets);
  });

  testWidgets(
      'CR-040: un JSON sin "protected" deja las acciones habilitadas (tolerancia)',
      (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(
        _usersScreen(_api(users: _unaEvaluadora), 'administrador'));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const Key('user-role-eva')))
            .onChanged,
        isNotNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('user-delete-eva')))
            .onPressed,
        isNotNull);
  });
}
