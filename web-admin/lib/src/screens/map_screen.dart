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

/// Índice 0..3 del nivel de paxtle autodeclarado (sano/leve/moderado/severo).
/// Default 0 (sano) para claves desconocidas.
int _nivelIndex(String nivel) =>
    const {'sano': 0, 'leve': 1, 'moderado': 2, 'severo': 3}[nivel] ?? 0;

/// Modo del mapa: mapa de calor o ubicaciones exactas.
enum _MapMode { heat, exact }

/// Pantalla **Mapa** de la consola (CR-010 #2): mapa de calor de `/public/grid`
/// (tiles OSM, leyenda por severidad). Visible para TODOS los roles de la
/// consola.
///
/// CR-025: la ubicación exacta del mezquite es información pública. Los roles de
/// la consola (con `canSeeExactLocation`) pueden **conmutar** a un mapa de
/// **ubicaciones exactas** (`/restricted/observations`) con un marcador por
/// árbol. La autorización real la impone el backend. Gate #1: muestra
/// presencia/impacto, no control/manejo.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  _MapMode _mode = _MapMode.heat;
  late Future<List<GridCell>> _gridFuture;
  // Se crea perezosamente al conmutar a "exacto" (solo se piden las coords
  // exactas cuando el usuario lo solicita).
  Future<List<RestrictedObservation>>? _exactFuture;

  @override
  void initState() {
    super.initState();
    _gridFuture = ref.read(apiClientProvider).publicGrid();
  }

  void _setMode(_MapMode mode) {
    setState(() {
      _mode = mode;
      if (mode == _MapMode.exact) {
        _exactFuture ??=
            ref.read(apiClientProvider).restrictedObservations(limit: 2000);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canExact = ref.watch(sessionProvider).canSeeRestricted;
    // Si el rol perdiera el permiso, no dejes el mapa en modo exacto.
    final exactActive = canExact && _mode == _MapMode.exact;
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
              if (canExact) ...[
                const SizedBox(height: 12),
                SegmentedButton<_MapMode>(
                  key: const Key('map_mode_toggle'),
                  segments: const [
                    ButtonSegment(
                      value: _MapMode.heat,
                      label: Text(Copy.mapModeHeat),
                      icon: Icon(Icons.blur_on_outlined),
                    ),
                    ButtonSegment(
                      value: _MapMode.exact,
                      label: Text(Copy.mapModeExact),
                      icon: Icon(Icons.location_on_outlined),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => _setMode(s.first),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: exactActive ? _buildExact() : _buildHeat(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeat() {
    return FutureBuilder<List<GridCell>>(
      future: _gridFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _MapWithCells(cells: []);
        }
        if (snap.hasError) {
          return const _MapErrorState();
        }
        return _MapWithCells(cells: snap.data ?? const []);
      },
    );
  }

  Widget _buildExact() {
    return FutureBuilder<List<RestrictedObservation>>(
      future: _exactFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _MapWithExact(observations: []);
        }
        if (snap.hasError) {
          return const _MapExactErrorState();
        }
        return _MapWithExact(observations: snap.data ?? const []);
      },
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

/// El `FlutterMap` en modo **ubicaciones exactas** (CR-025): un marcador por
/// árbol en su coord real y la misma leyenda de severidad. La ubicación exacta
/// es información pública; la ven todos los roles de la consola.
class _MapWithExact extends StatelessWidget {
  const _MapWithExact({required this.observations});

  final List<RestrictedObservation> observations;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            key: const Key('exact_map'),
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
                key: const Key('exact_markers'),
                markers: [
                  for (final obs in observations)
                    Marker(
                      point: LatLng(obs.lat, obs.lon),
                      width: 22,
                      height: 22,
                      child: _ExactMarker(obs: obs),
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

/// Un árbol en su ubicación exacta: círculo pequeño coloreado por su nivel de
/// paxtle, con borde blanco. Tappable → popup con lat/lon exactas.
class _ExactMarker extends StatelessWidget {
  const _ExactMarker({required this.obs});

  final RestrictedObservation obs;

  @override
  Widget build(BuildContext context) {
    final color = heatColor(context, _nivelIndex(obs.nivelG4).toDouble());
    return GestureDetector(
      key: Key('exact_marker_${obs.lat}_${obs.lon}'),
      onTap: () => _showExactPopup(context, obs),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

/// Popup de una celda del mapa de calor: `n`, paxtle, cúscuta y la severidad
/// media (agregado por celda; las coords exactas viven en el modo exacto).
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

/// Popup de un árbol exacto (CR-023): nivel, paxtle, cúscuta, fecha y las
/// **coordenadas exactas** con 6 decimales. Solo accesible en modo exacto.
void _showExactPopup(BuildContext context, RestrictedObservation obs) {
  final level = _nivelIndex(obs.nivelG4);
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        key: const Key('exact_popup'),
        title: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: heatColor(ctx, level.toDouble()),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(Copy.mapExactPopupTitle,
                  style: theme.textTheme.titleLarge),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PopupRow(
                label: Copy.mapLegendTitle, value: Copy.mapLegendLevels[level]),
            _PopupRow(
                label: Copy.mapCellPaxtle, value: obs.flagDanio ? 'Sí' : 'No'),
            _PopupRow(
                label: Copy.mapCellCuscuta,
                value: obs.flagCuscuta ? 'Sí' : 'No'),
            _PopupRow(label: 'Fecha', value: _fmtDate(obs.capturedAt)),
            _PopupRow(
                label: Copy.mapExactPopupLat,
                value: obs.lat.toStringAsFixed(6)),
            _PopupRow(
                label: Copy.mapExactPopupLon,
                value: obs.lon.toStringAsFixed(6)),
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

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

/// Estado de error del calor: mantiene el mapa base (encuadre Aguascalientes) y avisa.
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

/// Estado de error del modo exacto (p. ej. 403): mantiene el mapa base y
/// muestra el aviso sin volver a calor.
class _MapExactErrorState extends StatelessWidget {
  const _MapExactErrorState();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _MapWithExact(observations: [])),
        Positioned(
          top: 24,
          left: 0,
          right: 0,
          child: Center(
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(Copy.mapExactError, key: Key('map-exact-error')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
