import 'dart:math';
import 'dart:typed_data';

import '../../models/enums.dart';
import '../../models/models.dart';

/// Estado de **transporte** de una captura guardada en el dispositivo (CR-031).
///
/// ⚠️ Gate #9 / Q5.A-D1: esto NO tiene nada que ver con la revisión humana. Una
/// captura "en cola" está esperando *red*, no esperando *veredicto*. Los tres
/// estados que el voluntario debe poder distinguir son:
/// **en tu teléfono** → **subida, en revisión** → **confirmada**; los dos últimos
/// los decide el backend y no se representan aquí.
enum PendingState {
  /// Guardada, esperando conexión (o su turno en el backoff).
  enCola('en_cola'),

  /// Se está subiendo ahora mismo.
  subiendo('subiendo'),

  /// El servidor la rechazó por algo que no se arregla reintentando (422). No se
  /// borra nunca (decisión D1): queda marcada para que alguien la atienda.
  necesitaAtencion('necesita_atencion');

  const PendingState(this.wire);

  final String wire;

  static PendingState byWire(String wire) =>
      values.firstWhere((v) => v.wire == wire, orElse: () => enCola);
}

/// Una captura guardada en el dispositivo esperando subir (CR-031).
///
/// Contiene **todo** lo necesario para reconstruir el envío más tarde: las 8
/// etiquetas, la posición, y —por separado, en el almacén de bytes— la foto. La
/// cola anterior a este CR guardaba solo las etiquetas, así que aunque hubiera
/// sobrevivido a cerrar la app no habría tenido nada que subir.
///
/// **[id] es el `client_capture_id`** que viaja al backend (W1). Se genera **al
/// capturar** y es el mismo en todos los reintentos: es lo que permite al servidor
/// reconocer un reintento y responder 200 + `ya_existia` en vez de crear un
/// segundo árbol.
class PendingCapture {
  const PendingCapture({
    required this.id,
    required this.accountId,
    required this.lat,
    required this.lon,
    required this.capturedAt,
    required this.nivelG4,
    required this.flagCuscuta,
    required this.flagDanio,
    required this.tamanio,
    required this.contexto,
    this.estado,
    this.municipio,
    this.state = PendingState.enCola,
    this.intentos = 0,
    this.ultimoError,
    this.proximoIntento,
  });

  /// `client_capture_id` (UUID v4). Clave local y sello de idempotencia.
  final String id;

  /// Cuenta que capturó. **Sello de procedencia** (decisión D8: un dispositivo,
  /// un voluntario). No se usa para filtrar la cola al leer, pero si apareciera
  /// un ítem de otra cuenta se trata como anomalía: no se sube.
  final String accountId;

  final double lat;
  final double lon;

  /// Momento de la **captura**, nunca el de la subida. Es lo que el backend
  /// guarda en `captured_at`; el retraso de la subida queda en su `created_at`.
  final DateTime capturedAt;

  final String nivelG4;
  final bool flagCuscuta;
  final bool flagDanio;
  final String tamanio;
  final String contexto;
  final String? estado;
  final String? municipio;

  final PendingState state;

  /// Nº de intentos de subida fallidos. Alimenta el backoff (W3) y el diagnóstico.
  final int intentos;

  /// Último error, para el reporte de problemas. Nunca se muestra crudo al
  /// voluntario.
  final String? ultimoError;

  /// Cuándo puede volver a intentarse. `null` = ya.
  final DateTime? proximoIntento;

  /// True si esta captura sigue contando como "por subir" para el contador.
  /// Las que necesitan atención **también** cuentan: el número nunca miente
  /// (decisión D5, que dejó el contador como única superficie).
  bool get cuentaComoPendiente => true;

  PendingCapture copyWith({
    PendingState? state,
    int? intentos,
    String? ultimoError,
    DateTime? proximoIntento,
    bool limpiarProximoIntento = false,
  }) =>
      PendingCapture(
        id: id,
        accountId: accountId,
        lat: lat,
        lon: lon,
        capturedAt: capturedAt,
        nivelG4: nivelG4,
        flagCuscuta: flagCuscuta,
        flagDanio: flagDanio,
        tamanio: tamanio,
        contexto: contexto,
        estado: estado,
        municipio: municipio,
        state: state ?? this.state,
        intentos: intentos ?? this.intentos,
        ultimoError: ultimoError ?? this.ultimoError,
        proximoIntento:
            limpiarProximoIntento ? null : (proximoIntento ?? this.proximoIntento),
      );

  /// Rehidrata el borrador de envío. [bytes] llegan del almacén de imágenes.
  ///
  /// Se usa `imageBytes` en las dos plataformas a propósito: en nativo la foto ya
  /// se copió a la carpeta de pendientes, así que la ruta original del archivo
  /// temporal de la cámara pudo desaparecer. Los bytes son la única fuente fiable
  /// una vez que la captura sobrevivió a un cierre de la app.
  ObservationDraft toDraft(Uint8List bytes) => ObservationDraft(
        lat: lat,
        lon: lon,
        capturedAt: capturedAt,
        nivelG4: NivelG4.byWire(nivelG4),
        flagCuscuta: flagCuscuta,
        flagDanio: flagDanio,
        tamanio: Tamanio.byWire(tamanio),
        contexto: Contexto.byWire(contexto),
        estado: estado,
        municipio: municipio,
        imageBytes: bytes,
        clientCaptureId: id,
      );

  /// Construye una pendiente a partir del borrador recién capturado.
  factory PendingCapture.fromDraft(
    ObservationDraft draft, {
    required String id,
    required String accountId,
  }) =>
      PendingCapture(
        id: id,
        accountId: accountId,
        lat: draft.lat,
        lon: draft.lon,
        capturedAt: draft.capturedAt,
        nivelG4: draft.nivelG4.wire,
        flagCuscuta: draft.flagCuscuta,
        flagDanio: draft.flagDanio,
        tamanio: draft.tamanio.wire,
        contexto: draft.contexto.wire,
        estado: draft.estado,
        municipio: draft.municipio,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_id': accountId,
        'lat': lat,
        'lon': lon,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'nivel_g4': nivelG4,
        'flag_cuscuta': flagCuscuta,
        'flag_danio': flagDanio,
        'tamanio': tamanio,
        'contexto': contexto,
        if (estado != null) 'estado': estado,
        if (municipio != null) 'municipio': municipio,
        'state': state.wire,
        'intentos': intentos,
        if (ultimoError != null) 'ultimo_error': ultimoError,
        if (proximoIntento != null)
          'proximo_intento': proximoIntento!.toUtc().toIso8601String(),
      };

  factory PendingCapture.fromJson(Map<String, dynamic> j) => PendingCapture(
        id: j['id'] as String,
        accountId: j['account_id'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        capturedAt: DateTime.parse(j['captured_at'] as String),
        nivelG4: j['nivel_g4'] as String,
        flagCuscuta: j['flag_cuscuta'] as bool? ?? false,
        flagDanio: j['flag_danio'] as bool? ?? false,
        tamanio: j['tamanio'] as String,
        contexto: j['contexto'] as String,
        estado: j['estado'] as String?,
        municipio: j['municipio'] as String?,
        state: PendingState.byWire(j['state'] as String? ?? 'en_cola'),
        intentos: (j['intentos'] as num?)?.toInt() ?? 0,
        ultimoError: j['ultimo_error'] as String?,
        proximoIntento: (j['proximo_intento'] as String?) != null
            ? DateTime.parse(j['proximo_intento'] as String)
            : null,
      );
}

/// UUID v4 con `Random.secure()`, sin añadir un paquete por 12 líneas.
///
/// Fija la versión (4) y la variante (RFC 4122) en los nibbles que manda el
/// estándar: el backend lo recibe como `uuid` de Postgres y un valor mal formado
/// lo rechazaría el propio tipo.
String nuevoClientCaptureId([Random? random]) {
  final rnd = random ?? Random.secure();
  final bytes = Uint8List.fromList(
    List<int>.generate(16, (_) => rnd.nextInt(256)),
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  String hex(int desde, int hasta) => bytes
      .sublist(desde, hasta)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
