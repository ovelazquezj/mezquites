// Selector de plataforma del almacén de capturas pendientes (CR-031).
//
// - nativo (io): JPEG en el directorio privado de la app + índice en
//   shared_preferences (pending_backend_io.dart).
// - web / PWA: IndexedDB, bytes en binario (pending_backend_web.dart). Es el caso
//   de PRODUCCIÓN.
//
// El import condicional evita compilar dart:io en el build web y, al revés,
// idb_shim/package:web en el build nativo. Mismo idioma que `capture_pane.dart`.
//
// Ambos archivos exponen `crearPendingBackend()`; la lógica de la cola vive una
// sola vez en `PendingCaptureStore` (pending_store.dart), no aquí.
export 'pending_backend_io.dart'
    if (dart.library.html) 'pending_backend_web.dart';
