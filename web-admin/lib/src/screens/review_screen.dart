import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/paged_table.dart';

/// Sección REVISIÓN (CR-001): cola de observaciones + detalle con visor de imagen
/// y botones Confirmar/Retirar. Acceso para `evaluador`/`administrador` (emiten
/// veredicto) y `analista` (solo lectura: ve la cola pero sin botones de veredicto).
///
/// La vista de revisión muestra estado/municipio (no lat/lon) en los campos; la
/// imagen la sirve el backend con su EXIF (CR-025: el saneo de GPS quedó ocioso).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  String? _estadoRevisionFilter;
  late Future<List<ReviewQueueItem>> _future;

  // CR-033: la paginación vive AQUÍ y no en el PagedTable. Al recargar la cola
  // el FutureBuilder pasa por el spinner y destruye la tabla con su estado
  // interno; si la página y las filas/página no sobreviven aquí, volver de un
  // detalle regresaba al revisor a la página 1 con 10 filas.
  int _page = 0;
  int _perPage = 10;

  static const _filters = <String, String>{
    'aceptada': 'Aceptadas',
    'confirmada': 'Confirmadas',
    'rechazada': 'Retiradas',
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    // CR-033: reviewQueueAll pagina contra el backend hasta traer TODA la
    // cola; el limit fijo de 200 escondía el resto de los registros.
    _future = ref
        .read(apiClientProvider)
        .reviewQueueAll(estadoRevision: _estadoRevisionFilter);
  }

  Future<void> _openDetail(ReviewQueueItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ReviewDetailDialog(observationId: item.observationId),
    );
    setState(_reload); // refresca la cola tras un posible veredicto
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.navReview, style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(Copy.reviewIntro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          Copy.reviewLocationNote,
          key: const Key('review-location-note'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('review-filter-todas'),
              label: const Text('Todas'),
              selected: _estadoRevisionFilter == null,
              onSelected: (_) => setState(() {
                _estadoRevisionFilter = null;
                _page = 0; // cambiar de filtro sí reinicia la página
                _reload();
              }),
            ),
            for (final entry in _filters.entries)
              ChoiceChip(
                key: Key('review-filter-${entry.key}'),
                label: Text(entry.value),
                selected: _estadoRevisionFilter == entry.key,
                onSelected: (_) => setState(() {
                  _estadoRevisionFilter = entry.key;
                  _page = 0;
                  _reload();
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<ReviewQueueItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return const Text('No se pudo cargar la cola. Inténtalo de nuevo.');
            }
            final rows = snap.data ?? const <ReviewQueueItem>[];
            if (rows.isEmpty) {
              return Text(Copy.reviewQueueEmpty, key: const Key('review-empty'));
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PagedTable<ReviewQueueItem>(
                  items: rows,
                  page: _page,
                  perPage: _perPage,
                  onPageChanged: (p) => setState(() => _page = p),
                  onPerPageChanged: (v) => setState(() => _perPage = v),
                  columns: const [
                    DataColumn(label: Text('Usuario')),
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Estado de revisión')),
                    DataColumn(label: Text('Nivel de paxtle')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Municipio')),
                    DataColumn(label: Text('')),
                  ],
                  rowBuilder: (o) => DataRow(
                    key: ValueKey('review-row-${o.observationId}'),
                    onSelectChanged: (_) => _openDetail(o),
                    cells: [
                      DataCell(Text(o.handle)),
                      DataCell(Text(_fmtDate(o.capturedAt))),
                      DataCell(Text(Copy.estadoRevision(o.estadoRevision))),
                      DataCell(Text(Copy.nivelG4(o.nivelG4))),
                      DataCell(Text(o.estado ?? '—')),
                      DataCell(Text(o.municipio ?? '—')),
                      DataCell(
                        TextButton(
                          key: Key('review-open-${o.observationId}'),
                          onPressed: () => _openDetail(o),
                          child: const Text(Copy.reviewOpenDetail),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Detalle de una observación con visor de imagen + veredicto (Confirmar/Retirar).
/// `analista` ve el detalle e historial pero NO los botones de veredicto.
class ReviewDetailDialog extends ConsumerStatefulWidget {
  const ReviewDetailDialog({super.key, required this.observationId});

  final String observationId;

  @override
  ConsumerState<ReviewDetailDialog> createState() => _ReviewDetailDialogState();
}

class _ReviewDetailDialogState extends ConsumerState<ReviewDetailDialog> {
  late Future<ReviewObservationDetail> _future;
  final _notaCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).reviewDetail(widget.observationId);
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _emit(String veredicto) async {
    setState(() => _busy = true);
    try {
      final resp = await ref.read(apiClientProvider).submitVerdict(
            observationId: widget.observationId,
            veredicto: veredicto,
            nota: _notaCtrl.text.trim(),
          );
      if (!mounted) return;
      // CR-029: el backend no registra un veredicto igual al estado actual. Decirlo evita que el
      // revisor crea que emitió uno nuevo (así se colaron 3 filas repetidas en el log).
      final sinCambio = resp['sin_cambio'] == true;
      final msg = sinCambio
          ? (resp['message'] as String? ?? Copy.reviewNoChange)
          : switch (veredicto) {
              'rechazada' => Copy.reviewRejected,
              'aceptada' => Copy.reviewReopened,
              _ => Copy.reviewConfirmed,
            };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.statusCode == 403
                ? 'Tu cuenta no puede emitir veredictos (solo consulta).'
                : 'No se pudo guardar el veredicto. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canVerdict = ref.watch(sessionProvider).canEmitVerdict;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: FutureBuilder<ReviewObservationDetail>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 240, child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError || snap.data == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No se pudo cargar el detalle.'),
              );
            }
            final d = snap.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Observación de ${d.handle}',
                            style: theme.textTheme.displayLarge),
                      ),
                      IconButton(
                        key: const Key('review-detail-close'),
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Visor de imagen (servida con EXIF GPS saneado, gate #5).
                  // CR-010 #4: Flutter Web IGNORA los headers de Image.network,
                  // así que la imagen da 401. Se descargan los bytes con el
                  // header Authorization (http client autenticado) y se pintan
                  // con Image.memory.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _ReviewImage(observationId: widget.observationId),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    Chip(label: Text('Nivel: ${Copy.nivelG4(d.nivelG4)}')),
                    Chip(
                        label: Text(
                            'Revisión: ${Copy.estadoRevision(d.estadoRevision)}')),
                    if (d.flagCuscuta) const Chip(label: Text('Cúscuta')),
                    if (d.flagDanio) const Chip(label: Text('Signos de daño')),
                    Chip(label: Text('Estado: ${d.estado ?? '—'}')),
                    Chip(label: Text('Municipio: ${d.municipio ?? '—'}')),
                  ]),
                  const SizedBox(height: 16),
                  Text(Copy.reviewHistoryTitle, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (d.historial.isEmpty)
                    Text(Copy.reviewNoHistory, style: theme.textTheme.bodySmall)
                  else
                    for (final h in d.historial)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${Copy.estadoRevision(h.veredicto)} · ${h.reviewerHandle}'
                          '${h.nota == null || h.nota!.isEmpty ? '' : ' — ${h.nota}'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  if (canVerdict) ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('review-nota'),
                      controller: _notaCtrl,
                      decoration:
                          const InputDecoration(labelText: Copy.reviewNoteLabel),
                    ),
                    const SizedBox(height: 12),
                    // CR-029: el veredicto que YA es el estado actual va deshabilitado. Antes los
                    // tres estaban siempre activos y volver a pulsar el vigente añadía una fila
                    // redundante al log de revisión.
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('review-confirm'),
                          onPressed: _busy || d.estadoRevision == 'confirmada'
                              ? null
                              : () => _emit('confirmada'),
                          icon: const Icon(Icons.check),
                          label: const Text(Copy.reviewConfirm),
                        ),
                        OutlinedButton.icon(
                          key: const Key('review-reject'),
                          onPressed: _busy || d.estadoRevision == 'rechazada'
                              ? null
                              : () => _emit('rechazada'),
                          icon: const Icon(Icons.block),
                          label: const Text(Copy.reviewReject),
                        ),
                        // CR-010 #4: tercer veredicto que regresa al estado por
                        // defecto (aceptada). El backend ya lo acepta.
                        TextButton.icon(
                          key: const Key('review-reopen'),
                          onPressed: _busy || d.estadoRevision == 'aceptada'
                              ? null
                              : () => _emit('aceptada'),
                          icon: const Icon(Icons.undo),
                          label: const Text(Copy.reviewReopen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Copy.reviewCurrentState(Copy.estadoRevision(d.estadoRevision)),
                      key: const Key('review-current-state'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Visor de imagen de revisión (CR-010 #4). Descarga los bytes con el header
/// Authorization vía el [ApiClient] (Flutter Web ignora los headers de
/// `Image.network`) y los pinta con `Image.memory`. El backend sirve la imagen
/// con el GPS del EXIF saneado (gate #5).
class _ReviewImage extends ConsumerStatefulWidget {
  const _ReviewImage({required this.observationId});

  final String observationId;

  @override
  ConsumerState<_ReviewImage> createState() => _ReviewImageState();
}

class _ReviewImageState extends ConsumerState<_ReviewImage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Uint8List> _load() async {
    final bytes = await ref
        .read(apiClientProvider)
        .reviewImageBytes(widget.observationId);
    return Uint8List.fromList(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            height: 280,
            alignment: Alignment.center,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const CircularProgressIndicator(),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Container(
            key: const Key('review-image-error'),
            height: 280,
            alignment: Alignment.center,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Text(Copy.reviewImageError),
          );
        }
        final bytes = snap.data!;
        // CR-029: la miniatura abre el visor con zoom. Los bytes en resolución completa YA están
        // aquí (se descargaron con el header de autorización), así que ampliar no pide nada al
        // servidor ni toca el RBAC del endpoint de imagen.
        return Semantics(
          button: true,
          label: Copy.reviewZoomHint,
          child: Tooltip(
            message: Copy.reviewZoomHint,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                key: const Key('review-image-open-zoom'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ImageZoomDialog(bytes: bytes),
                ),
                // Alto fijo y ancho completo: el área clicable no depende de que la imagen ya esté
                // decodificada, así que no cambia de tamaño ni se "escapa" mientras carga.
                child: SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Positioned.fill(
                        child: Image.memory(
                          bytes,
                          key: const Key('review-image'),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            alignment: Alignment.center,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Text(Copy.reviewImageError),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.zoom_in, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Visor a pantalla completa con zoom (CR-029), para juzgar detalle fino al revisar.
///
/// Arrastrar para desplazar, doble clic para acercar/alejar y botones +/−/restablecer. Los botones
/// son deliberados: el zoom por rueda del ratón se comporta distinto según navegador y trackpad, y
/// el revisor no debería depender de eso. Trabaja sobre los bytes ya descargados: sin peticiones.
class _ImageZoomDialog extends StatefulWidget {
  const _ImageZoomDialog({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImageZoomDialog> createState() => _ImageZoomDialogState();
}

class _ImageZoomDialogState extends State<_ImageZoomDialog> {
  static const double _min = 1.0;
  static const double _max = 8.0;

  final TransformationController _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  double get _escala => _tc.value.getMaxScaleOnAxis();

  /// Fija la escala desde el centro. Reencuadra a propósito: tras un +/− el revisor espera ver el
  /// centro de la foto, no seguir perdido donde estaba el desplazamiento anterior.
  void _fijarEscala(double objetivo) {
    setState(() {
      _tc.value = Matrix4.identity()..scale(objetivo.clamp(_min, _max));
    });
  }

  void _alternarDobleClic() =>
      _fijarEscala(_escala > _min + 0.01 ? _min : 2.5);

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTap: _alternarDobleClic,
              child: InteractiveViewer(
                key: const Key('review-image-zoom'),
                transformationController: _tc,
                minScale: _min,
                maxScale: _max,
                child: Center(
                  child: Image.memory(widget.bytes, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  key: const Key('review-zoom-out'),
                  tooltip: 'Alejar',
                  color: Colors.white,
                  onPressed: () => _fijarEscala(_escala / 1.5),
                  icon: const Icon(Icons.zoom_out),
                ),
                IconButton(
                  key: const Key('review-zoom-in'),
                  tooltip: 'Acercar',
                  color: Colors.white,
                  onPressed: () => _fijarEscala(_escala * 1.5),
                  icon: const Icon(Icons.zoom_in),
                ),
                IconButton(
                  key: const Key('review-zoom-reset'),
                  tooltip: 'Restablecer',
                  color: Colors.white,
                  onPressed: () => _fijarEscala(_min),
                  icon: const Icon(Icons.center_focus_strong),
                ),
                IconButton(
                  key: const Key('review-zoom-close'),
                  tooltip: 'Cerrar',
                  color: Colors.white,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Text(
              Copy.reviewZoomControls,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
