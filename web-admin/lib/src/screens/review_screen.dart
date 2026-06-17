import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';

/// Sección REVISIÓN (CR-001): cola de observaciones + detalle con visor de imagen
/// y botones Confirmar/Retirar. Acceso para `evaluador`/`administrador` (emiten
/// veredicto) y `analista` (solo lectura: ve la cola pero sin botones de veredicto).
///
/// Gate #5: nunca muestra coords exactas (solo estado/municipio); la imagen la
/// sirve el backend con el GPS del EXIF saneado.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  String? _estadoRevisionFilter;
  late Future<List<ReviewQueueItem>> _future;

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
    _future = ref
        .read(apiClientProvider)
        .reviewQueue(estadoRevision: _estadoRevisionFilter, limit: 200);
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Usuario')),
                      DataColumn(label: Text('Fecha')),
                      DataColumn(label: Text('Estado de revisión')),
                      DataColumn(label: Text('Nivel de paxtle')),
                      DataColumn(label: Text('Estado')),
                      DataColumn(label: Text('Municipio')),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final o in rows)
                        DataRow(
                          key: ValueKey('review-row-${o.observationId}'),
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
      await ref.read(apiClientProvider).submitVerdict(
            observationId: widget.observationId,
            veredicto: veredicto,
            nota: _notaCtrl.text.trim(),
          );
      if (!mounted) return;
      final msg = switch (veredicto) {
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          key: const Key('review-confirm'),
                          onPressed: _busy ? null : () => _emit('confirmada'),
                          icon: const Icon(Icons.check),
                          label: const Text(Copy.reviewConfirm),
                        ),
                        OutlinedButton.icon(
                          key: const Key('review-reject'),
                          onPressed: _busy ? null : () => _emit('rechazada'),
                          icon: const Icon(Icons.block),
                          label: const Text(Copy.reviewReject),
                        ),
                        // CR-010 #4: tercer veredicto que regresa al estado por
                        // defecto (aceptada). El backend ya lo acepta.
                        TextButton.icon(
                          key: const Key('review-reopen'),
                          onPressed: _busy ? null : () => _emit('aceptada'),
                          icon: const Icon(Icons.undo),
                          label: const Text(Copy.reviewReopen),
                        ),
                      ],
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
        return Image.memory(
          snap.data!,
          key: const Key('review-image'),
          height: 280,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            height: 280,
            alignment: Alignment.center,
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Text(Copy.reviewImageError),
          ),
        );
      },
    );
  }
}
