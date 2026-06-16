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

  /// Solo el `administrador` gestiona usuarios de backend (CR-002).
  bool get canManageUsers => role == 'administrador';

  /// Roles con acceso a la consola del consorcio (CR-001 amplía los de revisión).
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
  });

  final String id;
  final String handle;
  final String? username;
  final String role;
  final bool hasEmail;
  final bool mustChangePassword;

  factory BackendUser.fromJson(Map<String, dynamic> j) => BackendUser(
        id: (j['id'] ?? '') as String,
        handle: (j['handle'] ?? '') as String,
        username: j['username'] as String?,
        role: (j['role'] ?? '') as String,
        hasEmail: (j['has_email'] ?? false) as bool,
        mustChangePassword: (j['must_change_password'] ?? false) as bool,
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
        tempPassword: (j['temp_password'] ?? '') as String,
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

/// Observación pública: coords YA obfuscadas a 1 km server-side (gate #5).
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

/// Observación restringida: coords EXACTAS (solo aliado_firmante; gate #5).
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
  });

  final int aceptadas;
  final int confirmadas;
  final int rechazadas;
  final int total;
  final int pendientesDeRevision;
  final int revisionesTotales;

  factory ReviewStats.fromJson(Map<String, dynamic> j) => ReviewStats(
        aceptadas: (j['aceptadas'] ?? 0) as int,
        confirmadas: (j['confirmadas'] ?? 0) as int,
        rechazadas: (j['rechazadas'] ?? 0) as int,
        total: (j['total'] ?? 0) as int,
        pendientesDeRevision: (j['pendientes_de_revision'] ?? 0) as int,
        revisionesTotales: (j['revisiones_totales'] ?? 0) as int,
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

/// Catálogo de claves de indicadores organizacionales (Q6 amendment).
/// Captura MANUAL en la web admin; sin lógica de umbrales (U1).
class OrganizationalIndicatorKey {
  const OrganizationalIndicatorKey(this.key, this.label);
  final String key;
  final String label;

  /// Las 4 sub-categorías organizacionales de Q6-D1.
  static const List<OrganizationalIndicatorKey> all = [
    OrganizationalIndicatorKey(
        'mesas_formales_autoridades', 'Mesas formales con autoridades'),
    OrganizationalIndicatorKey('aliados_firmantes_coords',
        'Aliados firmantes con acceso a ubicación exacta'),
    OrganizationalIndicatorKey('eventos_w3', 'Eventos realizados'),
    OrganizationalIndicatorKey(
        'menciones_mediaticas', 'Menciones en medios'),
  ];
}
