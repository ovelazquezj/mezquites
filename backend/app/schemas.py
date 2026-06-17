"""Esquemas pydantic de request/response de la API REST (OpenAPI autogenerado, T2).

Notas de gates:
- Gate #2 (sin PII): ningún esquema de registro/recuperación pide email/teléfono/nombre.
- Gate #8: la observación lleva las 8 etiquetas autodeclaradas; NO hay campo de "especie" ni de
  veredicto/validación en la entrada. El estado de validación nunca se devuelve por observación
  individual al voluntario (Q5.A-D1).
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

# --- Auth ---


class RegisterRequest(BaseModel):
    institution_id: uuid.UUID | None = None  # F3; None ⇒ "Independiente"
    # CR-002 (cierra el hueco del gate #5): el registro YA NO acepta `role`. Toda alta por este
    # endpoint es `voluntario`; los roles de backend los crea el administrador (POST /admin/users) y
    # el primer administrador se siembra por config/CLI (bootstrap).


class RegisterResponse(BaseModel):
    handle: str
    role: str
    token: str
    backup_code: str = Field(description="Mostrar UNA vez; permite recuperar la cuenta sin PII.")


class RecoverRequest(BaseModel):
    handle: str
    backup_code: str


class GoogleLoginRequest(BaseModel):
    """Login social de la app (CR-002). Recibe el ID token de Firebase/Google.

    Gate #2 acotado: NO se aceptan email/nombre; el backend verifica el token y guarda solo el `sub`
    opaco. ``institution_id`` es opcional (afiliación F3) y solo aplica al crear la cuenta.
    """

    id_token: str
    institution_id: uuid.UUID | None = None


class TokenResponse(BaseModel):
    handle: str
    role: str
    token: str
    must_change_password: bool = False


class LoginRequest(BaseModel):
    """Login de los roles de backend (CR-002). Usuario + contraseña (hash argon2)."""

    username: str
    password: str


# --- Gestión de usuarios por el administrador (CR-002) ---

# Roles que el administrador puede crear/gestionar. Excluye `voluntario` (alta por la app) y
# `aliado_firmante`/`admin_consorcio` (promoción aparte por la web admin del consorcio).
BACKEND_ROLES = ("administrador", "evaluador", "analista")


class AdminCreateUserRequest(BaseModel):
    """El administrador crea un usuario de backend (evaluador/analista/administrador).

    Gate #2 acotado: `email` SOLO es válido (y opcional) cuando `role == 'administrador'`. Se valida
    en el endpoint. La contraseña temporal la genera el backend (invitación).
    """

    username: str
    role: Literal["administrador", "evaluador", "analista"]
    email: str | None = None  # solo administrador


class AdminUserResponse(BaseModel):
    id: uuid.UUID
    handle: str
    username: str | None
    role: str
    has_email: bool  # NO exponemos el email; solo si lo tiene (gate #2 acotado)
    must_change_password: bool


class AdminCreateUserResponse(AdminUserResponse):
    temp_password: str = Field(
        description="Contraseña temporal de invitación. Mostrar UNA vez; el usuario la cambia."
    )


class AdminPatchUserRequest(BaseModel):
    role: Literal["administrador", "evaluador", "analista"] | None = None
    active: bool | None = None  # reservado; el modelo no tiene 'active' aún, se ignora si None


class AdminResetResponse(BaseModel):
    id: uuid.UUID
    username: str | None
    temp_password: str = Field(
        description="Nueva contraseña temporal. Mostrar UNA vez; el usuario la cambia."
    )


# --- ARCO: Cancelación (eliminar cuenta, anonimizando) — CR-006 ---


class AdminAccountSummary(BaseModel):
    """Resumen de una cuenta para la pantalla ARCO (sin exponer PII: solo `has_email`)."""

    id: uuid.UUID
    handle: str
    role: str
    auth_provider: str
    has_email: bool
    observations: int


class DeleteAccountRequest(BaseModel):
    """Cancelación ARCO ejecutada por el administrador (CR-006). El motivo NO debe contener PII."""

    reason: str | None = Field(
        default=None,
        description="Motivo de la cancelación (auditoría, gate #7). No incluir datos personales.",
    )


class DeleteAccountResponse(BaseModel):
    deleted_account_id: uuid.UUID
    observations_anonymized: int
    message: str = "Cuenta eliminada y observaciones anonimizadas. El dato ecológico se conserva."


class PasswordResetRequest(BaseModel):
    """Reset por correo del administrador (CR-002). Requiere SMTP; degrada si no hay."""

    username: str


class PasswordResetResponse(BaseModel):
    delivered: bool  # True si se envió correo; False ⇒ degradado a "reset por el administrador"
    message: str


# --- Observaciones ---


class ObservationCreate(BaseModel):
    """8 etiquetas de captura (Q2/Q3). EXIF (lat/lon/captured_at) viene del dispositivo (gate #4)."""

    # 1-3: EXIF (cámara nativa)
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    captured_at: datetime
    # 4: triple etiqueta M3 — nivel G4 (autodeclarado, gate #8)
    nivel_g4: Literal["sano", "leve", "moderado", "severo"]
    # 5-6: flags binarios M3
    flag_cuscuta: bool = False
    flag_danio: bool = False
    # 7-8: campos adicionales V3
    tamanio: Literal["pequeno", "mediano", "grande", "no_estimable"]
    contexto: Literal["campo_abierto", "borde_cultivo", "urbano", "ripario", "otro"]
    # CR-010: estado/municipio AUTODECLARADOS (gate #8). El móvil los auto-detecta del GPS y los
    # preselecciona (editable). Si no vienen, el backend los DERIVA del EXIF (respaldo, Q8).
    estado: str | None = None
    municipio: str | None = None


class ObservationSubmitResponse(BaseModel):
    observation_id: uuid.UUID
    base_points: int
    message: str = "Observación registrada y aceptada. ¡Gracias por contribuir!"
    # NO se devuelve estado de revisión individual (Q5.A-D1: sin acusación por observación).


class ObservationMine(BaseModel):
    observation_id: uuid.UUID
    captured_at: datetime
    nivel_g4: str
    flag_cuscuta: bool
    flag_danio: bool
    tamanio: str | None
    contexto: str | None
    estado: str | None
    municipio: str | None
    # Sin validation_state (gate Q5.A-D1).


# --- Feedback / perfil ---


class FeedbackAggregate(BaseModel):
    """Feedback AGREGADO de aportaciones (Q5.A-D1). NUNCA acusación individual.

    Revisión humana (CR-001): toda observación se acepta al subir, así que el resumen pasa a
    "aceptadas / contadas" sobre las últimas N. ``validas`` = no-rechazadas (compatibilidad de campo).
    """

    window: int
    total_considered: int
    validas: int  # no-rechazadas (aceptadas + confirmadas) en la ventana
    message: str


class ProfileResponse(BaseModel):
    handle: str
    identity_label: str  # L3
    institution: str | None
    lifelist_trees: int
    total_observations: int
    total_points: int
    badges: list[str]


# --- Gamificación ---


class RankingEntry(BaseModel):
    handle: str
    institution: str | None
    estado: str | None
    points: int
    observations: int


class InstitutionRankingEntry(BaseModel):
    institution: str
    estado: str | None
    points: int
    observations: int


class RankingsResponse(BaseModel):
    period: str
    individual: list[RankingEntry]
    by_institution: list[InstitutionRankingEntry]


# --- Vistas de datos (público / restringido) ---


class PublicObservation(BaseModel):
    handle: str
    lat: float = Field(description="Obfuscada a la celda de obfuscación (gate #5; CR-009: 300 m).")
    lon: float = Field(description="Obfuscada a la celda de obfuscación (gate #5; CR-009: 300 m).")
    nivel_g4: str
    flag_cuscuta: bool
    flag_danio: bool
    estado: str | None
    municipio: str | None
    captured_at: datetime
    snapshot_quarter: str  # "Qn" — toda vista muestra fecha de snapshot


class PublicGridCell(BaseModel):
    """Celda agregada del mapa de calor público (CR-009, §4.1).

    Agrega las observaciones **no-rechazadas** por celda de obfuscación (gate #5; CR-009: 300 m).
    NUNCA expone coords más finas que la celda ni listas de árboles: solo el centro de celda
    obfuscado y conteos agregados. Especie y nivel G4 son AUTODECLARADOS (gate #8).
    """

    lat: float = Field(description="Centro de celda obfuscado (gate #5; CR-009: 300 m).")
    lon: float = Field(description="Centro de celda obfuscado (gate #5; CR-009: 300 m).")
    n: int = Field(description="Observaciones no-rechazadas en la celda.")
    n_paxtle: int = Field(description="Con daño/paxtle autodeclarado (flag_danio).")
    n_cuscuta: int = Field(description="Con cúscuta autodeclarada (flag_cuscuta).")
    g4_indice: float = Field(
        description="Promedio del nivel G4 mapeado 0..3 (sano=0..severo=3), autodeclarado (gate #8)."
    )
    snapshot_quarter: str  # "Qn" — toda vista muestra fecha de snapshot


class RestrictedObservation(BaseModel):
    handle: str
    lat: float  # EXACTA (solo aliado_firmante)
    lon: float
    nivel_g4: str
    flag_cuscuta: bool
    flag_danio: bool
    estado: str | None
    municipio: str | None
    captured_at: datetime
    estado_revision: str  # aceptada | confirmada | rechazada (revisión humana, CR-001)


class Indicators(BaseModel):
    """Indicadores Q6 social/educativo/ecológico, calculados automáticamente. SIN umbrales (U1)."""

    snapshot_quarter: str
    caveat: str
    social: dict
    educativo: dict
    ecologico: dict
    organizacional: dict


# --- Admin (web admin) ---


class OrganizationalIndicatorIn(BaseModel):
    key: str
    value: float
    estado: str | None = None


class AllyIn(BaseModel):
    handle: str  # promueve una cuenta existente a aliado_firmante


class InstitutionIn(BaseModel):
    name: str
    estado: str | None = None
    request_only: bool = Field(
        default=False, description="True ⇒ 'solicitar agregar' (status=solicitada, ticket a EA3)."
    )


class SnapshotResponse(BaseModel):
    quarter: str
    created_at: datetime
    observations_total: int


# --- Revisión humana (CR-001) ---


class ReviewQueueItem(BaseModel):
    """Fila de la cola de revisión (sin coord exacta; solo estado/municipio, gate #5)."""

    observation_id: uuid.UUID
    handle: str
    captured_at: datetime
    estado_revision: str
    nivel_g4: str
    flag_cuscuta: bool
    flag_danio: bool
    tamanio: str | None
    contexto: str | None
    estado: str | None
    municipio: str | None


class HumanReviewEntry(BaseModel):
    """Una entrada del log append-only de revisión humana."""

    veredicto: str
    nota: str | None
    reviewer_handle: str
    created_at: datetime


class ReviewObservationDetail(BaseModel):
    """Detalle para revisión: 8 etiquetas + metadata + estado + historial (sin coord exacta)."""

    observation_id: uuid.UUID
    handle: str
    captured_at: datetime
    estado_revision: str
    nivel_g4: str
    flag_cuscuta: bool
    flag_danio: bool
    tamanio: str | None
    contexto: str | None
    estado: str | None
    municipio: str | None
    historial: list[HumanReviewEntry]


class VerdictRequest(BaseModel):
    # CR-010: además de confirmada/rechazada, se permite revertir a 'aceptada' (pendiente de
    # revisión). El veredicto sigue siendo autoritativo en backend (CR-001, gate #9 enmendado).
    veredicto: Literal["aceptada", "confirmada", "rechazada"]
    nota: str | None = None


# --- Solicitud de institución (voluntario) — CR-010 ---


class InstitutionRequestIn(BaseModel):
    """Alta de institución solicitada por el voluntario desde la app (CR-010, gate #3 sin gating)."""

    name: str
    estado: str | None = None


class InstitutionRequestResponse(BaseModel):
    id: uuid.UUID
    name: str
    status: str


# --- Analítica (analista) — CR-010 ---


class AnalyticsSummary(BaseModel):
    """Resúmenes agregados para el analista (CR-010). Sin coords; conteos descriptivos (gate #1)."""

    por_estado_revision: dict[str, int]
    por_municipio: dict[str, int]
    por_nivel_g4: dict[str, int]
    total: int


# --- Sesiones de participación / evidencia (#7) — CR-010 ---


class SessionCreate(BaseModel):
    """Una sesión de participación medida por el cliente (lifecycle de la app). Sin PII (gate #2)."""

    started_at: datetime
    ended_at: datetime


class SessionResponse(BaseModel):
    id: uuid.UUID
    started_at: datetime
    ended_at: datetime
    duration_seconds: int


class EvidenceResponse(BaseModel):
    """Evidencia de participación del voluntario (en pantalla). Descriptiva (gate #1), sin PII."""

    capturas: int
    horas_totales: float
    sesiones: int
    primera: datetime | None
    ultima: datetime | None


class VerdictResponse(BaseModel):
    observation_id: uuid.UUID
    estado_revision: str
    message: str


class ReviewStats(BaseModel):
    """Conteos por estado_revision + throughput de revisión (Monitor del analista)."""

    aceptadas: int
    confirmadas: int
    rechazadas: int
    total: int
    pendientes_de_revision: int  # = aceptadas (aún sin veredicto humano)
    revisiones_totales: int  # filas en human_review
