import 'dart:typed_data';

import 'enums.dart';

/// Sesión del voluntario (CR-002, gate #2 acotado). Identidad real por Google, pero la app guarda
/// SOLO el `handle` de presentación + `role` + JWT que devuelve el backend. NUNCA email/nombre.
class AuthSession {
  const AuthSession({
    required this.handle,
    required this.role,
    required this.token,
  });

  final String handle;
  final String role;
  final String token;

  factory AuthSession.fromToken(Map<String, dynamic> j) => AuthSession(
        handle: j['handle'] as String,
        role: j['role'] as String,
        token: j['token'] as String,
      );
}

/// Borrador de las 8 etiquetas de captura (Q2/Q3) listas para POST /observations.
/// 1-3 EXIF (cámara nativa), 4 nivel G4, 5-6 flags, 7-8 dropdowns V3.
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
    this.imagePath,
    this.imageBytes,
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

  /// Imagen capturada: por **ruta** (móvil nativo, con EXIF) o por **bytes** (web).
  final String? imagePath;
  final Uint8List? imageBytes;

  /// Las 8 etiquetas serializadas para el campo `payload` (multipart).
  Map<String, dynamic> toPayloadJson() => {
        'lat': lat,
        'lon': lon,
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'nivel_g4': nivelG4.wire,
        'flag_cuscuta': flagCuscuta,
        'flag_danio': flagDanio,
        'tamanio': tamanio.wire,
        'contexto': contexto.wire,
      };
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

/// Feedback AGREGADO de tasa de validación (Q5.A-D1, gate #9).
/// "De tus últimas N, M válidas." NUNCA acusación individual.
class FeedbackAggregate {
  const FeedbackAggregate({
    required this.window,
    required this.totalConsidered,
    required this.validas,
    required this.message,
  });

  final int window;
  final int totalConsidered;
  final int validas;
  final String message;

  factory FeedbackAggregate.fromJson(Map<String, dynamic> j) =>
      FeedbackAggregate(
        window: j['window'] as int,
        totalConsidered: j['total_considered'] as int,
        validas: j['validas'] as int,
        message: j['message'] as String,
      );
}

/// Perfil del voluntario (Q4). Etiqueta de identidad SIN desbloquear funciones.
class Profile {
  const Profile({
    required this.handle,
    required this.identityLabel,
    this.institution,
    required this.lifelistTrees,
    required this.totalObservations,
    required this.totalPoints,
    required this.badges,
  });

  final String handle;
  final String identityLabel;
  final String? institution;
  final int lifelistTrees;
  final int totalObservations;
  final int totalPoints;
  final List<String> badges;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        handle: j['handle'] as String,
        identityLabel: j['identity_label'] as String,
        institution: j['institution'] as String?,
        lifelistTrees: j['lifelist_trees'] as int,
        totalObservations: j['total_observations'] as int,
        totalPoints: j['total_points'] as int,
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

/// Observación pública con coords OBFUSCADAS a la celda pública (gate #5;
/// CR-009 enmienda el radio de 1 km a 300 m server-side).
/// La app NUNCA muestra coords más finas que esto.
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

  /// Centro de celda pública (obfuscado server-side, gate #5; CR-009 = 300 m).
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
/// NO RECHAZADAS por celda de 300 m; el centro de celda viene OBFUSCADO
/// server-side (gate #5 enmendado: 1 km → 300 m). La app NUNCA recibe ni
/// muestra coords más finas que la celda.
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

  /// Centro de celda de 300 m (obfuscado server-side, gate #5).
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

/// Institución de la lista F3 (afiliación o "solicitar agregar").
class Institution {
  const Institution({
    required this.id,
    required this.name,
    this.estado,
    required this.status,
  });

  final String id;
  final String name;
  final String? estado;
  final String status;

  factory Institution.fromJson(Map<String, dynamic> j) => Institution(
        id: j['id'] as String,
        name: j['name'] as String,
        estado: j['estado'] as String?,
        status: j['status'] as String,
      );
}
