import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/home_shell.dart';
import 'package:mezquite_web_admin/src/screens/problem_reports_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

const _sampleReport = {
  'id': 'p1',
  'created_at': '2026-06-28T14:30:00Z',
  'account_id': 'a1',
  'handle': 'obs-juan',
  'user_agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/120',
  'platform': 'web-android',
  'app_version': 'beta-2606',
  'context': 'captura',
  'message': 'La cámara no abre al tomar la foto.',
  'error_detail': 'TypeError: null is not an object (camera.start)',
  'status': 'nuevo',
};

/// MockClient para la API que registra peticiones y responde a las rutas de
/// reportes (y a /public/indicators para que el shell monte).
ApiClient _api(RequestRecorder rec, {List<Map<String, dynamic>>? reports}) {
  final mock = MockClient((req) async {
    rec.requests.add(req);
    final path = req.url.path;
    if (path.endsWith('/admin/problem-reports/p1/status')) {
      final body = json.decode(req.body) as Map<String, dynamic>;
      final updated = Map<String, dynamic>.from(_sampleReport)
        ..['status'] = body['status'];
      return http.Response(json.encode(updated), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/admin/problem-reports')) {
      return http.Response(json.encode(reports ?? [_sampleReport]), 200,
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

Map<String, dynamic> _jsonBody(http.BaseRequest req) =>
    json.decode((req as http.Request).body) as Map<String, dynamic>;

Widget _shellAs(String role, ApiClient api) => ProviderScope(
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

Widget _screen(ApiClient api) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: Scaffold(body: ProblemReportsScreen())),
    );

void main() {
  void big(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  group('Contrato REST — reportes de problemas (CR-019)', () {
    test('listProblemReports hace GET /admin/problem-reports y parsea', () async {
      final rec = RequestRecorder();
      final api = _api(rec);
      final rows = await api.listProblemReports();
      final req = rec.requests.single;
      expect(req.method, 'GET');
      expect(req.url.path, '/api/v1/admin/problem-reports');
      expect(rows, hasLength(1));
      expect(rows.single.id, 'p1');
      expect(rows.single.context, 'captura');
      expect(rows.single.errorDetail,
          'TypeError: null is not an object (camera.start)');
      expect(rows.single.isNuevo, isTrue);
    });

    test('setProblemReportStatus hace POST .../{id}/status con body', () async {
      final rec = RequestRecorder();
      final api = _api(rec);
      api.setToken('t');
      final updated =
          await api.setProblemReportStatus(id: 'p1', status: 'resuelto');
      final req = rec.requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/admin/problem-reports/p1/status');
      expect(_jsonBody(req)['status'], 'resuelto');
      expect(req.headers['Authorization'], 'Bearer t');
      expect(updated.status, 'resuelto');
    });
  });

  group('Gateo de rol en el NavigationRail (CR-019)', () {
    for (final role in ['administrador', 'admin_consorcio']) {
      testWidgets('$role SÍ ve "Reportes"', (tester) async {
        big(tester);
        await tester.pumpWidget(_shellAs(role, _api(RequestRecorder())));
        await tester.pump();
        expect(find.text(Copy.navProblems), findsWidgets);
      });
    }

    for (final role in ['evaluador', 'analista']) {
      testWidgets('$role NO ve "Reportes"', (tester) async {
        big(tester);
        await tester.pumpWidget(_shellAs(role, _api(RequestRecorder())));
        await tester.pump();
        expect(find.text(Copy.navProblems), findsNothing);
      });
    }
  });

  group('Pantalla de reportes (CR-019)', () {
    testWidgets('muestra la tabla con los datos del reporte', (tester) async {
      big(tester);
      await tester.pumpWidget(_screen(_api(RequestRecorder())));
      await tester.pumpAndSettle();

      expect(find.text('captura'), findsOneWidget);
      expect(find.text('La cámara no abre al tomar la foto.'), findsOneWidget);
      expect(find.text('obs-juan'), findsOneWidget);
      expect(find.byKey(const Key('problems-refresh')), findsOneWidget);
    });

    testWidgets('estado vacío con texto humanizado', (tester) async {
      big(tester);
      await tester
          .pumpWidget(_screen(_api(RequestRecorder(), reports: const [])));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('problems-empty')), findsOneWidget);
      expect(find.text(Copy.problemsEmpty), findsOneWidget);
    });

    testWidgets('"Visto" hace el POST de estado y avisa', (tester) async {
      big(tester);
      final rec = RequestRecorder();
      await tester.pumpWidget(_screen(_api(rec)));
      await tester.pumpAndSettle();

      final seen = find.byKey(const Key('problem-seen-p1'));
      await tester.ensureVisible(seen);
      await tester.pumpAndSettle();
      await tester.tap(seen);
      await tester.pumpAndSettle();

      expect(rec.hitPathContaining('/admin/problem-reports/p1/status'), isTrue);
      expect(find.text(Copy.problemsMarkedSeen), findsOneWidget);
    });

    testWidgets('el detalle muestra el error técnico completo', (tester) async {
      big(tester);
      await tester.pumpWidget(_screen(_api(RequestRecorder())));
      await tester.pumpAndSettle();

      final detailBtn = find.byKey(const Key('problem-detail-p1'));
      await tester.ensureVisible(detailBtn);
      await tester.pumpAndSettle();
      await tester.tap(detailBtn);
      await tester.pumpAndSettle();

      expect(find.text(Copy.problemsDetailTitle), findsOneWidget);
      expect(find.byKey(const Key('problem-detail-text')), findsOneWidget);
      expect(find.textContaining('TypeError'), findsOneWidget);
    });
  });
}
