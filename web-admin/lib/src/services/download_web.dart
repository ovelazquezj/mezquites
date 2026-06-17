import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Implementación web: crea un Blob con los bytes y dispara la descarga vía un
/// `<a download>` con un Object URL temporal (CR-010 #3).
void downloadBytes(List<int> bytes, String filename, {String mime = 'text/csv'}) {
  final data = Uint8List.fromList(bytes);
  final parts = [data.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
