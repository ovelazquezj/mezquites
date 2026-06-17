import 'download_stub.dart'
    if (dart.library.js_interop) 'download_web.dart' as impl;

/// Descarga un archivo en el navegador (CR-010 #3). En web crea un Blob y dispara
/// la descarga; en la VM (pruebas) es un no-op. El llamador ya obtuvo los bytes
/// por fetch autenticado (el header Authorization no viaja en `<a download>`).
void downloadBytes(List<int> bytes, String filename, {String mime = 'text/csv'}) =>
    impl.downloadBytes(bytes, filename, mime: mime);
