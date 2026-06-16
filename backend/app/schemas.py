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
    # NOTA (CR-001): el registro aún admite asignar rol (los nuevos roles de revisión incluidos);
    # la restricción del registro a `voluntario` + bootstrap de roles por CLI es alcance de CR-002.
    role: Literal[
        "voluntario",
        "aliado_firmante",
        "admin_consorcio",
        "administrador",
        "evaluador",
        "analista",
    ] = "voluntario"


class RegisterResponse(BaseModel):
    handle: str
    role: str
    token: str
    backup_code: str = Field(description="Mostrar UNA vez; permite recuperar la cuenta sin PII.")


class RecoverRequest(BaseModel):
    handle: str
    backup_code: str


class TokenResponse(BaseModel):
    handle: str
    role: str
    token: str


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
    lat: float = Field(description="Obfuscada a celda de 1 km (gate #5).")
    lon: float = Field(description="Obfuscada a celda de 1 km (gate #5).")
    nivel_g4: str
    flag_cuscuta: bool
    flag_danio: bool
    estado: str | None
    municipio: str | None
    captured_at: datetime
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
    veredicto: Literal["confirmada", "rechazada"]
    nota: str | None = None


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
