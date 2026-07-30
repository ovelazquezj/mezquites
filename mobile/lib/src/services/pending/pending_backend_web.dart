import 'dart:js_interop';
import 'dart:typed_data';

// `idb_browser.dart` re-exporta el API de `idb.dart`, así que basta este import.
import 'package:idb_shim/idb_browser.dart';
import 'package:web/web.dart' as web;

import 'pending_store.dart';

/// Persistencia de la cola en **navegador / PWA** — el caso de PRODUCCIÓN (CR-031).
///
/// Todo vive en **IndexedDB**, en dos almacenes:
///
/// - `blobs`: un `Uint8List` por captura (binario nativo, sin base64).
/// - `meta`: un único registro con el índice serializado a JSON.
///
/// Por qué no `shared_preferences` en web: se traduce a `localStorage`, que topa
/// alrededor de **5 MB** y solo guarda texto — habría que pasar las fotos a base64
/// (+33 %) y unas pocas capturas llenarían la cuota. Con la mediana medida de
/// 200 KB por foto (§11 del CR), IndexedDB aguanta cientos sin acercarse a nada.
///
/// El índice se guarda como **cadena JSON** y no como objeto: así el formato es
/// idéntico al del backend nativo (misma función [encodeIndex]) y no depende de
/// cómo cada navegador convierta estructuras Dart anidadas.
class WebPendingBackend implements PendingStorageBackend {
  static const _dbName = 'mezquite_pendientes';
  static const _storeBlobs = 'blobs';
  static const _storeMeta = 'meta';
  static const _keyIndex = 'index';

  Database? _db;
  bool _persistente = false;

  @override
  bool get persistente => _persistente;

  @override
  Future<void> init() async {
    _db = await idbFactoryBrowser.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (VersionChangeEvent e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_storeBlobs)) {
          db.createObjectStore(_storeBlobs);
        }
        if (!db.objectStoreNames.contains(_storeMeta)) {
          db.createObjectStore(_storeMeta);
        }
      },
    );
    _persistente = await _pedirPersistencia();
  }

  /// Decisión **D4**: pedimos que el navegador marque este almacén como
  /// persistente. Sin esto, IndexedDB es "mejor esfuerzo" y el navegador puede
  /// **desalojarlo** bajo presión de almacenamiento — es decir, borrar capturas de
  /// campo sin avisar, que es exactamente el daño que este CR viene a cerrar.
  ///
  /// Si el navegador lo niega (o no soporta la API), NO se falla: la app sigue
  /// funcionando y el resultado viaja en el diagnóstico para que se pueda saber.
  Future<bool> _pedirPersistencia() async {
    try {
      final storage = web.window.navigator.storage;
      final yaEs = (await storage.persisted().toDart).toDart;
      if (yaEs) return true;
      return (await storage.persist().toDart).toDart;
    } catch (_) {
      return false;
    }
  }

  Database get _requireDb {
    final db = _db;
    if (db == null) {
      throw StateError('WebPendingBackend.init() no se ha llamado');
    }
    return db;
  }

  @override
  Future<List<Map<String, dynamic>>> readIndex() async {
    final txn = _requireDb.transaction(_storeMeta, idbModeReadOnly);
    final raw = await txn.objectStore(_storeMeta).getObject(_keyIndex);
    await txn.completed;
    return decodeIndex(raw is String ? raw : null);
  }

  @override
  Future<void> writeIndex(List<Map<String, dynamic>> index) async {
    final txn = _requireDb.transaction(_storeMeta, idbModeReadWrite);
    await txn.objectStore(_storeMeta).put(encodeIndex(index), _keyIndex);
    await txn.completed;
  }

  @override
  Future<void> putBlob(String id, Uint8List bytes) async {
    final txn = _requireDb.transaction(_storeBlobs, idbModeReadWrite);
    await txn.objectStore(_storeBlobs).put(bytes, id);
    await txn.completed;
  }

  @override
  Future<Uint8List?> getBlob(String id) async {
    final txn = _requireDb.transaction(_storeBlobs, idbModeReadOnly);
    final raw = await txn.objectStore(_storeBlobs).getObject(id);
    await txn.completed;
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    // Algunos navegadores devuelven la lista sin el tipo exacto.
    if (raw is List) return Uint8List.fromList(raw.cast<int>());
    return null;
  }

  @override
  Future<void> deleteBlob(String id) async {
    final txn = _requireDb.transaction(_storeBlobs, idbModeReadWrite);
    await txn.objectStore(_storeBlobs).delete(id);
    await txn.completed;
  }
}

/// Constructor que resuelve el import condicional (ver `pending_backend.dart`).
PendingStorageBackend crearPendingBackend() => WebPendingBackend();
