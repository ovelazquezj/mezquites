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
    required this.validationState,
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
  final String validationState;

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
        validationState: (j['validation_state'] ?? '') as String,
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
    OrganizationalIndicatorKey(
        'aliados_firmantes_coords', 'Aliados firmantes con coords exactas'),
    OrganizationalIndicatorKey('eventos_w3', 'Eventos W3 ejecutados'),
    OrganizationalIndicatorKey(
        'menciones_mediaticas', 'Menciones / coberturas mediáticas'),
  ];
}
