import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/models/models.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/theme/app_theme.dart';
import 'package:mezquite_app/src/ui/copy.dart';
import 'package:mezquite_app/src/ui/screens/heat_map_screen.dart';

import 'helpers.dart';

/// CR-009 · CR-025 — Mapa público del mezquite. Verifica (con datos MOCK, sin
/// backend real) que la vista "Mapa" renderiza el mapa de calor, la leyenda, el
/// popup por celda y el botón "ⓘ", y que el selector conmuta a **ubicaciones
/// exactas** (un marcador por árbol con popup de severidad/paxtle/cúscuta/fecha
/// y coordenadas). Gates: #1 (presencia/impacto, no control), #3 (abre siempre,
/// sin sesión).

/// Celdas de calor mock: varias celdas de Aguascalientes con severidad variada.
final _mockCells = <GridCell>[
  const GridCell(
    lat: 21.8853,
    lon: -102.2916,
    n: 5,
    nPaxtle: 4,
    nCuscuta: 1,
    g4Indice: 2.4,
    snapshotQuarter: '2026-Q2',
  ),
  const GridCell(
    lat: 21.8901,
    lon: -102.2850,
    n: 2,
    nPaxtle: 0,
    nCuscuta: 0,
    g4Indice: 0.0,
    snapshotQuarter: '2026-Q2',
  ),
  const GridCell(
    lat: 21.8800,
    lon: -102.3000,
    n: 3,
    nPaxtle: 2,
    nCuscuta: 2,
    g4Indice: 1.3,
    snapshotQuarter: '2026-Q2',
  ),
];

/// Observaciones exactas mock (CR-025): coords reales por árbol.
final _mockObs = <PublicObservation>[
  PublicObservation(
    handle: 'h1',
    lat: 21.8853,
    lon: -102.2916,
    nivelG4: 'severo',
    flagCuscuta: true,
    flagDanio: true,
    estado: 'AGU',
    municipio: 'Aguascalientes',
    capturedAt: DateTime.utc(2026, 5, 30, 10),
    snapshotQuarter: '2026-Q2',
  ),
  PublicObservation(
    handle: 'h2',
    lat: 21.8901,
    lon: -102.2850,
    nivelG4: 'sano',
    flagCuscuta: false,
    flagDanio: false,
    estado: 'AGU',
    municipio: 'Aguascalientes',
    capturedAt: DateTime.utc(2026, 6, 1, 9),
    snapshotQuarter: '2026-Q2',
  ),
];

const _mockIndicators = Indicators(
  snapshotQuarter: '2026-Q2',
  caveat: 'Datos de origen ciudadano, sin validación por expertos; '
      'especie y nivel autodeclarados.',
  social: {'registrados': 12, 'observaciones_totales': 30},
  educativo: {},
  ecologico: {'arboles_unicos': 18},
  organizacional: {},
);

List<Override> _overrides({bool withIndicators = true}) => [
      publicGridProvider.overrideWith((ref) async => _mockCells),
      publicObservationsProvider.overrideWith((ref) async => _mockObs),
      if (withIndicators)
        publicIndicatorsProvider.overrideWith((ref) async => _mockIndicators),
    ];

/// Superficie amplia para que los overlays (leyenda/ⓘ/selector) no se recorten.
void _wideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('AC1: renderiza el mapa de calor, la capa de celdas y la leyenda',
      (tester) async {
    _wideSurface(tester);
    await tester.pumpWidget(
      wrap(const HeatMapScreen(), overrides: _overrides()),
    );
    // El provider de grid resuelve en un microtask; un par de frames bastan.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // FlutterMap montado (mapa a pantalla completa).
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('heat_map')), findsOneWidget);

    // Default = mapa de calor: capa de celdas visible, sin pines exactos.
    expect(find.byKey(const Key('map_mode_toggle')), findsOneWidget);
    expect(find.byKey(const Key('heat_cells')), findsOneWidget);
    expect(find.byKey(const Key('exact_trees')), findsNothing);
    expect(find.byType(MarkerLayer), findsOneWidget);

    // Leyenda visible con los 4 niveles (verde→rojo).
    expect(find.byKey(const Key('heat_legend')), findsOneWidget);
    expect(find.text('Sano'), findsWidgets);
    expect(find.text('Severo'), findsWidgets);

    // Mapa PURO: sin lista de observaciones ni tarjeta de indicadores en pantalla.
    expect(find.byType(ListView), findsNothing);
    expect(find.byKey(const Key('map_indicators')), findsNothing);
  });

  testWidgets('AC3: el botón "ⓘ" abre el panel con disclaimer + indicadores',
      (tester) async {
    _wideSurface(tester);
    await tester.pumpWidget(
      wrap(const HeatMapScreen(), overrides: _overrides()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('map_info_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('map_info_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // El panel muestra el disclaimer (gate #1) y los indicadores numéricos.
    expect(find.byKey(const Key('map_info_sheet')), findsOneWidget);
    expect(find.textContaining('sin validación'), findsWidgets);
    // CR-025: el disclaimer ya NO promete ubicación aproximada/obfuscada.
    expect(find.textContaining('~300'), findsNothing);
    expect(find.textContaining('aproximad'), findsNothing);
    expect(find.byKey(const Key('map_indicators')), findsOneWidget);
    // Un indicador numérico real (registrados = 12).
    expect(find.text('12'), findsWidgets);
  });

  testWidgets(
      'el popup de una celda muestra n/paxtle/cúscuta, sin obfuscación (CR-025)',
      (tester) async {
    _wideSurface(tester);
    await tester.pumpWidget(
      wrap(const HeatMapScreen(), overrides: _overrides()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Toca la primera celda (key derivada de su centro de celda).
    final cell = find.byKey(const Key('heat_cell_21.8853_-102.2916'));
    expect(cell, findsOneWidget);
    await tester.tap(cell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('heat_cell_popup')), findsOneWidget);
    // Muestra los conteos agregados y el título de celda del mapa de calor.
    expect(find.text('Observaciones'), findsOneWidget);
    expect(find.text('Con paxtle'), findsOneWidget);
    expect(find.text('Con cúscuta'), findsOneWidget);
    expect(find.text(Copy.mapCellTitle), findsOneWidget);
    // CR-025: el popup ya no habla de ubicación aproximada ni radio de 300 m.
    expect(find.textContaining('aproximad'), findsNothing);
    expect(find.textContaining('300'), findsNothing);
  });

  testWidgets('CR-025: el selector conmuta a ubicaciones exactas (un pin por árbol)',
      (tester) async {
    _wideSurface(tester);
    await tester.pumpWidget(
      wrap(const HeatMapScreen(), overrides: _overrides()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Default = calor: hay celdas, no pines exactos.
    expect(find.byKey(const Key('heat_cells')), findsOneWidget);
    expect(find.byKey(const Key('exact_trees')), findsNothing);

    // Conmuta a "Ubicaciones exactas".
    await tester.tap(find.text(Copy.mapModeExact));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Ahora hay pines exactos y NO la capa de celdas.
    expect(find.byKey(const Key('exact_trees')), findsOneWidget);
    expect(find.byKey(const Key('heat_cells')), findsNothing);
  });

  testWidgets(
      'CR-025: el popup de un árbol muestra nivel/paxtle/cúscuta/fecha + lat-lon '
      '6 decimales, sin handle', (tester) async {
    _wideSurface(tester);
    await tester.pumpWidget(
      wrap(const HeatMapScreen(), overrides: _overrides()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Conmuta a exacto y espera a que carguen las observaciones.
    await tester.tap(find.text(Copy.mapModeExact));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final tree = find.byKey(const Key('tree_21.8853_-102.2916'));
    expect(tree, findsOneWidget);
    await tester.tap(tree);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('tree_popup')), findsOneWidget);
    expect(find.text(Copy.mapTreeNivel), findsOneWidget);
    expect(find.text(Copy.mapTreePaxtle), findsOneWidget);
    expect(find.text(Copy.mapTreeCuscuta), findsOneWidget);
    expect(find.text(Copy.mapTreeFecha), findsOneWidget);
    // Coordenadas EXACTAS con 6 decimales (CR-025).
    expect(find.textContaining('21.885300'), findsOneWidget);
    expect(find.textContaining('-102.291600'), findsOneWidget);
    // Nunca se muestra el handle del autor en el popup público.
    expect(find.text('h1'), findsNothing);
  });

  testWidgets('gate #3: el mapa abre SIN sesión (entrada pública)',
      (tester) async {
    _wideSurface(tester);
    // Sin override de auth ni token: el mapa debe montar igual (datos públicos).
    await tester.pumpWidget(
      wrap(const HeatMapScreen(showBack: true), overrides: _overrides()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(FlutterMap), findsOneWidget);
    // En la entrada pública por ruta propia aparece el botón de regreso.
    expect(find.byKey(const Key('map_back_button')), findsOneWidget);
  });

  testWidgets('encuadre inicial en Aguascalientes (CR-009)', (tester) async {
    _wideSurface(tester);
    await tester.pumpWidget(
      wrap(const HeatMapScreen(), overrides: _overrides()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter, kAguascalientesCenter);
    expect(map.options.initialZoom, kAguascalientesZoom);
  });

  test('la rampa de calor mapea g4_indice 0..3 de verde a rojo', () {
    // La rampa vive en el tema (T7); 0 = verde, 3 = rojo.
    const ramp = HeatRampTheme.defaults;
    final sano = ramp.colorFor(0);
    final severo = ramp.colorFor(3);
    expect((sano.g * 255).round() > (sano.r * 255).round(), isTrue,
        reason: 'g4=0 debe tirar a verde',);
    expect((severo.r * 255).round() > (severo.g * 255).round(), isTrue,
        reason: 'g4=3 debe tirar a rojo',);
    // Interpolación intermedia: g4=2 (naranja) tiene rojo alto y verde medio.
    final moderado = ramp.colorFor(2);
    expect((moderado.r * 255).round(), greaterThan(200));
  });

  test('nivelIndex mapea el vocabulario G4 a 0..3', () {
    expect(nivelIndex('sano'), 0);
    expect(nivelIndex('leve'), 1);
    expect(nivelIndex('moderado'), 2);
    expect(nivelIndex('severo'), 3);
    expect(nivelIndex('desconocido'), 0);
  });
}
