import 'package:flutter/material.dart';

import '../../services/capture_service.dart';
import '../copy.dart';
import 'captura_imagen.dart';

/// Miniatura de la foto recién tomada, con lupa y "Repetir foto" (CR-037).
///
/// Cierra el hueco que destapó la revisión en campo: el voluntario **nunca veía** la
/// fotografía que acababa de tomar —ni al capturar los datos ni después—, así que el
/// primer humano en mirarla era quien revisaba, con la observación ya enviada. Motivos
/// de rechazo evidentes ("solo tronco", desenfoque, encuadre) llegaban hasta la consola
/// sin que nadie pudiera atajarlos.
///
/// Dos decisiones de diseño que NO son cosméticas:
///
/// 1. **Alto fijo** en el recuadro. Un `Image` sin alto explícito toma sus dimensiones
///    intrínsecas, que valen **0 hasta que la imagen se decodifica**: queda en el árbol y
///    es invisible. Este proyecto ya se tropezó dos veces con eso (CR-029, la foto de
///    revisión de la consola; y el fix de CR-032, las ilustraciones de Aprender, que
///    medían `Size(1048, 0)`). El recuadro mide igual con la imagen cargada, cargando o
///    rota, y la prueba lo afirma **midiendo**, no suponiendo.
///
/// 2. **`BoxFit.contain`, nunca `cover`.** Recortar una foto que el voluntario está a
///    punto de juzgar puede esconder justo lo que la invalida, y la proporción del cuadro
///    (apaisado o vertical) solo se lee de un vistazo si se respeta.
class CapturaPreview extends StatelessWidget {
  const CapturaPreview({
    super.key,
    required this.captura,
    this.onRepetir,
  });

  final CaptureResult captura;

  /// Vuelve a la cámara conservando las etiquetas ya elegidas. `null` oculta el botón
  /// (el formulario se puede montar suelto —p. ej. en pruebas— y la foto se sigue viendo).
  final VoidCallback? onRepetir;

  /// Lado del recuadro de la miniatura. Pequeño a propósito: es un vistazo de control, y
  /// el juicio fino se hace en el visor ampliado.
  static const double ladoMiniatura = 112;

  Widget _error(BuildContext context, Object error, StackTrace? stack) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8),
      child: Text(
        Copy.captureFotoError,
        key: const Key('captura_foto_error'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  void _ampliar(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _VisorFotoCaptura(captura: captura),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: Copy.captureFotoAmpliar,
          child: Tooltip(
            message: Copy.captureFotoAmpliar,
            child: GestureDetector(
              key: const Key('captura_foto_ampliar'),
              onTap: () => _ampliar(context),
              // Alto y ancho fijos: el área que se toca no depende de que la imagen ya
              // esté decodificada, así que no baila ni se "escapa" mientras carga.
              child: SizedBox(
                key: const Key('captura_foto_miniatura'),
                width: ladoMiniatura,
                height: ladoMiniatura,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Positioned.fill(
                          child: imagenDeCaptura(
                            captura,
                            key: const Key('captura_foto_imagen'),
                            fit: BoxFit.contain,
                            errorBuilder: _error,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Copy.captureFotoAmpliar, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              if (onRepetir != null)
                OutlinedButton.icon(
                  key: const Key('captura_foto_repetir'),
                  onPressed: onRepetir,
                  // Cámara, NUNCA galería (gate #4): repetir reabre el mismo panel de
                  // captura por el que se llegó hasta aquí.
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text(Copy.captureFotoRepetir),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Visor a pantalla completa de la foto recién capturada (CR-037).
///
/// Mismo patrón que el visor de revisión de la consola (CR-029): trabaja sobre la imagen
/// que YA está en el dispositivo, así que ampliar no pide nada a la red y funciona igual
/// capturando sin señal (gate #3). Aquí el gesto natural es el pellizco, no la rueda del
/// ratón, así que no se replican los botones +/− que la consola sí necesita.
class _VisorFotoCaptura extends StatefulWidget {
  const _VisorFotoCaptura({required this.captura});

  final CaptureResult captura;

  @override
  State<_VisorFotoCaptura> createState() => _VisorFotoCapturaState();
}

class _VisorFotoCapturaState extends State<_VisorFotoCaptura> {
  static const double _min = 1.0;
  static const double _max = 8.0;

  final TransformationController _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  double get _escala => _tc.value.getMaxScaleOnAxis();

  /// Doble toque: acerca desde el centro o vuelve al encuadre completo. Reencuadrar es
  /// deliberado — tras alejar, el voluntario espera ver la foto entera otra vez.
  void _alternarDobleToque() {
    setState(() {
      _tc.value = Matrix4.identity()..scale(_escala > _min + 0.01 ? _min : 2.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTap: _alternarDobleToque,
              child: InteractiveViewer(
                key: const Key('captura_foto_visor'),
                transformationController: _tc,
                minScale: _min,
                maxScale: _max,
                child: Center(
                  child: imagenDeCaptura(
                    widget.captura,
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, __) => const Text(
                      Copy.captureFotoError,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              key: const Key('captura_foto_visor_cerrar'),
              tooltip: Copy.captureFotoCerrar,
              color: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
