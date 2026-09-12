/// Modelos de la web admin. Reflejan `backend/app/schemas.py` con nombres de
/// campo EXACTOS (sin PII; gate #2). Solo los necesarios para el rol
/// `admin_consorcio` y las vistas público/restringido.
library;

/// Sesión autenticada (de `/auth/recover` o token pegado). Sin PII.
class AuthSession {
  AuthSession({required this.handle, required this.role, required this.token});

  final String handle;
  final String role;
  final String token;

  /// Desde `TokenResponse` (POST /auth/recover): {handle, role, token}.
  factory AuthSession.fromToken(Map<String, dynamic> j) => AuthSession(
        handle: (j['handle'] ?? '') as String,
        role: (j['role'] ?? '') as String,
        token: j['token'] as String,
      );

  bool get isAdmin => role == 'admin_consorcio';

  /// Rol `administrador` de backend (CR-001/CR-002): gestiona usuarios + emite veredicto.
  bool get isAdministrador => role == 'administrador';

  /// Roles que pueden ver la cola de revisión (lectura). `analista` es solo lectura.
  bool get canReview =>
      role == 'evaluador' || role == 'analista' || role == 'administrador';

  /// Roles que pueden emitir veredicto (NO incluye `analista`).
  bool get canEmitVerdict => role == 'evaluador' || role == 'administrador';

  /// CR-042: ESCRIBIR comentarios sobre una observación (el área grande del
  /// detalle, antes llamada "Notas"). Es del `analista` y del `administrador`.
  ///
  /// El `evaluador` queda fuera A PROPÓSITO: él ya tiene su campo "Nota
  /// (opcional)" pegado al veredicto, y tener dos lugares donde escribir en la
  /// misma ventana era justo la confusión que el usuario reportó. Leer sí lee
  /// —los comentarios son el contexto que le ayuda a decidir—, así que la lista
  /// no se gatea con esta capacidad: solo el campo, el aviso y el botón.
  /// La autorización real la impone el backend (403 al evaluador).
  bool get canWriteComments => role == 'analista' || role == 'administrador';

  /// Solo el `administrador` gestiona usuarios de backend (CR-002).
  bool get canManageUsers => role == 'administrador';

  /// Solo el `administrador` ejecuta la cancelación ARCO de cuentas (CR-006).
  bool get canDeleteAccounts => role == 'administrador';

  /// Datos y descargas (CR-010 #3): `analista` y `administrador`.
  bool get canSeeData => role == 'analista' || role == 'administrador';

  /// Reportes de problemas (CR-019): mismo gateo que los módulos de consola —
  /// `admin_consorcio` y `administrador` (los roles que administran el piloto).
  bool get canSeeProblemReports => isAdmin || isAdministrador;

  /// CR-025: la ubicación exacta del mezquite es información pública. En la
  /// consola la ven TODOS los roles (mapa exacto + panel con ubicación exacta):
  /// `aliado_firmante`, `administrador`, `admin_consorcio`, `analista` y
  /// `evaluador`. La autorización real la impone el backend.
  bool get canSeeExactLocation =>
      role == 'aliado_firmante' ||
      role == 'administrador' ||
      role == 'admin_consorcio' ||
      role == 'analista' ||
      role == 'evaluador';

  /// Roles con acceso a la consola de administración (CR-001 amplía los de revisión).
  bool get canEnterAdminConsole => isAdmin || canReview;
}

/// Usuario de backend (CR-002). Gate #2 acotado: NUNCA expone el email, solo `has_email`.
class BackendUser {
  BackendUser({
    required this.id,
    required this.handle,
    required this.username,
    required this.role,
    required this.hasEmail,
    required this.mustChangePassword,
    this.protected = false,
  });

  final String id;
  final String handle;
  final String? username;
  final String role;
  final bool hasEmail;
  final bool mustChangePassword;

  /// CR-040: cuenta de administrador principal. El backend no deja eliminarla ni
  /// cambiarle el rol (devuelve 400); la consola desactiva ambas acciones para
  /// que nadie se quede sin manera de entrar. Falso si el backend no manda el
  /// campo (tolerante a respuestas anteriores a CR-040).
  final bool protected;

  factory BackendUser.fromJson(Map<String, dynamic> j) => BackendUser(
        id: (j['id'] ?? '') as String,
        handle: (j['handle'] ?? '') as String,
        username: j['username'] as String?,
        role: (j['role'] ?? '') as String,
        hasEmail: (j['has_email'] ?? false) as bool,
        mustChangePassword: (j['must_change_password'] ?? false) as bool,
        protected: (j['protected'] ?? false) as bool,
      );
}

/// Respuesta al crear un usuario: incluye la contraseña temporal (mostrar UNA vez).
class BackendUserCreated extends BackendUser {
  BackendUserCreated({
    required super.id,
    required super.handle,
    required super.username,
    required super.role,
    required super.hasEmail,
    required super.mustChangePassword,
    super.protected,
    required this.tempPassword,
  });

  final String tempPassword;

  factory BackendUserCreated.fromJson(Map<String, dynamic> j) => BackendUserCreated(
        id: (j['id'] ?? '') as String,
        handle: (j['handle'] ?? '') as String,
        username: j['username'] as String?,
        role: (j['role'] ?? '') as String,
        hasEmail: (j['has_email'] ?? false) as bool,
        mustChangePassword: (j['must_change_password'] ?? false) as bool,
        protected: (j['protected'] ?? false) as bool,
        tempPassword: (j['temp_password'] ?? '') as String,
      );
}

/// Resumen de una cuenta para la pantalla ARCO de cancelación (CR-006). SOLO
/// `administrador`. Gate #2: NUNCA expone el email (solo `hasEmail` como señal) ni
/// el nombre real; `username` es el nombre de acceso que el propio administrador
/// asignó a un usuario de consola, no un dato personal.
class AdminAccountSummary {
  AdminAccountSummary({
    required this.id,
    required this.handle,
    required this.role,
    required this.authProvider,
    required this.hasEmail,
    required this.observations,
    this.username,
    this.protected = false,
  });

  final String id;
  final String handle;
  final String role;
  final String authProvider;
  final bool hasEmail;
  final int observations;

  /// CR-040: nombre de acceso de un usuario de consola (evaluador/analista/
  /// administrador). Null para una persona voluntaria, que solo tiene handle.
  final String? username;

  /// CR-040: cuenta de administrador principal — el backend rechaza eliminarla.
  final bool protected;

  /// Cómo nombrar la cuenta en pantalla: el nombre de acceso si lo tiene; si no,
  /// el handle. Nadie conoce el `obs-XXXXXX` de un usuario de consola.
  String get displayName =>
      (username != null && username!.isNotEmpty) ? username! : handle;

  factory AdminAccountSummary.fromJson(Map<String, dynamic> j) =>
      AdminAccountSummary(
        id: (j['id'] ?? '') as String,
        handle: (j['handle'] ?? '') as String,
        role: (j['role'] ?? '') as String,
        authProvider: (j['auth_provider'] ?? '') as String,
        hasEmail: (j['has_email'] ?? false) as bool,
        observations: (j['observations'] ?? 0) as int,
        username: j['username'] as String?,
        protected: (j['protected'] ?? false) as bool,
      );
}

/// Resultado de la cancelación ARCO (DELETE /admin/accounts/{id}). Sin PII.
/// `observationsAnonymized`: nº de observaciones cuyo vínculo a la persona se rompió
/// (el dato ecológico se conserva en el dataset público).
class DeleteAccountResult {
  DeleteAccountResult({
    required this.deletedAccountId,
    required this.observationsAnonymized,
    required this.message,
  });

  final String deletedAccountId;
  final int observationsAnonymized;
  final String message;

  factory DeleteAccountResult.fromJson(Map<String, dynamic> j) =>
      DeleteAccountResult(
        deletedAccountId: (j['deleted_account_id'] ?? '') as String,
        observationsAnonymized: (j['observations_anonymized'] ?? 0) as int,
        message: (j['message'] ?? '') as String,
      );
}

/// Institución de la lista F3 (Q4). `status`: "aprobada" | "solicitada".
class Institution {
  Institution({
    required this.id,
    required this.name,
    required this.estado,
    required this.status,
  });

  final String id;
  final String name;
  final String? estado;
  final String status;

  bool get isRequested => status == 'solicitada';

  factory Institution.fromJson(Map<String, dynamic> j) => Institution(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        estado: j['estado'] as String?,
        status: (j['status'] ?? '') as String,
      );
}

/// Resultado de un snapshot trimestral (POST /admin/snapshots).
class SnapshotResult {
  SnapshotResult({
    required this.quarter,
    required this.createdAt,
    required this.observationsTotal,
  });

  final String quarter;
  final DateTime createdAt;
  final int observationsTotal;

  factory SnapshotResult.fromJson(Map<String, dynamic> j) => SnapshotResult(
        quarter: (j['quarter'] ?? '') as String,
        createdAt:
            DateTime.tryParse((j['created_at'] ?? '') as String) ??
                DateTime.now(),
        observationsTotal: (j['observations_total'] ?? 0) as int,
      );
}

/// Observación pública: coords EXACTAS del árbol (CR-025).
class PublicObservation {
  PublicObservation({
    required this.handle,
    required this.lat,
    required this.lon,
    required this.nivelG4,
    required this.flagCuscuta,
    required this.flagDanio,
    required this.estado,
    required this.municipio,
    required this.capturedAt,
    required this.snapshotQuarter,
  });

  final String handle;
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
        handle: (j['handle'] ?? '') as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        nivelG4: (j['nivel_g4'] ?? '') as String,
        flagCuscuta: (j['flag_cuscuta'] ?? false) as bool,
        flagDanio: (j['flag_danio'] ?? false) as bool,
        estado: j['estado'] as String?,
        municipio: j['municipio'] as String?,
        capturedAt:
            DateTime.tryParse((j['captured_at'] ?? '') as String) ??
                DateTime.fromMillisecondsSinceEpoch(0),
        snapshotQuarter: (j['snapshot_quarter'] ?? '') as String,
      );
}

/// Observación con coords EXACTAS del árbol. La ubicación exacta es pública
/// (CR-025); en la consola la ven todos los roles.
class RestrictedObservation {
  RestrictedObservation({
    required this.handle,
    required this.lat,
    required this.lon,
    required this.nivelG4,
    required this.flagCuscuta,
    required this.flagDanio,
    required this.estado,
    required this.municipio,
    required this.capturedAt,
    required this.estadoRevision,
  });

  final String handle;
  final double lat;
  final double lon;
  final String nivelG4;
  final bool flagCuscuta;
  final bool flagDanio;
  final String? estado;
  final String? municipio;
  final DateTime capturedAt;
  final String estadoRevision;

  factory RestrictedObservation.fromJson(Map<String, dynamic> j) =>
      RestrictedObservation(
        handle: (j['handle'] ?? '') as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        nivelG4: (j['nivel_g4'] ?? '') as String,
        flagCuscuta: (j['flag_cuscuta'] ?? false) as bool,
        flagDanio: (j['flag_danio'] ?? false) as bool,
        estado: j['estado'] as String?,
        municipio: j['municipio'] as String?,
        capturedAt:
            DateTime.tryParse((j['captured_at'] ?? '') as String) ??
                DateTime.fromMillisecondsSinceEpoch(0),
        estadoRevision: (j['estado_revision'] ?? '') as String,
      );
}

/// Fila de la cola de revisión humana (CR-001). SIN coord exacta (gate #5).
class ReviewQueueItem {
  ReviewQueueItem({
    required this.observationId,
    required this.handle,
    required this.capturedAt,
    required this.estadoRevision,
    required this.nivelG4,
    required this.flagCuscuta,
    required this.flagDanio,
    required this.tamanio,
    required this.contexto,
    required this.estado,
    required this.municipio,
  });

  final String observationId;
  final String handle;
  final DateTime capturedAt;
  final String estadoRevision;
  final String nivelG4;
  final bool flagCuscuta;
  final bool flagDanio;
  final String? tamanio;
  final String? contexto;
  final String? estado;
  final String? municipio;

  factory ReviewQueueItem.fromJson(Map<String, dynamic> j) => ReviewQueueItem(
        observationId: (j['observation_id'] ?? '') as String,
        handle: (j['handle'] ?? '') as String,
        capturedAt: DateTime.tryParse((j['captured_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        estadoRevision: (j['estado_revision'] ?? '') as String,
        nivelG4: (j['nivel_g4'] ?? '') as String,
        flagCuscuta: (j['flag_cuscuta'] ?? false) as bool,
        flagDanio: (j['flag_danio'] ?? false) as bool,
        tamanio: j['tamanio'] as String?,
        contexto: j['contexto'] as String?,
        estado: j['estado'] as String?,
        municipio: j['municipio'] as String?,
      );
}

/// Una entrada del log append-only de revisión humana (auditoría, gate #7).
class HumanReviewEntry {
  HumanReviewEntry({
    required this.veredicto,
    required this.nota,
    required this.reviewerHandle,
    required this.createdAt,
  });

  final String veredicto;
  final String? nota;
  final String reviewerHandle;
  final DateTime createdAt;

  factory HumanReviewEntry.fromJson(Map<String, dynamic> j) => HumanReviewEntry(
        veredicto: (j['veredicto'] ?? '') as String,
        nota: j['nota'] as String?,
        reviewerHandle: (j['reviewer_handle'] ?? '') as String,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Una nota escrita sobre una observación, INDEPENDIENTE del veredicto (CR-041).
///
/// La nota de `HumanReviewEntry` viaja pegada a una decisión y solo la escribe quien
/// emite veredicto; ésta la puede dejar cualquier rol de revisión (el analista incluido)
/// sin mover `estado_revision`. Append-only: no hay edición ni borrado (gate #7).
class ObservationNote {
  ObservationNote({
    required this.id,
    required this.texto,
    required this.autorHandle,
    required this.createdAt,
  });

  final String id;
  final String texto;

  /// Handle de quien la escribió. NUNCA su correo (gate #2).
  final String autorHandle;
  final DateTime createdAt;

  factory ObservationNote.fromJson(Map<String, dynamic> j) => ObservationNote(
        id: (j['id'] ?? '') as String,
        texto: (j['texto'] ?? '') as String,
        autorHandle: (j['autor_handle'] ?? '') as String,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Detalle de una observación en revisión + historial. SIN coord exacta (gate #5).
class ReviewObservationDetail {
  ReviewObservationDetail({
    required this.observationId,
    required this.handle,
    required this.capturedAt,
    required this.estadoRevision,
    required this.nivelG4,
    required this.flagCuscuta,
    required this.flagDanio,
    required this.tamanio,
    required this.contexto,
    required this.estado,
    required this.municipio,
    required this.historial,
    this.notas = const [],
  });

  final String observationId;
  final String handle;
  final DateTime capturedAt;
  final String estadoRevision;
  final String nivelG4;
  final bool flagCuscuta;
  final bool flagDanio;
  final String? tamanio;
  final String? contexto;
  final String? estado;
  final String? municipio;
  final List<HumanReviewEntry> historial;

  /// Notas escritas sobre la observación (CR-041), de la más antigua a la más
  /// reciente. Lista VACÍA si el backend aún no manda el campo: la consola se
  /// despliega después del backend y no debe romperse contra uno anterior.
  final List<ObservationNote> notas;

  factory ReviewObservationDetail.fromJson(Map<String, dynamic> j) =>
      ReviewObservationDetail(
        observationId: (j['observation_id'] ?? '') as String,
        handle: (j['handle'] ?? '') as String,
        capturedAt: DateTime.tryParse((j['captured_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        estadoRevision: (j['estado_revision'] ?? '') as String,
        nivelG4: (j['nivel_g4'] ?? '') as String,
        flagCuscuta: (j['flag_cuscuta'] ?? false) as bool,
        flagDanio: (j['flag_danio'] ?? false) as bool,
        tamanio: j['tamanio'] as String?,
        contexto: j['contexto'] as String?,
        estado: j['estado'] as String?,
        municipio: j['municipio'] as String?,
        historial: ((j['historial'] ?? []) as List)
            .map((e) => HumanReviewEntry.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        notas: ((j['notas'] ?? []) as List)
            .map((e) => ObservationNote.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Métricas de la cola de revisión (Monitor del analista). Sin umbrales (U1).
class ReviewStats {
  ReviewStats({
    required this.aceptadas,
    required this.confirmadas,
    required this.rechazadas,
    required this.total,
    required this.pendientesDeRevision,
    required this.revisionesTotales,
    this.observacionesRevisadas = 0,
  });

  final int aceptadas;
  final int confirmadas;
  final int rechazadas;
  final int total;
  final int pendientesDeRevision;

  /// Veredictos EMITIDOS (filas del log append-only), no observaciones: una observación revisada
  /// dos veces suma dos. CR-029.
  final int revisionesTotales;

  /// Observaciones DISTINTAS con al menos un veredicto (CR-029). Es el número comparable con
  /// [total]; sin él, ver `total` junto a [revisionesTotales] parecía un descuadre.
  final int observacionesRevisadas;

  factory ReviewStats.fromJson(Map<String, dynamic> j) => ReviewStats(
        aceptadas: (j['aceptadas'] ?? 0) as int,
        confirmadas: (j['confirmadas'] ?? 0) as int,
        rechazadas: (j['rechazadas'] ?? 0) as int,
        total: (j['total'] ?? 0) as int,
        pendientesDeRevision: (j['pendientes_de_revision'] ?? 0) as int,
        revisionesTotales: (j['revisiones_totales'] ?? 0) as int,
        observacionesRevisadas: (j['observaciones_revisadas'] ?? 0) as int,
      );
}

/// Celda del mapa de calor público (CR-009/CR-010 #2). El centro es el de la
/// celda de *binning* de agregación (~300 m), no un árbol individual.
class GridCell {
  GridCell({
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
        snapshotQuarter: (j['snapshot_quarter'] ?? '') as String,
      );
}

/// Tarjetas de resumen del analista (CR-010 #3, GET /admin/analytics/summary).
/// Conteos agregados sin coords exactas (gate #5) y sin umbrales (U1).
class AnalyticsSummary {
  AnalyticsSummary({
    required this.total,
    required this.porEstadoRevision,
    required this.porNivelG4,
    required this.porMunicipio,
    required this.porEstado,
    required this.snapshotQuarter,
  });

  /// Total de observaciones consideradas (tras los filtros aplicados).
  final int total;

  /// Conteo por estado de revisión (aceptada/confirmada/rechazada).
  final Map<String, int> porEstadoRevision;

  /// Conteo por nivel de paxtle autodeclarado (sano/leve/moderado/severo).
  final Map<String, int> porNivelG4;

  /// Conteo por municipio (sin coords; gate #5).
  final Map<String, int> porMunicipio;

  /// CR-036: conteo por entidad federativa. El desglose que faltaba desde que el dataset dejó de
  /// ser de un solo estado.
  final Map<String, int> porEstado;

  final String snapshotQuarter;

  static Map<String, int> _intMap(dynamic v) => ((v ?? {}) as Map)
      .map((k, val) => MapEntry('$k', (val as num).toInt()));

  factory AnalyticsSummary.fromJson(Map<String, dynamic> j) => AnalyticsSummary(
        total: (j['total'] ?? 0) as int,
        porEstadoRevision: _intMap(j['por_estado_revision']),
        porNivelG4: _intMap(j['por_nivel_g4']),
        porMunicipio: _intMap(j['por_municipio']),
        porEstado: _intMap(j['por_estado']),
        snapshotQuarter: (j['snapshot_quarter'] ?? '') as String,
      );
}

/// Fila de la tabla de datos del analista (CR-010 #3). SIN coord exacta: solo
/// estado/municipio agregables (gate #5). Refleja /admin/analytics/observations.
class AnalyticsObservation {
  AnalyticsObservation({
    required this.observationId,
    required this.handle,
    required this.capturedAt,
    required this.estadoRevision,
    required this.nivelG4,
    required this.flagCuscuta,
    required this.flagDanio,
    required this.estado,
    required this.municipio,
  });

  final String observationId;
  final String handle;
  final DateTime capturedAt;
  final String estadoRevision;
  final String nivelG4;
  final bool flagCuscuta;
  final bool flagDanio;
  final String? estado;
  final String? municipio;

  factory AnalyticsObservation.fromJson(Map<String, dynamic> j) =>
      AnalyticsObservation(
        observationId: (j['observation_id'] ?? '') as String,
        handle: (j['handle'] ?? '') as String,
        capturedAt: DateTime.tryParse((j['captured_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        estadoRevision: (j['estado_revision'] ?? '') as String,
        nivelG4: (j['nivel_g4'] ?? '') as String,
        flagCuscuta: (j['flag_cuscuta'] ?? false) as bool,
        flagDanio: (j['flag_danio'] ?? false) as bool,
        estado: j['estado'] as String?,
        municipio: j['municipio'] as String?,
      );
}

/// Indicadores Q6 (público): social/educativo/ecológico/organizacional + caveat.
/// SIN umbrales (U1). `caveat` = caveat de origen ciudadano (debe verse en la UI).
class Indicators {
  Indicators({
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
        snapshotQuarter: (j['snapshot_quarter'] ?? '') as String,
        caveat: (j['caveat'] ?? '') as String,
        social: ((j['social'] ?? {}) as Map).cast<String, dynamic>(),
        educativo: ((j['educativo'] ?? {}) as Map).cast<String, dynamic>(),
        ecologico: ((j['ecologico'] ?? {}) as Map).cast<String, dynamic>(),
        organizacional:
            ((j['organizacional'] ?? {}) as Map).cast<String, dynamic>(),
      );
}

/// Reporte de un problema enviado desde las apps (CR-019). Lo levanta una persona
/// voluntaria (o un rol de backend) para avisar de un fallo. Gate #2: el backend
/// NUNCA incluye PII (email/nombre); como mucho el `handle` seudónimo. Refleja
/// `GET /admin/problem-reports`.
class ProblemReport {
  ProblemReport({
    required this.id,
    required this.createdAt,
    required this.accountId,
    required this.handle,
    required this.userAgent,
    required this.platform,
    required this.appVersion,
    required this.context,
    required this.message,
    required this.errorDetail,
    required this.status,
  });

  final String id;
  final DateTime createdAt;
  final String? accountId;
  final String? handle;
  final String? userAgent;
  final String? platform;
  final String? appVersion;
  final String? context;
  final String? message;
  final String? errorDetail;

  /// `nuevo` | `visto` | `resuelto` (wire del backend).
  final String status;

  bool get isNuevo => status == 'nuevo';
  bool get isVisto => status == 'visto';
  bool get isResuelto => status == 'resuelto';

  factory ProblemReport.fromJson(Map<String, dynamic> j) => ProblemReport(
        id: (j['id'] ?? '') as String,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        accountId: j['account_id'] as String?,
        handle: j['handle'] as String?,
        userAgent: j['user_agent'] as String?,
        platform: j['platform'] as String?,
        appVersion: j['app_version'] as String?,
        context: j['context'] as String?,
        message: j['message'] as String?,
        errorDetail: j['error_detail'] as String?,
        status: (j['status'] ?? 'nuevo') as String,
      );
}

/// Catálogo de claves de indicadores organizacionales (Q6 amendment).
/// Captura MANUAL en la web admin; sin lógica de umbrales (U1).
class OrganizationalIndicatorKey {
  const OrganizationalIndicatorKey(this.key, this.label, this.ayuda);
  final String key;
  final String label;

  /// Qué se cuenta exactamente en el campo "Cantidad" (CR-042). La etiqueta sola
  /// no bastaba: quien captura no sabía si el número eran eventos, personas o
  /// asistentes. Se muestra bajo el campo y cambia al cambiar de indicador.
  final String ayuda;

  /// Las 4 sub-categorías organizacionales de Q6-D1.
  static const List<OrganizationalIndicatorKey> all = [
    OrganizationalIndicatorKey('mesas_formales_autoridades',
        'Mesas formales con autoridades', 'Cuántas mesas o reuniones hubo'),
    OrganizationalIndicatorKey('aliados_firmantes_coords',
        'Aliados firmantes con convenio', 'Cuántos aliados firmaron'),
    OrganizationalIndicatorKey(
        'eventos_w3', 'Eventos realizados', 'Cuántos eventos se realizaron'),
    OrganizationalIndicatorKey('menciones_mediaticas', 'Menciones en medios',
        'Cuántas menciones aparecieron en medios'),
  ];

  /// Busca una clave del catálogo; `null` si el backend devuelve una que la
  /// consola todavía no conoce (la pantalla la muestra igual, sin romperse).
  static OrganizationalIndicatorKey? byKey(String key) {
    for (final k in all) {
      if (k.key == key) return k;
    }
    return null;
  }
}

/// Un registro de indicador organizacional guardado en el servidor (CR-042).
///
/// Antes la pantalla solo guardaba una lista **en memoria** ("Capturados en esta
/// sesión") que se perdía al cambiar de sección; el dato sí estaba en la base,
/// pero nadie lo leía. Este modelo es lo que devuelve
/// `GET /admin/indicators/organizational`.
class OrganizationalIndicator {
  const OrganizationalIndicator({
    required this.id,
    required this.key,
    required this.value,
    required this.estado,
    required this.createdAt,
    this.descripcion,
  });

  final String id;

  /// Clave del catálogo ([OrganizationalIndicatorKey]).
  final String key;

  /// Cantidad capturada. El panel público **suma** las de una misma clave.
  final double value;

  /// Entidad federativa (o "Otro"). Obligatoria: es el filtro geográfico.
  final String estado;

  /// Qué pasó, en palabras de quien captura. Opcional y puede faltar en el JSON.
  final String? descripcion;

  final DateTime createdAt;

  factory OrganizationalIndicator.fromJson(Map<String, dynamic> j) =>
      OrganizationalIndicator(
        id: (j['id'] ?? '') as String,
        key: (j['key'] ?? '') as String,
        value: (j['value'] as num?)?.toDouble() ?? 0,
        estado: (j['estado'] ?? '') as String,
        descripcion: j['descripcion'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Entidad federativa del catálogo geográfico (`GET /geo/estados`, CR-036).
class GeoEstado {
  const GeoEstado({required this.cveEnt, required this.estado});

  final String cveEnt;
  final String estado;

  factory GeoEstado.fromJson(Map<String, dynamic> j) => GeoEstado(
        cveEnt: j['cve_ent'] as String,
        estado: j['estado'] as String,
      );
}

/// Municipio del catálogo geográfico (`GET /geo/municipios`, CR-036).
class GeoMunicipio {
  const GeoMunicipio({
    required this.cveEnt,
    required this.cveMun,
    required this.estado,
    required this.municipio,
  });

  final String cveEnt;
  final String cveMun;
  final String estado;
  final String municipio;

  factory GeoMunicipio.fromJson(Map<String, dynamic> j) => GeoMunicipio(
        cveEnt: j['cve_ent'] as String,
        cveMun: j['cve_mun'] as String,
        estado: j['estado'] as String,
        municipio: j['municipio'] as String,
      );
}
