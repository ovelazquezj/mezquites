import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_app/src/api/api_client.dart';
import 'package:mezquite_app/src/models/models.dart';
import 'package:mezquite_app/src/services/session_store.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// CR-028: el login no puede fabricar instituciones duplicadas.
///
/// En producción convivieron dos "Global University" porque el campo "Registrar nueva institución"
/// del login mandaba texto libre sin mirar el catálogo que la propia pantalla ya tenía cargado.
/// Aquí se fija que ese cotejo ocurre, y que usa la MISMA regla que el backend y el índice único
/// de la base (sin acentos, minúsculas, espacios colapsados).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalogo = [
    {
      'id': 'inst-1',
      'name': 'Universidad Cuauhtémoc',
      'estado': 'Aguascalientes',
      'status': 'aprobada',
    },
  ];

  Future<SessionStore> emptyStore() async {
    SharedPreferences.setMockInitialValues({});
    return SessionStore.create();
  }

  Future<void> pumpLogin(WidgetTester tester, {List<http.Request>? capturadas}) async {
    final store = await emptyStore();
    final mock = MockClient((req) async {
      capturadas?.add(req);
      return http.Response(json.encode(catalogo), 200);
    });
    await tester.pumpWidget(
      wrap(
        const WelcomeScreen(),
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          apiClientProvider
              .overrideWithValue(ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock)),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> registrarInstitucion(WidgetTester tester, String nombre) async {
    await tester.tap(find.byKey(const Key('welcome_register_institution')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('welcome_new_institution_field')),
      nombre,
    );
    await tester.tap(find.text('Usar'));
    await tester.pumpAndSettle();
  }

  group('CR-028 — regla del nombre canónico (misma que el backend)', () {
    test('acentos, mayúsculas y espacios no hacen instituciones distintas', () {
      const esperado = 'universidad cuauhtemoc';
      for (final variante in [
        'Universidad Cuauhtémoc',
        'universidad cuauhtemoc',
        '  UNIVERSIDAD   Cuauhtémoc  ',
        'Universidad\tCUAUHTEMOC',
      ]) {
        expect(Institution.normalizeName(variante), esperado, reason: variante);
      }
    });

    test('nombres realmente distintos no colapsan', () {
      expect(
        Institution.normalizeName('Universidad Cuauhtémoc'),
        isNot(Institution.normalizeName('Universidad Cuauhtémoc Aguascalientes')),
      );
    });

    test('ya_existia llega del backend y por omisión es false', () {
      expect(
        Institution.fromJson({
          'id': 'i1',
          'name': 'X',
          'status': 'solicitada',
          'ya_existia': true,
        }).yaExistia,
        isTrue,
      );
      // El catálogo público no manda el campo.
      expect(
        Institution.fromJson({'id': 'i1', 'name': 'X', 'status': 'aprobada'}).yaExistia,
        isFalse,
      );
    });
  });

  group('CR-028 — login: escribir una institución que ya está', () {
    testWidgets('la selecciona en vez de encolar una gemela, y lo dice',
        (tester) async {
      await pumpLogin(tester);

      // Se escribe la MISMA institución del catálogo, con otro acento y espacios de más.
      await registrarInstitucion(tester, '  universidad   cuauhtemoc ');

      // Avisa que ya estaba y la deja elegida...
      expect(
        find.text(Copy.institutionAlreadyInList('Universidad Cuauhtémoc')),
        findsOneWidget,
      );
      // ...y NO queda nada pendiente de registrar (eso habría creado el duplicado).
      expect(find.textContaining('Registrarás:'), findsNothing);
      expect(find.byKey(const Key('welcome_register_institution')), findsOneWidget);
    });

    testWidgets('una institución realmente nueva sí queda pendiente de registro',
        (tester) async {
      await pumpLogin(tester);

      await registrarInstitucion(tester, 'Colegio Nuevo del Valle');

      expect(find.textContaining('Registrarás: Colegio Nuevo del Valle'), findsOneWidget);
      expect(
        find.text(Copy.institutionAlreadyInList('Universidad Cuauhtémoc')),
        findsNothing,
      );
    });

    testWidgets('elegir una existente no dispara ningún POST de alta',
        (tester) async {
      final capturadas = <http.Request>[];
      await pumpLogin(tester, capturadas: capturadas);

      await registrarInstitucion(tester, 'UNIVERSIDAD CUAUHTEMOC');

      expect(
        capturadas.where((r) => r.method == 'POST'),
        isEmpty,
        reason: 'el login no debe pedir alta de una institución que ya existe',
      );
    });
  });
}
