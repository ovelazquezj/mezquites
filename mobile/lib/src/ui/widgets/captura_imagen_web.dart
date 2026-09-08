import 'package:flutter/material.dart';

import '../../services/capture_service.dart';

/// Pinta la foto capturada — rama **WEB**: la cámara del navegador entrega bytes.
///
/// No usa `Image.file` (no hay `dart:io` en web). Si por lo que sea no hubiera bytes,
/// devuelve el mismo aviso de error que una imagen ilegible en vez de romper el
/// formulario: el voluntario debe poder seguir capturando (gate #3).
Widget imagenDeCaptura(
  CaptureResult captura, {
  required BoxFit fit,
  required ImageErrorWidgetBuilder errorBuilder,
  Key? key,
}) {
  final bytes = captura.imageBytes;
  if (bytes == null) {
    return Builder(
      key: key,
      builder: (context) => errorBuilder(
        context,
        StateError('captura web sin bytes de imagen'),
        StackTrace.current,
      ),
    );
  }
  return Image.memory(bytes, key: key, fit: fit, errorBuilder: errorBuilder);
}
