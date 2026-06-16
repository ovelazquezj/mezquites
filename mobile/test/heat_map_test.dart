import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/models/models.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:mezquite_app/src/theme/app_theme.dart';
import 'package:mezquite_app/src/ui/screens/heat_map_screen.dart';

import 'helpers.dart';

/// CR-009 — Mapa de calor público. Verifica (con celdas MOCK, sin backend real)
/// que la vista "Mapa" renderiza el mapa, la capa de celdas, la leyenda, el
/// popup por celda y el botón "ⓘ". Gates: #5 (la UI nunca muestra coords
/// exactas; el popup habla de celda aproximada ~300 m), #1 (presencia/impacto,
/// no control), #3 (abre siempre, sin sesión).

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
      if (withIndicators)
        publicIndicatorsProvider.overrideWith((ref) async => _mockIndicators),
    ];

/// Superficie amplia para que los overlays (leyenda/ⓘ) no se recorten.
void _wideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('AC1: renderiza el mapa, la capa de celdas y la leyenda',
      (tester) async {
    _wideSurface(tester);
    await tester.pumpWidget(
      wrap(const HeatMapScreen(), overrides: _overrides()),
    );
    // El provider de grid resuelve en un microtask; un par de frames bastan.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // FlutterMap montado (mapa puro a pantalla completa).
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('heat_map')), findsOneWidget);

    // Capa de celdas con un marker por celda mock.
    expect(find.byKey(const Key('heat_cells')), findsOneWidget);
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

    // El panel muestra el disclaimer (gates #5/#1) y los indicadores numéricos.
    expect(find.byKey(const Key('map_info_sheet')), findsOneWidget);
    expect(find.textContaining('~300 m'), findsWidgets);
    expect(find.textContaining('sin validación'), findsWidgets);
    expect(find.byKey(const Key('map_indicators')), findsOneWidget);
    // Un indicador numérico real (registrados = 12).
    expect(find.text('12'), findsWidgets);
  });

  testWidgets('el popup de una celda muestra n/paxtle/cúscuta, no coords exactas',
      (tester) async {
    _wideSurface(tester);
    await tester.pumpWidget(
      wrap(const HeatMapScreen(), overrides: _overrides()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Toca la primera celda (key derivada de su centro de celda obfuscado).
    final cell = find.byKey(const Key('heat_cell_21.8853_-102.2916'));
    expect(cell, findsOneWidget);
    await tester.tap(cell);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('heat_cell_popup')), findsOneWidget);
    // Muestra los conteos agregados.
    expect(find.text('Observaciones'), findsOneWidget);
    expect(find.text('Con paxtle'), findsOneWidget);
    expect(find.text('Con cúscuta'), findsOneWidget);
    // Gate #5: habla de celda aproximada, nunca de coordenadas exactas.
    expect(find.textContaining('aproximada'), findsWidgets);
    expect(find.textContaining('Latitud'), findsNothing);
    expect(find.textContaining('Longitud'), findsNothing);
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
}
