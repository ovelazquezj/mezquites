import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/capture_service.dart';

/// Pinta la foto capturada — rama **NATIVA**: la cámara deja el JPEG en disco.
///
/// Prefiere los bytes si los hay (una captura nativa podría traerlos) y cae a la ruta.
/// `Image.file` resuelve la lectura del archivo por su cuenta, así que no hace falta
/// ni `FutureBuilder` ni leer el archivo de forma síncrona en el hilo de la UI.
Widget imagenDeCaptura(
  CaptureResult captura, {
  required BoxFit fit,
  required ImageErrorWidgetBuilder errorBuilder,
  Key? key,
}) {
  final bytes = captura.imageBytes;
  if (bytes != null) {
    return Image.memory(bytes, key: key, fit: fit, errorBuilder: errorBuilder);
  }
  return Image.file(
    File(captura.imagePath!),
    key: key,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}
