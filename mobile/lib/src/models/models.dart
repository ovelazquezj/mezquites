import 'dart:convert';
import 'dart:typed_data';

import 'enums.dart';

/// Sesión del voluntario (CR-002, gate #2 acotado). Identidad real por Google, pero la app guarda
/// SOLO el `handle` de presentación + `role` + JWT que devuelve el backend. NUNCA email/nombre.
class AuthSession {
  const AuthSession({
    required this.handle,
    required this.role,
    required this.token,
    this.accountId,
  });

  final String handle;
  final String role;
  final String token;

  /// CR-031: id de la cuenta, leído del `sub` del JWT. Es el **sello de
  /// procedencia** de las capturas guardadas en el dispositivo: identifica de
  /// quién son sin que la app tenga que guardar nada nuevo (el backend ya pone ahí
  /// el `account_id`, ver `deps.py`). Sigue sin haber PII: es un UUID opaco.
  /// `null` si el token no se pudo leer.
  final String? accountId;

  factory AuthSession.fromToken(Map<String, dynamic> j) {
    final token = j['token'] as String;
    return AuthSession(
      handle: j['handle'] as String,
      role: j['role'] as String,
      token: token,
      accountId: accountIdFromJwt(token),
    );
  }
}

/// Lee el `sub` (account_id) del payload de un JWT, **sin verificar la firma**.
///
/// No hace falta verificarla: la firma la comprueba el backend en cada petición y
/// aquí el valor solo se usa como etiqueta local de "de quién es esta captura". Si
/// el token es ilegible devuelve `null` y quien lo use debe tolerarlo.
String? accountIdFromJwt(String token) {
  final json = _jwtPayload(token);
  if (json is Map && json['sub'] is String) return json['sub'] as String;
  return null;
}

/// Decodifica el payload (segunda parte) de un JWT, **sin verificar la firma**
/// (mismo criterio que [accountIdFromJwt]: la firma la comprueba el backend en
/// cada petición; aquí los claims solo se usan como pista local). Devuelve
/// `null` si el token es ilegible.
dynamic _jwtPayload(String token) {
  try {
    final partes = token.split('.');
    if (partes.length < 2) return null;
    var payload = partes[1].replaceAll('-', '+').replaceAll('_', '/');
    // base64url sin relleno: se completa a múltiplo de 4.
    payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
    return jsonDecode(utf8.decode(base64.decode(payload)));
  } catch (_) {
    return null;
  }
}

/// Lee el claim `exp` (segundos UNIX) del JWT como fecha UTC (CR-035).
/// `null` si el token es ilegible o no trae `exp` — tolerante, mismo espíritu
/// que [accountIdFromJwt]: quien lo use debe soportar no saberlo.
DateTime? expiryFromJwt(String token) {
  final json = _jwtPayload(token);
  if (json is Map && json['exp'] is num) {
    return DateTime.fromMillisecondsSinceEpoch(
      ((json['exp'] as num) * 1000).round(),
      isUtc: true,
    );
  }
  return null;
}

/// ¿El token ya venció? (CR-035, disparador **proactivo**: permite encender el
/// aviso al abrir la app sin esperar el primer 401). Sin `exp` legible devuelve
/// `false`: no se molesta al voluntario por un token que no sabemos leer — el
/// backend seguirá siendo la autoridad y el 401 real lo detectará el cliente.
/// [now] inyectable para pruebas deterministas.
bool tokenVencido(String token, {DateTime Function()? now}) {
  final exp = expiryFromJwt(token);
  if (exp == null) return false;
  final ahora = (now ?? DateTime.now)().toUtc();
  return !ahora.isBefore(exp);
}

/// Borrador de las etiquetas de captura (Q2/Q3) listas para POST /observations.
/// 1-3 EXIF (cámara nativa), 4 nivel G4, 5-6 flags, 7-8 dropdowns V3.
/// CR-010 #5: + estado/municipio AUTODECLARADOS (auto-detectados del GPS,
/// editables). Si llegan al backend se usan; si no, el backend los deriva.
class ObservationDraft {
  const ObservationDraft({
    required this.lat,
    required this.lon,
    required this.capturedAt,
    required this.nivelG4,
    required this.flagCuscuta,
    required this.flagDanio,
    required this.tamanio,
    required this.contexto,
    this.gpsAccuracyM,
    this.imagePath,
    this.imageBytes,
    this.clientCaptureId,
  }) : assert(imagePath != null || imageBytes != null,
            'La observación necesita imagen por ruta (móvil) o bytes (web).',);

  final double lat;
  final double lon;
  final DateTime capturedAt;
  final NivelG4 nivelG4;
  final bool flagCuscuta;
  final bool flagDanio;
  final Tamanio tamanio;
  final Contexto contexto;

  /// CR-036: precisión del fix del GPS en metros, tal como la reporta el
  /// dispositivo. Nullable: no todos los navegadores la entregan.
  ///
  /// Estado y municipio **ya no viajan**: los deriva el servidor de las
  /// coordenadas (CR-036). Antes eran autodeclarados por dos dropdowns, y ese
  /// fue el mecanismo que etiquetó 39 capturas de Zacatecas como "Calvillo".
  final double? gpsAccuracyM;

  /// Imagen capturada: por **ruta** (móvil nativo, con EXIF) o por **bytes** (web).
  final String? imagePath;
  final Uint8List? imageBytes;

  /// CR-031: id que la app genera **al capturar** y repite en cada reintento de
  /// subida. Hace idempotente el `POST /observations`: si la respuesta se perdió
  /// de vuelta, el reintento devuelve la observación original en vez de crear un
  /// segundo árbol. `null` solo en pruebas o en un envío que no pasa por la cola.
  final String? clientCaptureId;

  /// Las etiquetas serializadas para el campo `payload` (multipart). **No incluye
  /// estado ni municipio**: los resuelve el servidor a partir de lat/lon (CR-036).
  Map<String, dynamic> toPayloadJson() => {
        'lat': lat,
        'lon': lon,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'nivel_g4': nivelG4.wire,
        'flag_cuscuta': flagCuscuta,
        'flag_danio': flagDanio,
        'tamanio': tamanio.wire,
        'contexto': contexto.wire,
        if (gpsAccuracyM != null) 'gps_accuracy_m': gpsAccuracyM,
        if (clientCaptureId != null) 'client_capture_id': clientCaptureId,
      };
}

/// Resultado de `POST /observations` (CR-031).
///
/// Hay **dos** desenlaces buenos y la app necesita distinguirlos: **201** creó la
/// observación; **200 con [yaExistia]** significa que esta captura ya estaba
/// registrada —era el reintento de un envío cuya respuesta se perdió— y el
/// servidor devolvió la original en vez de crear un segundo árbol. Los dos quieren
/// decir "está a salvo en el servidor", así que en los dos casos la captura se
/// puede borrar del teléfono.
class SubmitResult {
  const SubmitResult({required this.observationId, this.yaExistia = false});

  final String observationId;
  final bool yaExistia;
}

/// Una observación propia en cola/registrada. NUNCA contiene estado de
/// validación individual (gate #9, Q5.A-D1).
class MineObservation {
  const MineObservation({
    required this.observationId,
    required this.capturedAt,
    required this.nivelG4,
    required this.flagCuscuta,
    required this.flagDanio,
    this.tamanio,
    this.contexto,
    this.estado,
    this.municipio,
    this.pending = false,
  });

  final String observationId;
  final DateTime capturedAt;
  final String nivelG4;
  final bool flagCuscuta;
  final bool flagDanio;
  final String? tamanio;
  final String? contexto;
  final String? estado;
  final String? municipio;

  /// Marca local "pendiente" (aún encolada) — NO es estado de validación.
  final bool pending;

  factory MineObservation.fromJson(Map<String, dynamic> j) => MineObservation(
        observationId: j['observation_id'] as String,
        capturedAt: DateTime.parse(j['captured_at'] as String),
        nivelG4: j['nivel_g4'] as String,
        flagCuscuta: j['flag_cuscuta'] as bool,
        flagDanio: j['flag_danio'] as bool,
        tamanio: j['tamanio'] as String?,
        contexto: j['contexto'] as String?,
        estado: j['estado'] as String?,
        municipio: j['municipio'] as String?,
      );
}

/// Feedback AGREGADO de aportaciones (Q5.A-D1, gate #9). NUNCA acusación individual.
///
/// CR-030: el resumen cubre **todas** las observaciones de la cuenta, no "las
/// últimas 20". El campo `window` del backend queda deprecado y ya no se lee:
/// era el recorte que hacía que el mensaje se congelara en 20.
class FeedbackAggregate {
  const FeedbackAggregate({
    required this.totalConsidered,
    required this.validas,
    this.enRevision = 0,
    required this.message,
  });

  /// Total real de observaciones subidas por la cuenta (CR-030).
  final int totalConsidered;

  /// Confirmadas por revisión humana (CR-026).
  final int validas;

  /// Subidas que siguen en cola de revisión. NO incluye rechazadas (CR-030).
  final int enRevision;

  /// Mensaje agregado, redactado por el backend.
  final String message;

  factory FeedbackAggregate.fromJson(Map<String, dynamic> j) =>
      FeedbackAggregate(
        totalConsidered: (j['total_considered'] as num).toInt(),
        validas: (j['validas'] as num).toInt(),
        // Tolera un backend anterior a CR-030 (campo ausente).
        enRevision: (j['en_revision'] as num?)?.toInt() ?? 0,
        message: j['message'] as String,
      );
}

/// Perfil del voluntario (Q4). Etiqueta de identidad SIN desbloquear funciones.
///
/// CR-030: además del conteo de confirmadas (CR-026) llega [totalUploaded], el
/// número que el voluntario reconoce como "lo que subí". Tener los dos permite
/// explicar la brecha en pantalla en vez de dejarla como una pérdida aparente.
class Profile {
  const Profile({
    required this.handle,
    required this.identityLabel,
    this.institution,
    required this.lifelistTrees,
    required this.totalObservations,
    this.totalUploaded = 0,
    this.enRevision = 0,
    required this.totalPoints,
    required this.badges,
  });

  final String handle;
  final String identityLabel;
  final String? institution;

  /// Árboles distintos con al menos una observación confirmada (CR-026).
  final int lifelistTrees;

  /// Observaciones **confirmadas** por revisión humana (CR-026).
  final int totalObservations;

  /// Observaciones **subidas**, revisadas o no (CR-030).
  final int totalUploaded;

  /// Subidas que siguen en cola de revisión. NO incluye rechazadas (CR-030).
  final int enRevision;

  final int totalPoints;
  final List<String> badges;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        handle: j['handle'] as String,
        identityLabel: j['identity_label'] as String,
        institution: j['institution'] as String?,
        lifelistTrees: (j['lifelist_trees'] as num).toInt(),
        totalObservations: (j['total_observations'] as num).toInt(),
        // Tolera un backend anterior a CR-030: sin el campo, el total subido no
        // se conoce y cae al confirmado (nunca lo pinta más bajo de lo real).
        totalUploaded: (j['total_uploaded'] as num?)?.toInt() ??
            (j['total_observations'] as num).toInt(),
        enRevision: (j['en_revision'] as num?)?.toInt() ?? 0,
        totalPoints: (j['total_points'] as num).toInt(),
        badges: (j['badges'] as List).cast<String>(),
      );
}

class RankingEntry {
  const RankingEntry({
    required this.handle,
    this.institution,
    this.estado,
    required this.points,
    required this.observations,
  });

  final String handle;
  final String? institution;
  final String? estado;
  final int points;
  final int observations;

  factory RankingEntry.fromJson(Map<String, dynamic> j) => RankingEntry(
        handle: j['handle'] as String,
        institution: j['institution'] as String?,
        estado: j['estado'] as String?,
        points: j['points'] as int,
        observations: j['observations'] as int,
      );
}

class InstitutionRankingEntry {
  const InstitutionRankingEntry({
    required this.institution,
    this.estado,
    required this.points,
    required this.observations,
  });

  final String institution;
  final String? estado;
  final int points;
  final int observations;

  factory InstitutionRankingEntry.fromJson(Map<String, dynamic> j) =>
      InstitutionRankingEntry(
        institution: j['institution'] as String,
        estado: j['estado'] as String?,
        points: j['points'] as int,
        observations: j['observations'] as int,
      );
}

class Rankings {
  const Rankings({
    required this.period,
    required this.individual,
    required this.byInstitution,
  });

  final String period;
  final List<RankingEntry> individual;
  final List<InstitutionRankingEntry> byInstitution;

  factory Rankings.fromJson(Map<String, dynamic> j) => Rankings(
        period: j['period'] as String,
        individual: (j['individual'] as List)
            .map((e) => RankingEntry.fromJson((e as Map).cast()))
            .toList(),
        byInstitution: (j['by_institution'] as List)
            .map((e) => InstitutionRankingEntry.fromJson((e as Map).cast()))
            .toList(),
      );
}

/// Observación pública individual con la ubicación del mezquite (presentación
/// pública, CR-025). Alimenta el modo "ubicaciones exactas" del mapa
/// (un marcador por árbol).
class PublicObservation {
  const PublicObservation({
    required this.handle,
    required this.lat,
    required this.lon,
    required this.nivelG4,
    required this.flagCuscuta,
    required this.flagDanio,
    this.estado,
    this.municipio,
    required this.capturedAt,
    required this.snapshotQuarter,
  });

  final String handle;

  /// Ubicación del mezquite (presentación pública, CR-025).
  final double lat;
  final double lon;
  final String nivelG4;
  final bool flagCuscuta;
  final bool flagDanio;
  final String? estado;
  final String? municipio;
  final DateTime capturedAt;
  final String snapshotQuarter;

  factory PublicObservation.fromJson(Map<String, dynamic> j) =>
      PublicObservation(
        handle: j['handle'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        nivelG4: j['nivel_g4'] as String,
        flagCuscuta: j['flag_cuscuta'] as bool,
        flagDanio: j['flag_danio'] as bool,
        estado: j['estado'] as String?,
        municipio: j['municipio'] as String?,
        capturedAt: DateTime.parse(j['captured_at'] as String),
        snapshotQuarter: j['snapshot_quarter'] as String,
      );
}

/// Celda del mapa de calor público (CR-009). Agrega las observaciones
/// NO RECHAZADAS por celda (~300 m) como *binning* del heatmap; el centro es
/// el de la celda de agregación, no un árbol individual.
class GridCell {
  const GridCell({
    required this.lat,
    required this.lon,
    required this.n,
    required this.nPaxtle,
    required this.nCuscuta,
    required this.g4Indice,
    required this.snapshotQuarter,
  });

  /// Centro de la celda de binning del mapa de calor (~300 m, server-side).
  final double lat;
  final double lon;

  /// Nº de observaciones en la celda.
  final int n;

  /// Nº con paxtle (flag_danio) y con cúscuta (flag_cuscuta).
  final int nPaxtle;
  final int nCuscuta;

  /// Promedio 0..3 (sano, leve, moderado, severo) → intensidad del calor.
  final double g4Indice;
  final String snapshotQuarter;

  factory GridCell.fromJson(Map<String, dynamic> j) => GridCell(
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        n: (j['n'] as num).toInt(),
        nPaxtle: (j['n_paxtle'] as num).toInt(),
        nCuscuta: (j['n_cuscuta'] as num).toInt(),
        g4Indice: (j['g4_indice'] as num).toDouble(),
        snapshotQuarter: j['snapshot_quarter'] as String,
      );
}

/// Indicadores Q6 (social/educativo/ecológico/organizacional). Sin umbrales (U1).
class Indicators {
  const Indicators({
    required this.snapshotQuarter,
    required this.caveat,
    required this.social,
    required this.educativo,
    required this.ecologico,
    required this.organizacional,
  });

  final String snapshotQuarter;
  final String caveat;
  final Map<String, dynamic> social;
  final Map<String, dynamic> educativo;
  final Map<String, dynamic> ecologico;
  final Map<String, dynamic> organizacional;

  factory Indicators.fromJson(Map<String, dynamic> j) => Indicators(
        snapshotQuarter: j['snapshot_quarter'] as String,
        caveat: j['caveat'] as String,
        social: (j['social'] as Map).cast<String, dynamic>(),
        educativo: (j['educativo'] as Map).cast<String, dynamic>(),
        ecologico: (j['ecologico'] as Map).cast<String, dynamic>(),
        organizacional: (j['organizacional'] as Map).cast<String, dynamic>(),
      );
}

/// Comprobante de participación (CR-010 #7). Resumen AGREGADO de la actividad
/// propia para mostrarlo como evidencia al alumno (en pantalla, sin PDF).
/// Gate #2: solo conteos y rango de fechas; nada de PII. Gate #1: descriptivo.
///
/// CR-026 (solicitud de las universidades): [capturas] pasó a contar solo las
/// observaciones **confirmadas** por revisión humana y [capturasTotales] guarda
/// el total subido. [horasTotales] se sigue recibiendo pero **ya no se muestra**:
/// medía tiempo con la app abierta, no trabajo en campo. Se conserva en el
/// modelo porque el backend la sigue enviando y es dato de análisis.
///
/// CR-030: [enRevision] llega del servidor. Antes se deducía restando
/// `capturasTotales - capturas`, y esa resta contaba las **rechazadas** como si
/// siguieran en cola: con 13 subidas, 12 confirmadas y 1 rechazada la pantalla
/// decía "1 sigue en revisión".
class Evidence {
  const Evidence({
    required this.capturas,
    required this.capturasTotales,
    required this.horasTotales,
    required this.sesiones,
    int? enRevision,
    this.primera,
    this.ultima,
  }) : _enRevision = enRevision;

  /// Nº de observaciones propias **confirmadas** (CR-026).
  final int capturas;

  /// Nº total de observaciones subidas, revisadas o no (CR-026).
  final int capturasTotales;

  /// Horas acumuladas de sesión (Σ duración / 3600). NO se pinta (CR-026).
  final double horasTotales;

  /// Nº de sesiones de participación registradas.
  final int sesiones;

  /// Rango de fechas de actividad (puede ser null si aún no hay nada).
  final DateTime? primera;
  final DateTime? ultima;

  /// Valor del servidor (CR-030). `null` = backend anterior al campo.
  final int? _enRevision;

  /// Observaciones subidas que siguen esperando revisión.
  ///
  /// Con un backend anterior a CR-030 cae a la resta antigua, que sobrestima
  /// (mete las rechazadas). Es el peor caso tolerable: nunca oculta trabajo.
  int get pendientes {
    final delServidor = _enRevision;
    if (delServidor != null) return delServidor < 0 ? 0 : delServidor;
    final resta = capturasTotales - capturas;
    return resta < 0 ? 0 : resta;
  }

  factory Evidence.fromJson(Map<String, dynamic> j) => Evidence(
        capturas: (j['capturas'] as num).toInt(),
        capturasTotales: (j['capturas_totales'] as num?)?.toInt() ??
            (j['capturas'] as num).toInt(),
        enRevision: (j['en_revision'] as num?)?.toInt(),
        horasTotales: (j['horas_totales'] as num).toDouble(),
        sesiones: (j['sesiones'] as num).toInt(),
        primera: (j['primera'] as String?) != null
            ? DateTime.parse(j['primera'] as String)
            : null,
        ultima: (j['ultima'] as String?) != null
            ? DateTime.parse(j['ultima'] as String)
            : null,
      );
}

/// Institución de la lista F3 (afiliación o "solicitar agregar").
class Institution {
  const Institution({
    required this.id,
    required this.name,
    this.estado,
    required this.status,
    this.yaExistia = false,
  });

  final String id;
  final String name;
  final String? estado;
  final String status;

  /// CR-028: la institución YA estaba registrada y quedaste afiliado a ella (no se creó nada).
  /// Solo lo manda `POST /institutions/request`; en el catálogo viene ausente ⇒ false.
  final bool yaExistia;

  factory Institution.fromJson(Map<String, dynamic> j) => Institution(
        id: j['id'] as String,
        name: j['name'] as String,
        estado: j['estado'] as String?,
        status: j['status'] as String,
        yaExistia: j['ya_existia'] as bool? ?? false,
      );

  /// Forma canónica del nombre, para saber si dos escrituras son la MISMA institución (CR-028).
  ///
  /// Réplica en Dart de `normalize_institution_name` del backend y del índice único de la base:
  /// sin acentos, minúsculas, espacios internos colapsados y extremos recortados. Se mantiene
  /// alineada a propósito — si divergiera, la app diría "es nueva" y el backend respondería "ya
  /// existía", que es exactamente la confusión que esto viene a evitar.
  static String normalizeName(String raw) {
    const acentos = 'ÁÀÂÄÃÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇáàâäãéèêëíìîïóòôöõúùûüñç';
    const bases = 'AAAAAEEEEIIIIOOOOOUUUUNCaaaaaeeeeiiiiooooouuuunc';
    final sinAcentos = StringBuffer();
    for (final ch in raw.split('')) {
      final i = acentos.indexOf(ch);
      sinAcentos.write(i >= 0 ? bases[i] : ch);
    }
    return sinAcentos
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }
}

/// Lugar resuelto por el servidor a partir de unas coordenadas (`GET /geo/resolve`, CR-036).
///
/// Es **informativo**: sirve para que el voluntario VEA dónde va a quedar su registro sin tener
/// que seleccionarlo. Nunca viaja de vuelta en el submit — el servidor vuelve a resolver la
/// ubicación al recibir la foto, así que esta respuesta no puede alterar el dato guardado.
class GeoLugar {
  const GeoLugar({
    this.estado,
    this.municipio,
    this.cveEnt,
    this.cveMun,
    this.resuelto = false,
  });

  final String? estado;
  final String? municipio;
  final String? cveEnt;
  final String? cveMun;

  /// False cuando el punto no cae en ningún municipio con límites cargados.
  final bool resuelto;

  /// "Jalpa, Zacatecas" — vacío si no se resolvió.
  String get etiqueta {
    if (!resuelto) return '';
    if (municipio != null && estado != null) return '$municipio, $estado';
    return estado ?? municipio ?? '';
  }

  factory GeoLugar.fromJson(Map<String, dynamic> j) => GeoLugar(
        estado: j['estado'] as String?,
        municipio: j['municipio'] as String?,
        cveEnt: j['cve_ent'] as String?,
        cveMun: j['cve_mun'] as String?,
        resuelto: j['resuelto'] as bool? ?? false,
      );
}
