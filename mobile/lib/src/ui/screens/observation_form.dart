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
/// Firma del resolvedor de lugar. Se inyecta (en vez de leer un provider aquí) para que el
/// formulario siga siendo probable sin red ni `ProviderScope`, y para que un fallo de red sea
/// simplemente `null` en lugar de una excepción que rompa la captura.
typedef ResolverLugar = Future<GeoLugar?> Function(double lat, double lon);

class ObservationForm extends StatefulWidget {
  const ObservationForm({
    super.key,
    this.resolverLugar,
    required this.capture,
    required this.onSubmit,
  });

  final CaptureResult capture;

  /// Fire-and-forget: el caller encola y NO bloquea (Q5.A).
  final void Function(ObservationDraft draft) onSubmit;

  /// CR-036: resuelve el nombre del lugar SOLO para mostrarlo. `null` ⇒ la tarjeta enseña
  /// únicamente las coordenadas. Se inyecta (en vez de leer un provider aquí) para que el
  /// formulario siga siendo probable sin red ni `ProviderScope`.
  final ResolverLugar? resolverLugar;

  @override
  State<ObservationForm> createState() => _ObservationFormState();
}

class _ObservationFormState extends State<ObservationForm> {
  NivelG4? _nivel;
  bool _cuscuta = false;
  bool _danio = false;
  Tamanio? _tamanio;
  Contexto? _contexto;

  // CR-036: el voluntario ya NO declara estado ni municipio — los deriva el servidor de las
  // coordenadas. Aquí solo se PIDE el nombre del lugar para mostrárselo como confirmación. Si no
  // hay red (lo normal en campo) queda en null y la tarjeta enseña las coordenadas: cero taps en
  // ambos casos, y la captura offline (CR-031) no depende de esta llamada.
  GeoLugar? _lugar;
  bool _resolviendo = false;

  @override
  void initState() {
    super.initState();
    final resolver = widget.resolverLugar;
    if (resolver == null) return;
    _resolviendo = true;
    resolver(widget.capture.lat, widget.capture.lon).then((lugar) {
      if (!mounted) return;
      setState(() {
        _lugar = lugar;
        _resolviendo = false;
      });
    });
  }

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
      gpsAccuracyM: widget.capture.gpsAccuracyM,
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
          title: Copy.captureUbicacionTitulo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CR-036: el lugar lo decide el servidor. Se muestra en grande porque es lo único
              // que un voluntario puede verificar de un vistazo; las coordenadas van debajo, en
              // pequeño, como respaldo verificable. Nunca se le pide que lo seleccione.
              if (_lugar?.resuelto ?? false)
                Text(
                  _lugar!.etiqueta,
                  key: const Key('captura_lugar'),
                  style: theme.textTheme.titleMedium,
                )
              else if (_resolviendo)
                Text(
                  Copy.captureUbicacionResolviendo,
                  key: const Key('captura_lugar_resolviendo'),
                  style: theme.textTheme.bodySmall,
                )
              else
                Text(
                  Copy.captureUbicacionSinResolver,
                  key: const Key('captura_lugar_sin_resolver'),
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: 4),
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
