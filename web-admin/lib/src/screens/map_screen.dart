import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../ui/copy.dart';

/// Encuadre inicial: **Aguascalientes** (igual que el móvil, CR-009). El centro
/// y el zoom son del catálogo de la ciudad; NO son coords de ningún árbol.
const LatLng kAguascalientesCenter = LatLng(21.8853, -102.2916);
const double kAguascalientesZoom = 12;

/// Resuelve el color del calor (0..3) desde el tema (T7: sin colores literales
/// en los widgets; la rampa vive en [HeatRampTheme]).
Color heatColor(BuildContext context, double g4Indice) {
  final ramp = Theme.of(context).extension<HeatRampTheme>() ??
      HeatRampTheme.defaults;
  return ramp.colorFor(g4Indice);
}

/// Pantalla **Mapa** de la consola (CR-010 #2): mapa de calor de `/public/grid`
/// (celdas de 300 m, tiles OSM, leyenda por severidad). Visible para TODOS los
/// roles de la consola. Gate #5: nunca pide ni muestra coords exactas (el centro
/// de cada celda viene obfuscado a ~300 m server-side); gate #1: muestra
/// presencia/impacto, no control/manejo.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late Future<List<GridCell>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).publicGrid();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Copy.navMap, style: theme.textTheme.displayLarge),
              const SizedBox(height: 8),
              Text(Copy.mapIntro, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder<List<GridCell>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const _MapWithCells(cells: []);
                  }
                  if (snap.hasError) {
                    return const _MapErrorState();
                  }
                  return _MapWithCells(cells: snap.data ?? const []);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// El `FlutterMap` con OSM + la capa de celdas + leyenda en overlay.
class _MapWithCells extends StatelessWidget {
  const _MapWithCells({required this.cells});

  final List<GridCell> cells;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            key: const Key('heat_map'),
            options: const MapOptions(
              initialCenter: kAguascalientesCenter,
              initialZoom: kAguascalientesZoom,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'mx.proyecto.mezquite',
              ),
              MarkerLayer(
                key: const Key('heat_cells'),
                markers: [
                  for (final cell in cells)
                    Marker(
                      point: LatLng(cell.lat, cell.lon),
                      width: 26,
                      height: 26,
                      child: _HeatCell(cell: cell),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap')],
              ),
            ],
          ),
        ),
        const Positioned(left: 12, bottom: 16, child: _HeatLegend()),
      ],
    );
  }
}

/// Una celda de calor: círculo coloreado por `g4_indice`, tappable → popup.
class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.cell});

  final GridCell cell;

  @override
  Widget build(BuildContext context) {
    final color = heatColor(context, cell.g4Indice);
    return GestureDetector(
      key: Key('heat_cell_${cell.lat}_${cell.lon}'),
      onTap: () => _showCellPopup(context, cell),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.78),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          '${cell.n}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Popup de una celda: `n`, paxtle, cúscuta y la severidad media.
/// NUNCA coords exactas ni lista de árboles (gate #5).
void _showCellPopup(BuildContext context, GridCell cell) {
  final level = cell.g4Indice.round().clamp(0, 3);
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        key: const Key('heat_cell_popup'),
        title: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: heatColor(ctx, cell.g4Indice),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(Copy.mapCellTitle, style: theme.textTheme.titleLarge),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PopupRow(label: Copy.mapCellObs, value: '${cell.n}'),
            _PopupRow(label: Copy.mapCellPaxtle, value: '${cell.nPaxtle}'),
            _PopupRow(label: Copy.mapCellCuscuta, value: '${cell.nCuscuta}'),
            _PopupRow(
              label: Copy.mapCellNivel,
              value: Copy.mapLegendLevels[level],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      );
    },
  );
}

class _PopupRow extends StatelessWidget {
  const _PopupRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 16),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// Leyenda del calor (verde → rojo) por `g4_indice` 0..3.
class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('heat_legend'),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Copy.mapLegendTitle,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < Copy.mapLegendLevels.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: heatColor(context, i.toDouble()),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Copy.mapLegendLevels[i],
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado de error: mantiene el mapa base (encuadre Aguascalientes) y avisa.
class _MapErrorState extends StatelessWidget {
  const _MapErrorState();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _MapWithCells(cells: [])),
        Positioned(
          top: 24,
          left: 0,
          right: 0,
          child: Center(
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(Copy.mapError, key: Key('map-error')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
