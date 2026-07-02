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
  testWidgets('admin_consorcio SÍ ve la pestaña con ubicación exacta (CR-023)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_shellAsAdmin());
    await tester.pump();
    expect(find.text(Copy.navRestricted), findsWidgets,
        reason: 'CR-023: los roles administrativos ven ubicación exacta');
    // Sí ve los módulos admin en el NavigationRail.
    expect(find.text(Copy.navInstitutions), findsOneWidget);
    expect(find.text(Copy.navAllies), findsOneWidget);
    expect(find.text(Copy.navIndicators), findsOneWidget);
    expect(find.text(Copy.navSnapshots), findsOneWidget);
    // El panel público aparece como etiqueta del nav y como título de la
    // pantalla seleccionada por defecto → al menos uno.
    expect(find.text(Copy.navPublic), findsWidgets);
  });

  testWidgets('evaluador NO ve la pestaña con ubicación exacta (gate #5)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final api = _emptyApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sessionProvider.overrideWith((ref) {
          final c = SessionController(api);
          c.loginWithToken(fakeJwt(handle: 'obs-EV', role: 'evaluador'));
          return c;
        }),
      ],
      child: const MaterialApp(home: HomeShell()),
    ));
    await tester.pump();
    expect(find.text(Copy.navRestricted), findsNothing,
        reason: 'gate #5: el evaluador no ve coords exactas');
  });
}
