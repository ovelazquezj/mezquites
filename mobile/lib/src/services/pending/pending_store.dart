import 'dart:convert';
import 'dart:typed_data';

import 'pending_capture.dart';

/// Persistencia CRUDA de la cola de capturas (CR-031). Solo primitivas.
///
/// La lógica —orden, transiciones de estado, "nunca borrar solo"— vive en
/// [PendingCaptureStore] y **no** se duplica por plataforma. Esta costura existe
/// porque guardar bytes es lo único que difiere de verdad entre el navegador y el
/// móvil nativo, y porque así la parte con reglas queda cubierta por pruebas: la
/// implementación de IndexedDB (que es la de **producción**) no se puede ejercitar
/// en el runner de `flutter test`, que corre sobre la VM de Dart y no en un
/// navegador. Reduciéndola a cuatro métodos sin decisiones, lo que queda sin
/// cubrir es mínimo y evidente.
abstract class PendingStorageBackend {
  /// Abre el almacén. En web pide además almacenamiento persistente (decisión D4).
  Future<void> init();

  /// Índice completo (metadatos, sin imágenes). Lista vacía si no hay nada.
  Future<List<Map<String, dynamic>>> readIndex();

  /// Reemplaza el índice completo. Debe ser atómico en la medida de lo posible.
  Future<void> writeIndex(List<Map<String, dynamic>> index);

  Future<void> putBlob(String id, Uint8List bytes);
  Future<Uint8List?> getBlob(String id);
  Future<void> deleteBlob(String id);

  /// True si el navegador concedió almacenamiento persistente (D4). En nativo
  /// siempre true: el archivo vive en el área privada de la app.
  bool get persistente;
}

/// Backend en memoria: pruebas y último recurso si el almacén no abre.
///
/// Si esto se usa en producción la cola **no** sobrevive al cierre de la app, así
/// que [persistente] es false y quien lo consuma debe poder decirlo en el
/// diagnóstico. Es preferible a no capturar (gate #3).
class InMemoryPendingBackend implements PendingStorageBackend {
  final Map<String, Uint8List> _blobs = {};
  List<Map<String, dynamic>> _index = [];

  @override
  Future<void> init() async {}

  @override
  Future<List<Map<String, dynamic>>> readIndex() async =>
      _index.map((e) => Map<String, dynamic>.from(e)).toList();

  @override
  Future<void> writeIndex(List<Map<String, dynamic>> index) async {
    _index = index.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<void> putBlob(String id, Uint8List bytes) async {
    _blobs[id] = Uint8List.fromList(bytes);
  }

  @override
  Future<Uint8List?> getBlob(String id) async => _blobs[id];

  @override
  Future<void> deleteBlob(String id) async {
    _blobs.remove(id);
  }

  @override
  bool get persistente => false;

  /// Solo para pruebas: nº de imágenes realmente guardadas.
  int get blobsGuardados => _blobs.length;
}

/// Cola de capturas pendientes de subir, persistente en el dispositivo (CR-031).
///
/// Reglas que fija esta clase (y que las pruebas fijan sobre ella):
///
/// - **Nada se borra automáticamente** (decisión D1). [delete] solo se llama tras
///   una subida confirmada, y [clearAll] solo ante un 410 (cuenta eliminada, D6).
///   No hay purga por tiempo ni por número de intentos.
/// - **FIFO por hora de captura**, no por hora de guardado: lo que se capturó
///   primero se sube primero, aunque el índice se haya reescrito.
/// - **`subiendo` no sobrevive a un reinicio.** Si la app muere a media subida, ese
///   ítem quedaría marcado como "subiendo" para siempre y nadie lo reintentaría.
///   [init] lo devuelve a la cola. Es seguro: si la subida sí había llegado al
///   servidor, la idempotencia de W1 responde `ya_existia` y no duplica.
/// - **La imagen se escribe ANTES que el índice.** Un blob sin entrada en el
///   índice es basura recuperable; una entrada sin blob es una captura que la app
///   creerá que puede subir y no podrá.
class PendingCaptureStore {
  PendingCaptureStore(this._backend);

  final PendingStorageBackend _backend;

  bool get persistente => _backend.persistente;

  /// Abre el almacén y **rescata** las que quedaron en `subiendo`.
  Future<void> init() async {
    await _backend.init();
    final index = await _backend.readIndex();
    var cambio = false;
    final rescatadas = index.map((raw) {
      if (raw['state'] == PendingState.subiendo.wire) {
        cambio = true;
        return {...raw, 'state': PendingState.enCola.wire};
      }
      return raw;
    }).toList();
    if (cambio) await _backend.writeIndex(rescatadas);
  }

  /// Guarda una captura nueva con su imagen. Devuelve la pendiente almacenada.
  Future<PendingCapture> save(PendingCapture captura, Uint8List bytes) async {
    // Imagen primero: ver la nota de la clase sobre el orden.
    await _backend.putBlob(captura.id, bytes);
    final index = await _backend.readIndex();
    // Idempotente también en local: guardar dos veces la misma captura no la
    // duplica en la cola (podría pasar con un doble toque en "Registrar").
    index.removeWhere((e) => e['id'] == captura.id);
    index.add(captura.toJson());
    await _backend.writeIndex(index);
    return captura;
  }

  /// Todas las pendientes, **en orden de captura** (la más antigua primero).
  Future<List<PendingCapture>> list() async {
    final index = await _backend.readIndex();
    final capturas = <PendingCapture>[];
    for (final raw in index) {
      try {
        capturas.add(PendingCapture.fromJson(raw));
      } catch (_) {
        // Una entrada corrupta no debe tumbar toda la cola ni esconder el resto.
        // Se ignora al leer; no se borra (D1): sigue en el índice para el diagnóstico.
      }
    }
    capturas.sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    return capturas;
  }

  /// Cuántas faltan por subir. Incluye las que necesitan atención: el contador
  /// que ve el voluntario nunca miente (decisión D5).
  Future<int> count() async => (await list()).length;

  /// La siguiente que toca subir: la más antigua que esté en cola y cuyo backoff
  /// ya venció. `null` si no hay nada que hacer ahora.
  ///
  /// [ahora] se inyecta para que las pruebas no dependan del reloj real.
  Future<PendingCapture?> next({
    required String accountId,
    DateTime? ahora,
  }) async {
    final momento = ahora ?? DateTime.now();
    for (final c in await list()) {
      if (c.state != PendingState.enCola) continue;
      // D8: un dispositivo, un voluntario. Un ítem de otra cuenta es una anomalía
      // y NO se sube: subirla la atribuiría a quien tiene la sesión abierta.
      if (c.accountId != accountId) continue;
      final espera = c.proximoIntento;
      if (espera != null && espera.isAfter(momento)) continue;
      return c;
    }
    return null;
  }

  /// Capturas que están en la cola pero pertenecen a otra cuenta (anomalía, D8).
  /// No se suben ni se borran; se reportan.
  Future<List<PendingCapture>> ajenas(String accountId) async =>
      (await list()).where((c) => c.accountId != accountId).toList();

  Future<Uint8List?> bytesOf(String id) => _backend.getBlob(id);

  /// Persiste un cambio de estado/intentos. Si el id ya no está, no hace nada
  /// (pudo subirse y borrarse en paralelo).
  Future<void> update(PendingCapture captura) async {
    final index = await _backend.readIndex();
    final i = index.indexWhere((e) => e['id'] == captura.id);
    if (i < 0) return;
    index[i] = captura.toJson();
    await _backend.writeIndex(index);
  }

  /// Borra una captura y su imagen. **Solo** tras subida confirmada (o por D6).
  Future<void> delete(String id) async {
    final index = await _backend.readIndex();
    index.removeWhere((e) => e['id'] == id);
    await _backend.writeIndex(index);
    await _backend.deleteBlob(id);
  }

  /// Vacía la cola. Reservado al 410 "cuenta eliminada" (decisión D6): esa cuenta
  /// pidió dejar de existir, así que sus capturas no se conservan ni se suben.
  Future<void> clearAll() async {
    final index = await _backend.readIndex();
    for (final e in index) {
      final id = e['id'];
      if (id is String) await _backend.deleteBlob(id);
    }
    await _backend.writeIndex([]);
  }

  /// Resumen sin PII para "Reportar un problema" (CR-019 ampliado, AC21).
  ///
  /// Es la única vía por la que una cola atascada llega al equipo: con solo el
  /// contador en pantalla (D5), el voluntario no puede señalar cuál falló.
  Future<Map<String, dynamic>> diagnostico() async {
    final capturas = await list();
    final conAtencion =
        capturas.where((c) => c.state == PendingState.necesitaAtencion).toList();
    return {
      'pendientes': capturas.length,
      'necesitan_atencion': conAtencion.length,
      'intentos_maximos': capturas.isEmpty
          ? 0
          : capturas.map((c) => c.intentos).reduce((a, b) => a > b ? a : b),
      'ultimo_error': conAtencion.isNotEmpty
          ? conAtencion.last.ultimoError
          : (capturas.isNotEmpty ? capturas.last.ultimoError : null),
      'almacenamiento_persistente': persistente,
      'mas_antigua':
          capturas.isEmpty ? null : capturas.first.capturedAt.toUtc().toIso8601String(),
    };
  }
}

/// Serialización del índice a texto (la usa el backend nativo, sobre
/// `shared_preferences`). Vive aquí para que las dos plataformas guarden el mismo
/// formato y una migración futura no tenga que adivinar cuál es el bueno.
String encodeIndex(List<Map<String, dynamic>> index) => json.encode(index);

List<Map<String, dynamic>> decodeIndex(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final lista = json.decode(raw);
    if (lista is! List) return [];
    return lista
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  } catch (_) {
    // Índice ilegible: se trata como vacío en lugar de tumbar el arranque. Los
    // blobs siguen en disco, así que el dato no se pierde de forma silenciosa
    // (aparece en el diagnóstico como huérfano).
    return [];
  }
}
