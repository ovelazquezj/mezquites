import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/models.dart';
import '../../services/capture_service.dart';
import '../copy.dart';
import '../widgets/common.dart';
import '../widgets/g4_selector.dart';

/// Formulario de las 8 etiquetas de captura (Q2/Q3), separado de la cámara para
/// poder probarlo sin hardware. Recibe la captura (imagen + EXIF de lat/lon/
/// timestamp REALES, gate #4) y recoge las 5 etiquetas autodeclaradas:
///   nivel G4, flag cúscuta, flag daño, tamaño, contexto.
///
/// Gate #9: NO muestra estado de validación individual.
/// Gate #8: nivel y flags son AUTODECLARADOS (la UI no afirma validación).
class ObservationForm extends StatefulWidget {
  const ObservationForm({
    super.key,
    required this.capture,
    required this.onSubmit,
  });

  final CaptureResult capture;

  /// Fire-and-forget: el caller encola y NO bloquea (Q5.A).
  final void Function(ObservationDraft draft) onSubmit;

  @override
  State<ObservationForm> createState() => _ObservationFormState();
}

class _ObservationFormState extends State<ObservationForm> {
  NivelG4? _nivel;
  bool _cuscuta = false;
  bool _danio = false;
  Tamanio? _tamanio;
  Contexto? _contexto;

  bool get _complete =>
      _nivel != null && _tamanio != null && _contexto != null;

  void _submit() {
    if (!_complete) return;
    final draft = ObservationDraft(
      lat: widget.capture.lat,
      lon: widget.capture.lon,
      capturedAt: widget.capture.capturedAt,
      nivelG4: _nivel!,
      flagCuscuta: _cuscuta,
      flagDanio: _danio,
      tamanio: _tamanio!,
      contexto: _contexto!,
      imagePath: widget.capture.imagePath,
      imageBytes: widget.capture.imageBytes,
    );
    widget.onSubmit(draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('observation_form'),
      padding: const EdgeInsets.all(16),
      children: [
        // 1-3: EXIF capturado (cámara nativa). Visible como confirmación.
        SectionCard(
          title: 'Ubicación y momento',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lat ${widget.capture.lat.toStringAsFixed(5)}, '
                'Lon ${widget.capture.lon.toStringAsFixed(5)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                widget.capture.capturedAt.toLocal().toString(),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // 4: nivel G4 (4 opciones + rango %, autodeclarado).
        SectionCard(
          child: G4Selector(
            value: _nivel,
            onChanged: (v) => setState(() => _nivel = v),
          ),
        ),

        // 5-6: dos toggles binarios INDEPENDIENTES.
        SectionCard(
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('toggle_cuscuta'),
                value: _cuscuta,
                onChanged: (v) => setState(() => _cuscuta = v),
                title: const Text(Copy.captureCuscutaLabel),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                key: const Key('toggle_danio'),
                value: _danio,
                onChanged: (v) => setState(() => _danio = v),
                title: const Text(Copy.captureDanioLabel),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),

        // 7: tamaño (dropdown obligatorio).
        SectionCard(
          child: DropdownButtonFormField<Tamanio>(
            key: const Key('dropdown_tamanio'),
            value: _tamanio,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: Copy.captureTamanioLabel,
            ),
            items: Tamanio.values
                .map(
                  (t) => DropdownMenuItem<Tamanio>(
                    value: t,
                    child: Text(t.label),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _tamanio = v),
          ),
        ),

        // 8: contexto (dropdown obligatorio).
        SectionCard(
          child: DropdownButtonFormField<Contexto>(
            key: const Key('dropdown_contexto'),
            value: _contexto,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: Copy.captureContextoLabel,
            ),
            items: Contexto.values
                .map(
                  (c) => DropdownMenuItem<Contexto>(
                    value: c,
                    child: Text(c.label),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _contexto = v),
          ),
        ),

        const SizedBox(height: 8),
        FilledButton(
          key: const Key('submit_observation'),
          onPressed: _complete ? _submit : null,
          child: const Text(Copy.captureSubmit),
        ),
      ],
    );
  }
}
