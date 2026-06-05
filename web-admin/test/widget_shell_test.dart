import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/home_shell.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// ApiClient mock que devuelve indicadores vacíos / listas vacías para que las
/// pantallas monten sin red real.
ApiClient _emptyApi() {
  final mock = MockClient((req) async {
    if (req.url.path.endsWith('/public/indicators')) {
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

Widget _shellAsAdmin() {
  final api = _emptyApi();
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      sessionProvider.overrideWith((ref) {
        final c = SessionController(api);
        c.loginWithToken(fakeJwt(handle: 'obs-A', role: 'admin_consorcio'));
        return c;
      }),
    ],
    child: const MaterialApp(home: HomeShell()),
  );
}

void main() {
  testWidgets('admin_consorcio NO ve la pestaña de dashboard restringido',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_shellAsAdmin());
    await tester.pump();
    expect(find.text(Copy.navRestricted), findsNothing,
        reason: 'gate #5: un admin puro no ve coords exactas');
    // Sí ve los módulos admin en el NavigationRail.
    expect(find.text(Copy.navInstitutions), findsOneWidget);
    expect(find.text(Copy.navAllies), findsOneWidget);
    expect(find.text(Copy.navIndicators), findsOneWidget);
    expect(find.text(Copy.navSnapshots), findsOneWidget);
    // El panel público aparece como etiqueta del nav y como título de la
    // pantalla seleccionada por defecto → al menos uno.
    expect(find.text(Copy.navPublic), findsWidgets);
  });
}
