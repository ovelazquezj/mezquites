import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../copy.dart';

/// Encuadre inicial del mapa: **Aguascalientes** (CR-009 §4.2). El centro y el
/// zoom son del catálogo de la ciudad; NO son coords de ningún árbol.
const LatLng kAguascalientesCenter = LatLng(21.8853, -102.2916);
const double kAguascalientesZoom = 12;

/// Resuelve el color del calor (0..3) desde el tema (T7: sin colores literales
/// en los widgets; la rampa vive en [HeatRampTheme]).
Color heatColor(BuildContext context, double g4Indice) {
  final ramp = Theme.of(context).extension<HeatRampTheme>() ??
      HeatRampTheme.defaults;
  return ramp.colorFor(g4Indice);
}

/// Mapa de calor público del mezquite (CR-009).
///
/// **Mapa puro a pantalla completa:** `FlutterMap` con tiles de OpenStreetMap y
/// una capa de celdas de calor (markers coloreados por `g4_indice`). SIN tarjeta
/// de indicadores ni lista en la pantalla: los números y el aviso viven detrás
/// del botón "ⓘ". Funciona **con o sin sesión** (los endpoints `public/*` no
/// requieren auth): la entrada pública desde la Bienvenida y la pestaña "Mapa"
/// del HomeShell usan esta MISMA pantalla.
///
/// Gates: #5 (la UI nunca pide ni muestra coords exactas; el centro de cada
/// celda viene obfuscado a ~300 m server-side), #1 (muestra presencia/impacto,
/// no control/manejo), #3 (abre siempre, sin gating).
class HeatMapScreen extends ConsumerWidget {
  /// [showBack] = true cuando se entra como ruta propia (entrada pública sin
  /// sesión desde la Bienvenida): muestra un botón de regreso en overlay. En la
  /// pestaña "Mapa" del HomeShell es false (la navegación inferior basta).
  const HeatMapScreen({super.key, this.showBack = false});

  final bool showBack;

  /// Navega a la pantalla de mapa como ruta propia (con botón de regreso). La
  /// usa la entrada pública SIN sesión desde la Bienvenida (gate #3: abre
  /// siempre; los endpoints `public/*` no requieren auth).
  static void openPublic(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HeatMapScreen(showBack: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gridAsync = ref.watch(publicGridProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: gridAsync.when(
              loading: () => const _MapWithCells(cells: []),
              error: (e, _) => const _MapErrorState(),
              data: (cells) => _MapWithCells(cells: cells),
            ),
          ),
          // Botón de regreso (solo en la entrada pública por ruta propia).
          if (showBack)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: Material(
                key: const Key('map_back_button'),
                color: Theme.of(context).colorScheme.surface,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  tooltip: 'Volver',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          // Botón "ⓘ" (overlay, esquina superior derecha): abre el panel con el
          // disclaimer + indicadores. La pantalla queda como mapa puro.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _InfoButton(),
          ),
          // Leyenda del calor (overlay, esquina inferior izquierda).
          const Positioned(
            left: 12,
            bottom: 16,
            child: _HeatLegend(),
          ),
        ],
      ),
    );
  }
}

/// El `FlutterMap` con OSM + la capa de celdas. Se separa para reusarlo en los
/// estados de carga (mapa vacío) y con datos.
class _MapWithCells extends StatelessWidget {
  const _MapWithCells({required this.cells});

  final List<GridCell> cells;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      key: const Key('heat_map'),
      options: const MapOptions(
        initialCenter: kAguascalientesCenter,
        initialZoom: kAguascalientesZoom,
        // Sin rotación: mantiene el norte arriba (lectura simple del calor).
        interactionOptions: InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // Requisito de uso de los tiles de OSM (etapa de demo, CR-009 §7).
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
        // Atribución obligatoria de OpenStreetMap.
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap'),
          ],
        ),
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

/// Popup de una celda: muestra `n`, paxtle, cúscuta y la mezcla de severidad.
/// NUNCA coords exactas ni lista de árboles (gate #5).
void _showCellPopup(BuildContext context, GridCell cell) {
  final level = cell.g4Indice.round().clamp(0, 3);
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          key: const Key('heat_cell_popup'),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  Text(
                    'Celda aproximada (~300 m)',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PopupRow(label: 'Observaciones', value: '${cell.n}'),
              _PopupRow(label: 'Con paxtle', value: '${cell.nPaxtle}'),
              _PopupRow(label: 'Con cúscuta', value: '${cell.nCuscuta}'),
              _PopupRow(
                label: 'Nivel de paxtle (promedio)',
                value: Copy.mapLegendLevels[level],
              ),
              const SizedBox(height: 12),
              Text(
                'Severidad autodeclarada por quien observa; sin validación '
                'experta. Ubicación aproximada para proteger a los árboles.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
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
          Text(value, style: theme.textTheme.titleMedium),
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

/// Botón "ⓘ": abre el panel con el disclaimer (gates #5/#1) + los indicadores
/// numéricos (de `/public/indicators`). Así el mapa queda puro.
class _InfoButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map_info_button'),
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: Copy.mapInfoTooltip,
        icon: const Icon(Icons.info_outline),
        onPressed: () => _showInfoSheet(context),
      ),
    );
  }
}

/// Panel del botón "ⓘ": disclaimer + indicadores numéricos públicos.
void _showInfoSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (ctx, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            key: const Key('map_info_sheet'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Copy.mapInfoTitle,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  Copy.mapDisclaimer,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                const _IndicatorsBlock(),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Indicadores numéricos públicos (Q6), mostrados dentro del panel "ⓘ".
class _IndicatorsBlock extends ConsumerWidget {
  const _IndicatorsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indAsync = ref.watch(publicIndicatorsProvider);
    final theme = Theme.of(context);
    return indAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (ind) {
        final social = ind.social;
        final eco = ind.ecologico;
        return Column(
          key: const Key('map_indicators'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Copy.mapIndicatorsTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Última actualización: ${ind.snapshotQuarter}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            _IndRow(
              label: 'Registrados',
              value: '${social['registrados'] ?? '-'}',
            ),
            _IndRow(
              label: 'Observaciones totales',
              value: '${social['observaciones_totales'] ?? '-'}',
            ),
            _IndRow(
              label: 'Árboles únicos',
              value: '${eco['arboles_unicos'] ?? '-'}',
            ),
            const SizedBox(height: 8),
            Text(ind.caveat, style: theme.textTheme.bodySmall),
          ],
        );
      },
    );
  }
}

class _IndRow extends StatelessWidget {
  const _IndRow({required this.label, required this.value});

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
          Text(value, style: theme.textTheme.titleMedium),
        ],
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
          top: MediaQuery.of(context).padding.top + 64,
          left: 0,
          right: 0,
          child: Center(
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(Copy.mapError),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
