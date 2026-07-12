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

/// Modo de presentación del mapa público (CR-025): mapa de calor (celdas
/// agregadas) o ubicaciones exactas (un marcador por árbol). Default: calor.
enum MapMode { heat, exact }

/// `wire` de nivel G4 → índice 0..3 para la rampa de severidad (sano..severo).
int nivelIndex(String wire) {
  switch (wire) {
    case 'leve':
      return 1;
    case 'moderado':
      return 2;
    case 'severo':
      return 3;
    default:
      return 0; // 'sano' u otro
  }
}

/// Mapa público del mezquite (CR-009 · CR-025).
///
/// **Mapa a pantalla completa** con dos modos, conmutables por un selector
/// (default = mapa de calor):
///  - **Mapa de calor:** celdas agregadas coloreadas por `g4_indice`
///    (`/public/grid`).
///  - **Ubicaciones exactas:** un marcador por árbol en su coordenada
///    (`/public/observations`), con popup de severidad, paxtle, cúscuta, fecha
///    y coordenadas.
///
/// Los indicadores numéricos y el aviso viven detrás del botón "ⓘ". Funciona
/// **con o sin sesión** (los endpoints `public/*` no requieren auth): la entrada
/// pública desde la Bienvenida y la pestaña "Mapa" del HomeShell usan esta MISMA
/// pantalla. Gates: #1 (muestra presencia/impacto, no control/manejo), #3 (abre
/// siempre, sin gating).
class HeatMapScreen extends ConsumerStatefulWidget {
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
  ConsumerState<HeatMapScreen> createState() => _HeatMapScreenState();
}

class _HeatMapScreenState extends ConsumerState<HeatMapScreen> {
  MapMode _mode = MapMode.heat;

  @override
  Widget build(BuildContext context) {
    final isExact = _mode == MapMode.exact;

    // Solo observamos el proveedor del modo activo (evita la carga eager del otro).
    final Widget mapLayer;
    if (isExact) {
      final obsAsync = ref.watch(publicObservationsProvider);
      mapLayer = obsAsync.when(
        loading: () => const _MapView(exact: true),
        error: (e, _) => const _MapErrorState(exact: true),
        data: (obs) => _MapView(exact: true, trees: obs),
      );
    } else {
      final gridAsync = ref.watch(publicGridProvider);
      mapLayer = gridAsync.when(
        loading: () => const _MapView(exact: false),
        error: (e, _) => const _MapErrorState(exact: false),
        data: (cells) => _MapView(exact: false, cells: cells),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: mapLayer),
          // Botón de regreso (solo en la entrada pública por ruta propia).
          if (widget.showBack)
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
          // Selector de vista: mapa de calor ⇄ ubicaciones exactas (default
          // calor). Centrado arriba, entre el botón de regreso y el de "ⓘ"; el
          // FittedBox lo encoge en pantallas estrechas para no encimarse.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 64,
            right: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _MapModeToggle(
                      mode: _mode,
                      onChanged: (m) => setState(() => _mode = m),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Leyenda del calor (overlay, esquina inferior izquierda). Sirve a
          // ambos modos: los pines exactos usan la MISMA rampa de severidad.
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

/// Selector calor ⇄ ubicaciones exactas (CR-025). Es información **pública**: no
/// hay banner de uso interno ni advertencia de obfuscación.
class _MapModeToggle extends StatelessWidget {
  const _MapModeToggle({required this.mode, required this.onChanged});

  final MapMode mode;
  final ValueChanged<MapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map_mode_toggle'),
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      color: Theme.of(context).colorScheme.surface,
      child: SegmentedButton<MapMode>(
        segments: const [
          ButtonSegment<MapMode>(
            value: MapMode.heat,
            icon: Icon(Icons.blur_on),
            label: Text(Copy.mapModeHeat),
          ),
          ButtonSegment<MapMode>(
            value: MapMode.exact,
            icon: Icon(Icons.place_outlined),
            label: Text(Copy.mapModeExact),
          ),
        ],
        selected: {mode},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

/// El `FlutterMap` con OSM + la capa activa (celdas de calor o pines exactos).
/// Se separa para reusarlo en los estados de carga (mapa vacío) y con datos.
class _MapView extends StatelessWidget {
  const _MapView({
    required this.exact,
    this.cells = const [],
    this.trees = const [],
  });

  /// true = modo ubicaciones exactas (pines por árbol); false = mapa de calor.
  final bool exact;
  final List<GridCell> cells;
  final List<PublicObservation> trees;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      key: const Key('heat_map'),
      options: const MapOptions(
        initialCenter: kAguascalientesCenter,
        initialZoom: kAguascalientesZoom,
        // Sin rotación: mantiene el norte arriba (lectura simple del mapa).
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
        // Modo calor: un marker (celda) por agregado.
        if (!exact)
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
        // Modo exacto: un pin por árbol en su coordenada real (CR-025).
        if (exact)
          MarkerLayer(
            key: const Key('exact_trees'),
            markers: [
              for (final t in trees)
                Marker(
                  point: LatLng(t.lat, t.lon),
                  width: 34,
                  height: 34,
                  child: _TreeMarker(obs: t),
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

/// Popup de una celda del mapa de calor: muestra `n`, paxtle, cúscuta y la
/// mezcla de severidad (promedio). Es el agregado de la celda, no un árbol.
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
                    Copy.mapCellTitle,
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
                'experta.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Un árbol en el modo de ubicaciones exactas (CR-025): pin coloreado por
/// severidad (misma rampa que el calor), tappable → popup del árbol.
class _TreeMarker extends StatelessWidget {
  const _TreeMarker({required this.obs});

  final PublicObservation obs;

  @override
  Widget build(BuildContext context) {
    final color = heatColor(context, nivelIndex(obs.nivelG4).toDouble());
    return GestureDetector(
      key: Key('tree_${obs.lat}_${obs.lon}'),
      onTap: () => _showTreePopup(context, obs),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Contorno blanco para contraste sobre el mapa.
          const Icon(Icons.location_on, size: 34, color: Colors.white),
          Icon(Icons.location_on, size: 26, color: color),
        ],
      ),
    );
  }
}

/// Popup de un árbol (modo exacto, CR-025): severidad, paxtle, cúscuta, fecha y
/// coordenadas con 6 decimales. NO muestra el `handle` (dato público sin autor).
void _showTreePopup(BuildContext context, PublicObservation obs) {
  final level = nivelIndex(obs.nivelG4);
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Padding(
          key: const Key('tree_popup'),
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
                      color: heatColor(ctx, level.toDouble()),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Copy.mapTreeTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PopupRow(
                label: Copy.mapTreeNivel,
                value: Copy.mapLegendLevels[level],
              ),
              _PopupRow(
                label: Copy.mapTreePaxtle,
                value: obs.flagDanio ? 'Sí' : 'No',
              ),
              _PopupRow(
                label: Copy.mapTreeCuscuta,
                value: obs.flagCuscuta ? 'Sí' : 'No',
              ),
              _PopupRow(
                label: Copy.mapTreeFecha,
                value: _treeFecha(obs.capturedAt),
              ),
              _PopupRow(
                label: Copy.mapTreeUbicacion,
                value: '${obs.lat.toStringAsFixed(6)}, '
                    '${obs.lon.toStringAsFixed(6)}',
              ),
              const SizedBox(height: 12),
              Text(
                'Severidad autodeclarada por quien observa; sin validación '
                'experta.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Fecha corta local dd/mm/aaaa (mismo formato que "Mi participación").
String _treeFecha(DateTime d) {
  final local = d.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return '$dd/$mm/${local.year}';
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

/// Botón "ⓘ": abre el panel con el disclaimer (gate #1) + los indicadores
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
  const _MapErrorState({required this.exact});

  final bool exact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _MapView(exact: exact)),
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
