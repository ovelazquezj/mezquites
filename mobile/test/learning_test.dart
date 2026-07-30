import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/learning_detail_screen.dart';
import 'package:mezquite_app/src/ui/screens/learning_screen.dart';

import 'helpers.dart';

/// Bundle de pruebas: sirve los markdown `assets/learning/*.md` leyéndolos del
/// disco (la misma fuente que en runtime) y DELEGA todo lo demás (imágenes de
/// marca, tokens, etc.) al `rootBundle`. Así el detalle carga su contenido sin
/// romper el `Image.asset` del `BrandedAppBar`.
class _DiskAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key.startsWith('assets/learning/')) {
      return File(key).readAsStringSync();
    }
    return rootBundle.loadString(key, cache: cache);
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) async =>
      parser(await loadString(key));
}

/// CR-007 — Contenidos de "Aprender". El motor/UI renderiza el markdown
/// bundleado por módulo; el contenido (texto + enlaces) lo provee `docs/learning/`.
/// Aquí verificamos los criterios de aceptación que tocan a `mobile/` (AC1, AC3,
/// AC4, AC5) y los gates #1/#3/#8. AC2 (abrir el navegador externo) depende de un
/// plugin de plataforma y se valida en QA E2E.

/// Superficie alta para que el `ListView` (lazy) renderice los 7 módulos sin
/// recortar los de abajo (de otro modo `find.byType(ListTile)` no los ve).
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Envuelve un widget con un `DefaultAssetBundle` que lee los `.md` del disco,
/// para que el detalle cargue el contenido en pruebas sin el bundle real.
Widget _withBundle(Widget child) =>
    DefaultAssetBundle(bundle: _DiskAssetBundle(), child: child);

/// Monta el detalle con el bundle de disco (instalado DENTRO del MaterialApp,
/// sobre la pantalla) y deja que el `FutureBuilder` resuelva antes de aserir.
Future<void> _pumpDetail(WidgetTester tester, LearningModule mod) async {
  await tester.pumpWidget(wrap(_withBundle(LearningDetailScreen(module: mod))));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('los 7 módulos del CR-007 están definidos con ids/assets exactos', () {
    const mods = LearningModule.placeholders;
    expect(mods.length, 7);

    const expected = {
      'mod_que_es': 'assets/learning/mod_que_es.md',
      'mod_paxtle': 'assets/learning/mod_paxtle.md',
      'mod_cuscuta': 'assets/learning/mod_cuscuta.md',
      'mod_escala': 'assets/learning/mod_escala.md',
      'mod_buena_foto': 'assets/learning/mod_buena_foto.md',
      'mod_ciencia_ciudadana': 'assets/learning/mod_ciencia_ciudadana.md',
      'mod_que_no_hace': 'assets/learning/mod_que_no_hace.md',
    };
    for (final m in mods) {
      expect(expected.containsKey(m.id), isTrue, reason: 'id inesperado: ${m.id}');
      expect(m.assetPath, expected[m.id]);
      expect(m.title, isNotEmpty);
      expect(m.summary, isNotEmpty);
    }
  });

  testWidgets('AC1: la lista muestra los 7 módulos y abren su detalle',
      (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(wrap(const LearningScreen()));
    await tester.pumpAndSettle();

    // Los 7 módulos aparecen como tarjetas con su key estable.
    for (final m in LearningModule.placeholders) {
      expect(find.byKey(Key('learning_${m.id}')), findsOneWidget);
    }

    // Tocar el primer módulo navega al detalle. El render del cuerpo markdown
    // se verifica aparte (test del detalle con bundle de disco).
    await tester.tap(find.byKey(const Key('learning_mod_que_es')));
    await tester.pump(); // inicia la transición de ruta
    await tester.pump(const Duration(milliseconds: 400)); // completa la transición

    expect(find.byKey(const Key('learning_detail_content')), findsOneWidget);
    // CR-032: el banner de BORRADOR se retiró de la pantalla (petición del
    // usuario). El contenido sigue marcado como borrador en `docs/learning/`.
    expect(find.textContaining('BORRADOR'), findsNothing);
  });

  testWidgets('AC1/AC5: el detalle renderiza el markdown bundleado del módulo',
      (tester) async {
    const mod = LearningModule(
      id: 'mod_que_es',
      title: '¿Qué es el mezquite?',
      summary: 'x',
      assetPath: 'assets/learning/mod_que_es.md',
    );
    await _pumpDetail(tester, mod);

    expect(find.byKey(const Key('learning_detail_markdown')), findsOneWidget);
    expect(find.byKey(const Key('learning_detail_error')), findsNothing);
    // El encabezado "Saber más" del stub se renderiza desde el asset.
    expect(find.textContaining(Copy.learningMoreTitle), findsOneWidget);
  });

  testWidgets('AC5/gate #3: todos los módulos abren siempre (sin bloqueo)',
      (tester) async {
    _tallSurface(tester);
    await tester.pumpWidget(wrap(const LearningScreen()));
    await tester.pumpAndSettle();

    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(7));
    for (var i = 0; i < 7; i++) {
      final tile = tester.widget<ListTile>(tiles.at(i));
      expect(tile.onTap, isNotNull, reason: 'gate #3: ningún módulo bloqueado');
      expect(tile.enabled, isTrue);
    }
    for (final term in ['bloquead', 'certificad', 'nivel requerido', 'desbloque']) {
      expect(find.textContaining(term), findsNothing);
    }
  });

  testWidgets('gate #1: el módulo "Qué NO hace" aclara que no controla plagas',
      (tester) async {
    const mod = LearningModule(
      id: 'mod_que_no_hace',
      title: 'Qué hace y qué NO hace la app',
      summary: 'x',
      assetPath: 'assets/learning/mod_que_no_hace.md',
    );
    await _pumpDetail(tester, mod);

    expect(find.textContaining('no'), findsWidgets);
    expect(find.textContaining('controla'), findsWidgets);
  });

  testWidgets('gate #8: el módulo de la escala dice autodeclarado / a ojo',
      (tester) async {
    const mod = LearningModule(
      id: 'mod_escala',
      title: 'La escala de observación (G4)',
      summary: 'x',
      assetPath: 'assets/learning/mod_escala.md',
    );
    await _pumpDetail(tester, mod);

    expect(find.textContaining('autodeclarado'), findsWidgets);
    expect(find.textContaining('ojo'), findsWidgets);
  });
}
