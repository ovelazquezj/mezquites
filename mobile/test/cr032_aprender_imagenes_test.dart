import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/services/pending/pending_store.dart';
import 'package:mezquite_app/src/services/session_store.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/home_shell.dart';
import 'package:mezquite_app/src/ui/screens/learning_detail_screen.dart';
import 'package:mezquite_app/src/ui/screens/learning_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// CR-032 — la app abre en "Aprender" y los módulos llevan ilustración.
///
/// Las imágenes van **empaquetadas**, no enlazadas: los módulos de reconocimiento
/// se consultan en campo, frente al árbol y a menudo sin señal, así que una imagen
/// que dependa de la red no serviría justo cuando hace falta. Estas pruebas fijan
/// eso (ninguna URL remota en el contenido) y la atribución que exige la licencia.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const imagenes = {
    'mod_que_es': 'mezquite.jpg',
    'mod_paxtle': 'paxtle-tillandsia-recurvata.jpg',
    'mod_cuscuta': 'cuscuta.jpg',
  };

  group('las ilustraciones están EMPAQUETADAS, no enlazadas', () {
    test('cada módulo referencia su imagen con ruta relativa', () {
      imagenes.forEach((modulo, archivo) {
        final md = File('../docs/learning/$modulo.md').readAsStringSync();
        expect(
          md.contains('](img/$archivo)'),
          isTrue,
          reason: '$modulo debe referenciar img/$archivo',
        );
      });
    });

    test('ningún módulo carga imágenes por red', () {
      for (final f in Directory('../docs/learning')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))) {
        final md = f.readAsStringSync();
        // Los enlaces de "Saber más" y de licencia SÍ son remotos; lo que no puede
        // haber es una IMAGEN remota, es decir `![...](http...)`.
        expect(
          RegExp(r'!\[[^\]]*\]\(\s*https?:').hasMatch(md),
          isFalse,
          reason: '${f.path} no debe traer imágenes por red',
        );
      }
    });

    test('los archivos existen en la fuente y en el bundle, idénticos', () {
      for (final archivo in imagenes.values) {
        final fuente = File('../docs/learning/img/$archivo');
        final bundle = File('assets/learning/img/$archivo');
        expect(fuente.existsSync(), isTrue, reason: 'falta $archivo en docs/');
        expect(bundle.existsSync(), isTrue, reason: 'falta $archivo en assets/');
        expect(
          bundle.readAsBytesSync(),
          fuente.readAsBytesSync(),
          reason: '$archivo difiere entre la fuente y el bundle',
        );
        // Que sean JPEG de verdad (magic bytes), no un HTML de error renombrado:
        // las URLs de Commons del CSV devolvían text/html.
        final bytes = bundle.readAsBytesSync();
        expect(bytes[0], 0xFF, reason: '$archivo no parece JPEG');
        expect(bytes[1], 0xD8, reason: '$archivo no parece JPEG');
      }
    });

    test('los .md del bundle son copia exacta de la fuente', () {
      for (final modulo in imagenes.keys) {
        expect(
          File('assets/learning/$modulo.md').readAsStringSync(),
          File('../docs/learning/$modulo.md').readAsStringSync(),
          reason: '$modulo.md quedó desincronizado',
        );
      }
    });

    test('pubspec declara assets/learning/img/ explícitamente', () {
      // Declarar `assets/learning/` NO incluye subcarpetas en Flutter: sin esta
      // línea las imágenes no viajan en el bundle y solo se vería el texto.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('assets/learning/img/'), isTrue);
    });
  });

  group('atribución (condición de la licencia, no cortesía)', () {
    test('las dos CC BY-SA nombran autor, licencia y enlace', () {
      final paxtle = File('../docs/learning/mod_paxtle.md').readAsStringSync();
      expect(paxtle, contains('Juan Carlos Fonseca Mata'));
      expect(paxtle, contains('CC BY-SA 4.0'));
      expect(paxtle, contains('creativecommons.org/licenses/by-sa/4.0'));

      final cuscuta = File('../docs/learning/mod_cuscuta.md').readAsStringSync();
      expect(cuscuta, contains('ShahadatHossain'));
      expect(cuscuta, contains('CC BY-SA 4.0'));
      expect(cuscuta, contains('creativecommons.org/licenses/by-sa/4.0'));
    });

    test('la de dominio público también acredita al autor', () {
      final md = File('../docs/learning/mod_que_es.md').readAsStringSync();
      expect(md, contains('Renebeto'));
      expect(md.toLowerCase(), contains('dominio público'));
    });

    test('existe el registro de procedencia', () {
      final creditos =
          File('../docs/learning/CREDITOS-IMAGENES.md').readAsStringSync();
      for (final archivo in imagenes.values) {
        expect(creditos, contains(archivo));
      }
      // Y la advertencia de que recortar/retocar sí crearía obra derivada.
      expect(creditos.toLowerCase(), contains('obra derivada'));
    });
  });

  group('la app abre en Aprender', () {
    testWidgets('la pestaña inicial es Aprender, no la cámara', (tester) async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        wrap(
          const HomeShell(),
          overrides: [
            pendingStoreProvider.overrideWithValue(store),
            sessionStoreProvider.overrideWithValue(await SessionStore.create()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // La pantalla montada es la de Aprender.
      expect(find.byType(LearningScreen), findsOneWidget);
      // Y la barra inferior marca ese destino como seleccionado.
      final nav = tester.widget<NavigationBar>(find.byKey(const Key('home_nav')));
      expect(nav.selectedIndex, 1);
    });

    testWidgets('capturar sigue estando a un toque', (tester) async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        wrap(
          const HomeShell(),
          overrides: [
            pendingStoreProvider.overrideWithValue(store),
            sessionStoreProvider.overrideWithValue(await SessionStore.create()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final nav = tester.widget<NavigationBar>(find.byKey(const Key('home_nav')));
      // Gate #3: los cuatro destinos siguen disponibles desde el primer momento.
      expect(nav.destinations, hasLength(4));
      expect(nav.onDestinationSelected, isNotNull);
    });
  });

  group('el detalle pinta la imagen desde los assets', () {
    /// Monta el detalle de un módulo con los `.md` leídos del disco.
    Future<void> abrirModulo(WidgetTester tester, String modulo) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final mod = LearningModule.placeholders
          .firstWhere((m) => m.assetPath.contains(modulo));
      await tester.pumpWidget(
        wrap(
          DefaultAssetBundle(
            bundle: _DiskAssetBundle(),
            child: LearningDetailScreen(module: mod),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mod_cuscuta muestra la imagen y no el texto de reemplazo',
        (tester) async {
      await abrirModulo(tester, 'mod_cuscuta');

      expect(find.byKey(const Key('learning_image')), findsOneWidget);
      expect(find.byKey(const Key('learning_image_fallback')), findsNothing);
      // El pie de foto con la atribución se ve en pantalla, no solo en el archivo.
      expect(find.textContaining('ShahadatHossain'), findsOneWidget);
    });

    // Esta es la aserción que faltaba y por la que el fallo llegó a producción:
    // la imagen SÍ estaba en el árbol, pero con `Size(ancho, 0)` — invisible.
    // Estar presente no es estar visible.
    for (final modulo in ['mod_que_es', 'mod_paxtle', 'mod_cuscuta']) {
      testWidgets('$modulo: la imagen se renderiza con alto MAYOR QUE CERO',
          (tester) async {
        await abrirModulo(tester, modulo);

        final img = find.byKey(const Key('learning_image'));
        expect(img, findsOneWidget);
        final tamano = tester.getSize(img);
        expect(
          tamano.height,
          greaterThan(0),
          reason: '$modulo: la ilustración quedaría invisible',
        );
        expect(tamano.width, greaterThan(0));
      });
    }
  });
}

/// Bundle que lee los `.md` del disco y delega el resto (imágenes incluidas) al
/// `rootBundle`. Mismo enfoque que `learning_test.dart`.
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

