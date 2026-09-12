import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/screens/org_indicators_screen.dart';
import 'package:mezquite_web_admin/src/state/session.dart';
import 'package:mezquite_web_admin/src/ui/copy.dart';

import 'helpers.dart';

/// CR-042 (parte B) — Indicadores organizacionales.
///
/// Dos fallas reportadas por el usuario:
///   1. *"Los indicadores desaparecen"*: la pantalla guardaba una lista local y
///      **nunca leía del servidor**; al cambiar de sección el `State` moría con
///      ella. La regresión que lo cubre es la primera prueba: al abrir, la
///      pantalla PIDE la lista.
///   2. *"Tres casilleros y solo el primero es intuitivo"*: el tercero decía
///      "Estado (opcional)" pero pedía la entidad federativa. Ahora la entidad
///      es una lista obligatoria y "¿Qué pasó?" tiene su propio campo.

const _dosEstados = [
  {'cve_ent': '01', 'estado': 'Aguascalientes'},
  {'cve_ent': '32', 'estado': 'Zacatecas'},
];

/// Tres registros: dos de la misma clave (para comprobar que el total SUMA) y
/// uno de otra.
const _tresRegistros = [
  {
    'id': 'i1',
    'key': 'eventos_w3',
    'value': 3,
    'estado': 'Aguascalientes',
    'descripcion': 'Visita Rotaract Ejecutivo',
    'created_at': '2026-09-01T10:00:00Z',
  },
  {
    'id': 'i2',
    'key': 'eventos_w3',
    'value': 2,
    'estado': 'Zacatecas',
    'descripcion': null,
    'created_at': '2026-09-02T10:00:00Z',
  },
  // Sin la llave `descripcion`: el JSON anterior a CR-042 no la trae y la
  // consola no debe romperse con él.
  {
    'id': 'i3',
    'key': 'menciones_mediaticas',
    'value': 1,
    'estado': 'Otro',
    'created_at': '2026-09-03T10:00:00Z',
  },
];

ApiClient _api({
  List<Map<String, dynamic>>? registros,
  RequestRecorder? rec,
  bool listaFalla = false,
  bool estadosFallan = false,
}) {
  final mock = MockClient((req) async {
    rec?.requests.add(req);
    final path = req.url.path;

    if (path.endsWith('/geo/estados')) {
      if (estadosFallan) return http.Response('boom', 500);
      return http.Response(json.encode(_dosEstados), 200,
          headers: {'content-type': 'application/json'});
    }

    if (path.endsWith('/admin/indicators/organizational')) {
      if (req.method == 'GET') {
        if (listaFalla) return http.Response('boom', 500);
        return http.Response(json.encode(registros ?? []), 200,
            headers: {'content-type': 'application/json'});
      }
      if (req.method == 'POST') {
        final body = json.decode(req.body) as Map<String, dynamic>;
        return http.Response(
            json.encode({
              'id': 'nuevo',
              'key': body['key'],
              'value': body['value'],
              'estado': body['estado'],
              'descripcion': body['descripcion'],
              'created_at': '2026-09-12T12:00:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'});
      }
    }

    if (path.contains('/admin/indicators/organizational/')) {
      if (req.method == 'PATCH') {
        final body = json.decode(req.body) as Map<String, dynamic>;
        return http.Response(
            json.encode({
              'id': path.split('/').last,
              'key': 'eventos_w3',
              'value': body['value'] ?? 3,
              'estado': body['estado'] ?? 'Aguascalientes',
              'descripcion': body['descripcion'],
              'created_at': '2026-09-01T10:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'});
      }
      if (req.method == 'DELETE') return http.Response('', 204);
    }

    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

Widget _pantalla(ApiClient api) => ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sessionProvider.overrideWith((ref) {
          final c = SessionController(api);
          c.loginWithToken(
              fakeJwt(handle: 'obs-admin', role: 'administrador'));
          return c;
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: OrgIndicatorsScreen())),
    );

void _pantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

/// Cuántas veces se pidió la lista al servidor.
int _gets(RequestRecorder rec) => rec.requests
    .where((r) =>
        r.method == 'GET' &&
        r.url.path.endsWith('/admin/indicators/organizational'))
    .length;

/// Elige una entidad en el desplegable del formulario de alta.
Future<void> _elegirEntidad(WidgetTester tester, String nombre) async {
  await tester.tap(find.byKey(const Key('org-entidad')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nombre).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('al abrir, la pantalla PIDE la lista al servidor (regresión)',
      (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_pantalla(_api(rec: rec, registros: _tresRegistros)));
    await tester.pumpAndSettle();

    expect(_gets(rec), 1);
    expect(find.byKey(const Key('org-lista')), findsOneWidget);
    // Los tres registros guardados están en pantalla (ya no "los de esta sesión").
    expect(find.byKey(const Key('org-row-i1')), findsOneWidget);
    expect(find.byKey(const Key('org-row-i2')), findsOneWidget);
    expect(find.byKey(const Key('org-row-i3')), findsOneWidget);
  });

  testWidgets('el total por indicador SUMA los registros de la misma clave',
      (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(_pantalla(_api(registros: _tresRegistros)));
    await tester.pumpAndSettle();

    // 3 + 2 de eventos_w3 = 5; la otra clave va aparte.
    expect(
      tester
          .widget<Text>(find.byKey(const Key('org-total-eventos_w3')))
          .data,
      'Eventos realizados: 5',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('org-total-menciones_mediaticas')))
          .data,
      'Menciones en medios: 1',
    );
  });

  testWidgets('el alta manda key, value, estado y descripcion, y recarga',
      (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_pantalla(_api(rec: rec, registros: _tresRegistros)));
    await tester.pumpAndSettle();
    expect(_gets(rec), 1);

    await tester.enterText(find.byKey(const Key('org-value')), '4');
    await tester.enterText(
        find.byKey(const Key('org-descripcion')), 'Visita Rotaract Ejecutivo');
    await _elegirEntidad(tester, 'Zacatecas');

    await tester.tap(find.byKey(const Key('org-submit')));
    await tester.pumpAndSettle();

    final post = rec.requests.firstWhere((r) => r.method == 'POST');
    expect(post.url.path, '/api/v1/admin/indicators/organizational');
    final body = json.decode((post as http.Request).body) as Map<String, dynamic>;
    expect(body['key'], 'mesas_formales_autoridades'); // el primero del catálogo
    expect(body['value'], 4);
    expect(body['estado'], 'Zacatecas');
    expect(body['descripcion'], 'Visita Rotaract Ejecutivo');

    // Y vuelve a leer del servidor: la lista no se queda en memoria.
    expect(_gets(rec), 2);

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('la ayuda de Cantidad dice qué se cuenta y cambia con el indicador',
      (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(_pantalla(_api(registros: _tresRegistros)));
    await tester.pumpAndSettle();

    String ayuda() => tester
        .widget<TextField>(find.byKey(const Key('org-value')))
        .decoration!
        .helperText!;

    expect(ayuda(), 'Cuántas mesas o reuniones hubo');

    await tester.tap(find.byKey(const Key('org-key')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eventos realizados').last);
    await tester.pumpAndSettle();

    expect(ayuda(), 'Cuántos eventos se realizaron');
  });

  testWidgets('sin entidad elegida, el botón Registrar está deshabilitado',
      (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(_pantalla(_api(registros: _tresRegistros)));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('org-submit')))
            .onPressed,
        isNull);

    await _elegirEntidad(tester, 'Aguascalientes');

    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('org-submit')))
            .onPressed,
        isNotNull);
  });

  testWidgets('la entidad ofrece las del catálogo /geo/estados más "Otro"',
      (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(_pantalla(_api(registros: _tresRegistros)));
    await tester.pumpAndSettle();

    final dd = tester.widget<DropdownButton<String>>(find.descendant(
      of: find.byKey(const Key('org-entidad')),
      matching: find.byType(DropdownButton<String>),
    ));
    expect(dd.items!.map((i) => i.value).toList(),
        ['Aguascalientes', 'Zacatecas', Copy.orgEntidadOtro]);
  });

  testWidgets('si el catálogo de entidades falla, queda "Otro" y un aviso llano',
      (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(
        _pantalla(_api(registros: _tresRegistros, estadosFallan: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('org-entidad-error')), findsOneWidget);
    final dd = tester.widget<DropdownButton<String>>(find.descendant(
      of: find.byKey(const Key('org-entidad')),
      matching: find.byType(DropdownButton<String>),
    ));
    expect(dd.items!.map((i) => i.value).toList(), [Copy.orgEntidadOtro]);
  });

  testWidgets('editar manda el PATCH tras confirmar', (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_pantalla(_api(rec: rec, registros: _tresRegistros)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('org-edit-i1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org-edit-dialog')), findsOneWidget);
    // Nada se manda por abrir el diálogo.
    expect(rec.requests.any((r) => r.method == 'PATCH'), isFalse);

    await tester.enterText(find.byKey(const Key('org-edit-value')), '7');
    await tester.enterText(
        find.byKey(const Key('org-edit-descripcion')), 'Corregido');
    await tester.tap(find.byKey(const Key('org-edit-ok')));
    await tester.pumpAndSettle();

    final patch = rec.requests.firstWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, '/api/v1/admin/indicators/organizational/i1');
    final body =
        json.decode((patch as http.Request).body) as Map<String, dynamic>;
    expect(body['value'], 7);
    expect(body['descripcion'], 'Corregido');
    expect(body['estado'], 'Aguascalientes');

    // Y recarga: 1 al abrir + 1 tras editar.
    expect(_gets(rec), 2);

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('cancelar la edición NO manda nada', (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_pantalla(_api(rec: rec, registros: _tresRegistros)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('org-edit-i1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('org-edit-value')), '7');
    await tester.tap(find.byKey(const Key('org-edit-cancel')));
    await tester.pumpAndSettle();

    expect(rec.requests.any((r) => r.method == 'PATCH'), isFalse);
    expect(_gets(rec), 1);
  });

  testWidgets('borrar manda el DELETE tras confirmar', (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_pantalla(_api(rec: rec, registros: _tresRegistros)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('org-delete-i2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('org-delete-dialog')), findsOneWidget);
    expect(rec.requests.any((r) => r.method == 'DELETE'), isFalse);

    await tester.tap(find.byKey(const Key('org-delete-ok')));
    await tester.pumpAndSettle();

    final del = rec.requests.firstWhere((r) => r.method == 'DELETE');
    expect(del.url.path, '/api/v1/admin/indicators/organizational/i2');
    expect(_gets(rec), 2);

    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('cancelar el borrado NO elimina', (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_pantalla(_api(rec: rec, registros: _tresRegistros)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('org-delete-i2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('org-delete-cancel')));
    await tester.pumpAndSettle();

    expect(rec.requests.any((r) => r.method == 'DELETE'), isFalse);
    expect(_gets(rec), 1);
  });

  testWidgets('sin registros, lo dice en texto llano', (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(_pantalla(_api(registros: const [])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('org-vacio')), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('org-vacio'))).data,
        Copy.orgEmpty);
  });

  testWidgets('si la lista no carga, lo dice en texto llano y deja reintentar',
      (tester) async {
    _pantallaGrande(tester);
    final rec = RequestRecorder();
    await tester.pumpWidget(_pantalla(_api(rec: rec, listaFalla: true)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('org-error')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('org-error'))).data,
        Copy.orgLoadError);

    await tester.tap(find.byKey(const Key('org-reload')));
    await tester.pumpAndSettle();
    expect(_gets(rec), 2);
  });

  testWidgets('el aviso de U1 (sin metas ni semáforos) sigue presente',
      (tester) async {
    _pantallaGrande(tester);
    await tester.pumpWidget(_pantalla(_api(registros: _tresRegistros)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('org-u1-note')), findsOneWidget);
    final aviso = tester.widget<Text>(find.byKey(const Key('org-u1-note'))).data!;
    expect(aviso, contains('metas'));
    expect(aviso, contains('semáforos'));
  });
}
