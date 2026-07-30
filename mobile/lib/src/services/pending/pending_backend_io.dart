import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pending_store.dart';

/// Persistencia de la cola en **móvil nativo** (CR-031).
///
/// - Imágenes: un JPEG por captura en `<documentos de la app>/pendientes/`.
/// - Índice: JSON en `shared_preferences`.
///
/// Se separan a propósito: `shared_preferences` es un archivo de preferencias, no
/// un almacén de binarios — meter ahí fotos de 200 KB (peor aún en base64) lo
/// convertiría en un archivo de decenas de MB que se lee entero en cada arranque.
/// El directorio de documentos de la app es privado y no lo indexa la galería, así
/// que el gate #4 sigue intacto: nada de esto crea una vía de importar imágenes.
class IoPendingBackend implements PendingStorageBackend {
  /// [directorio] permite inyectar una ruta en pruebas: `path_provider` necesita
  /// canal de plataforma y no está disponible en el runner de `flutter test`.
  IoPendingBackend({Directory? directorio, SharedPreferences? prefs})
      : _directorioInyectado = directorio,
        _prefs = prefs;

  static const _kIndex = 'pending_capture_index';

  final Directory? _directorioInyectado;
  SharedPreferences? _prefs;
  Directory? _dir;

  @override
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final base = _directorioInyectado ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}pendientes');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
  }

  Directory get _requireDir {
    final d = _dir;
    if (d == null) {
      throw StateError('IoPendingBackend.init() no se ha llamado');
    }
    return d;
  }

  SharedPreferences get _requirePrefs {
    final p = _prefs;
    if (p == null) {
      throw StateError('IoPendingBackend.init() no se ha llamado');
    }
    return p;
  }

  File _archivo(String id) =>
      File('${_requireDir.path}${Platform.pathSeparator}$id.jpg');

  @override
  Future<List<Map<String, dynamic>>> readIndex() async =>
      decodeIndex(_requirePrefs.getString(_kIndex));

  @override
  Future<void> writeIndex(List<Map<String, dynamic>> index) async {
    await _requirePrefs.setString(_kIndex, encodeIndex(index));
  }

  @override
  Future<void> putBlob(String id, Uint8List bytes) async {
    // `flush: true` para que la foto esté realmente en disco antes de que el
    // índice la anuncie: si el teléfono se apaga en medio, sobra un archivo (que
    // se puede limpiar) en vez de faltar uno que la app cree que tiene.
    await _archivo(id).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List?> getBlob(String id) async {
    final f = _archivo(id);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  @override
  Future<void> deleteBlob(String id) async {
    final f = _archivo(id);
    if (await f.exists()) await f.delete();
  }

  /// En nativo el archivo vive en el área privada de la app: no hay desalojo por
  /// presión de almacenamiento como el que puede hacer un navegador (D4).
  @override
  bool get persistente => true;
}

/// Constructor que resuelve el import condicional (ver `pending_backend.dart`).
PendingStorageBackend crearPendingBackend() => IoPendingBackend();
