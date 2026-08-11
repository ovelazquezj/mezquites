"""Esquemas pydantic de request/response de la API REST (OpenAPI autogenerado, T2).

Notas de gates:
- Gate #2 (sin PII): ningún esquema de registro/recuperación pide email/teléfono/nombre.
- Gate #8: la observación lleva las 8 etiquetas autodeclaradas; NO hay campo de "especie" ni de
  veredicto/validación en la entrada. El estado de validación nunca se devuelve por observación
  individual al voluntario (Q5.A-D1).
"""

from __future__ import annotations

import re
import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator


def _nombre_institucion_limpio(v: str) -> str:
    """Colapsa espacios internos, recorta y rechaza vacío (CR-028).

    Solo limpia lo que se GUARDA. Decidir si dos nombres son "el mismo" es harina de otro costal y
    vive en ``institution_names`` (acentos, mayúsculas), porque esa regla también la tiene que
    conocer el índice de la base.
    """
    limpio = re.sub(r"\s+", " ", v).strip()
    if not limpio:
        raise ValueError("el nombre de la institución no puede ir vacío")
    return limpio


def _estado_institucion_opcional(v: str | None) -> str | None:
    """Un estado en blanco es "sin estado" (``None``), no un estado distinto de ``NULL`` (CR-028)."""
    if v is None:
        return None
    return re.sub(r"\s+", " ", v).strip() or None

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
    # CR-036: **el servidor deriva estado/municipio del punto capturado y estos campos se IGNORAN.**
    # Se conservan en el esquema —sin retirarlos— porque los bundles PWA anteriores siguen
    # enviándolos desde su caché y rechazar el POST los dejaría sin poder subir. Un cliente al día
    # ya no los manda. (Antes, CR-010, eran autodeclarados por un dropdown; ese fue el origen de las
    # 39 observaciones de Zacatecas etiquetadas "Calvillo".)
    estado: str | None = None
    municipio: str | None = None
    # CR-036: precisión del fix del GPS en metros, como la reporta el dispositivo. Al retirar los
    # dropdowns de la captura ya no queda ningún humano que pueda notar un fix malo cerca de un
    # límite estatal: esta es la única señal de calidad de la ubicación que queda.
    gps_accuracy_m: float | None = Field(default=None, ge=0)
    # CR-031: id que la app genera AL CAPTURAR y repite en cada reintento. Hace idempotente el
    # submit: si la respuesta se perdió, el reintento no crea un segundo árbol. Opcional para no
    # romper clientes anteriores a CR-031 (que simplemente no lo mandan).
    client_capture_id: uuid.UUID | None = None


class ObservationSubmitResponse(BaseModel):
    observation_id: uuid.UUID
    base_points: int
    message: str = "Observación registrada y aceptada. ¡Gracias por contribuir!"
    # CR-031: True ⇒ esta captura ya estaba registrada (mismo `client_capture_id`), así que NO se
    # creó nada nuevo y se devuelve el `observation_id` original. Mismo criterio que `ya_existia` de
    # CR-028 y `sin_cambio` de CR-029: no castigar un reintento legítimo ni ensuciar el dato.
    ya_existia: bool = False
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
    "aceptadas / contadas". CR-026: ``validas`` = **confirmadas** (se conserva el nombre del campo
    por compatibilidad).

    **CR-030:** el resumen ya no se calcula sobre "las últimas N": considera **todas** las
    observaciones de la cuenta, así que ``total_considered`` es el total real subido.
    """

    # Deprecado (CR-030): la ventana desapareció y este campo vale lo mismo que `total_considered`.
    # Se conserva porque una PWA con bundle viejo en caché lo parsea como `int` obligatorio; quitarlo
    # rompería su pantalla de perfil hasta que el service worker refresque.
    window: int
    total_considered: int  # CR-030: total real subido por la cuenta
    validas: int  # confirmadas (CR-026)
    en_revision: int = 0  # CR-030: aceptadas (sin revisar); NO incluye rechazadas
    message: str


class ProfileResponse(BaseModel):
    handle: str
    identity_label: str  # L3
    institution: str | None
    lifelist_trees: int
    # CR-026: confirmadas por revisión humana. Alimenta insignias y etiqueta L3, y NO cambia con
    # CR-030: lo que se añade es el total crudo al lado, no otra definición de "válida".
    total_observations: int
    total_uploaded: int = 0  # CR-030: total real subido, revisado o no
    en_revision: int = 0  # CR-030: aceptadas (sin revisar); NO incluye rechazadas
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
    lat: float = Field(description="Ubicación exacta del árbol.")
    lon: float = Field(description="Ubicación exacta del árbol.")
    nivel_g4: str
    flag_cuscuta: bool
    flag_danio: bool
    estado: str | None
    municipio: str | None
    captured_at: datetime
    snapshot_quarter: str  # "Qn" — toda vista muestra fecha de snapshot


class PublicGridCell(BaseModel):
    """Celda agregada del mapa de calor público (CR-009, §4.1).

    Agrupa (*binning*) las observaciones **no-rechazadas** en celdas métricas (CR-009: 300 m) y
    devuelve el centro de celda + conteos/promedios. El snap a celda es agregación de
    densidad/severidad del heatmap (no una capa de presentación de la ubicación). Especie y nivel G4
    son AUTODECLARADOS (gate #8).
    """

    lat: float = Field(description="Centro de la celda del heatmap (binning de agregación).")
    lon: float = Field(description="Centro de la celda del heatmap (binning de agregación).")
    n: int = Field(description="Observaciones no-rechazadas en la celda.")
    n_paxtle: int = Field(description="Con daño/paxtle autodeclarado (flag_danio).")
    n_cuscuta: int = Field(description="Con cúscuta autodeclarada (flag_cuscuta).")
    g4_indice: float = Field(
        description="Promedio del nivel G4 mapeado 0..3 (sano=0..severo=3), autodeclarado (gate #8)."
    )
    snapshot_quarter: str  # "Qn" — toda vista muestra fecha de snapshot


class RestrictedObservation(BaseModel):
    handle: str
    lat: float  # EXACTA (roles de consola, CR-025)
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

    @field_validator("name")
    @classmethod
    def _limpia_nombre(cls, v: str) -> str:
        return _nombre_institucion_limpio(v)

    @field_validator("estado")
    @classmethod
    def _limpia_estado(cls, v: str | None) -> str | None:
        return _estado_institucion_opcional(v)


class InstitutionUpdateIn(BaseModel):
    """Edición de una institución del catálogo (CR-029).

    **No incluye `status` a propósito** (decisión del usuario): degradar una `aprobada` la sacaría
    del catálogo con voluntarios ya afiliados. Para aprobar sigue estando `POST .../approve`, en un
    solo sentido.

    Campos omitidos = "no tocar". Para `estado`, mandar `null` **explícitamente** sí lo limpia; por
    eso el router distingue con `model_fields_set` y no por el valor.
    """

    name: str | None = None
    estado: str | None = None

    @field_validator("name")
    @classmethod
    def _limpia_nombre(cls, v: str | None) -> str | None:
        # `name` es NOT NULL: mandar null equivale a no mandarlo (el router lo ignora).
        return None if v is None else _nombre_institucion_limpio(v)

    @field_validator("estado")
    @classmethod
    def _limpia_estado(cls, v: str | None) -> str | None:
        return _estado_institucion_opcional(v)


class SnapshotResponse(BaseModel):
    quarter: str
    created_at: datetime
    observations_total: int


# --- Revisión humana (CR-001) ---


class ReviewQueueItem(BaseModel):
    """Fila de la cola de revisión (no incluye coords; solo estado/municipio)."""

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

    @field_validator("name")
    @classmethod
    def _limpia_nombre(cls, v: str) -> str:
        return _nombre_institucion_limpio(v)

    @field_validator("estado")
    @classmethod
    def _limpia_estado(cls, v: str | None) -> str | None:
        return _estado_institucion_opcional(v)


class InstitutionRequestResponse(BaseModel):
    id: uuid.UUID
    name: str
    status: str
    # CR-028: True ⇒ la institución YA existía y la cuenta quedó afiliada a ella (no se creó nada).
    # Permite a la app decir "ya estaba registrada" en vez de "solicitud enviada".
    ya_existia: bool = False


# --- Analítica (analista) — CR-010 ---


class AnalyticsSummary(BaseModel):
    """Resúmenes agregados para el analista (CR-010). Sin coords; conteos descriptivos (gate #1)."""

    por_estado_revision: dict[str, int]
    por_municipio: dict[str, int]
    por_nivel_g4: dict[str, int]
    # CR-036: desgloses de la dimensión geográfica ahora que el dataset es multi-estado.
    # `por_estado` es nuevo. `por_municipio` conserva su forma (nombre → conteo) por compatibilidad,
    # pero **su clave es ambigua entre estados** ("Jesús María" existe en Aguascalientes, Jalisco y
    # Nayarit): `por_municipio_cve` es la versión desambiguada, con clave "cve_ent:cve_mun", y es la
    # que debe usar cualquier consumidor nuevo.
    por_estado: dict[str, int] = {}
    por_municipio_cve: dict[str, int] = {}
    total: int


# --- Geografía derivada (CR-036) ---


class GeoResolucion(BaseModel):
    """Respuesta de ``GET /geo/resolve``: a qué municipio pertenece un punto.

    Es informativa para el cliente (le permite MOSTRAR el lugar antes de enviar). No es la que se
    guarda: el servidor vuelve a resolver al recibir el POST, siempre.
    """

    estado: str | None = None
    municipio: str | None = None
    cve_ent: str | None = None
    cve_mun: str | None = None
    resuelto: bool = False


class GeoEstado(BaseModel):
    cve_ent: str
    estado: str


class GeoMunicipio(BaseModel):
    cve_ent: str
    cve_mun: str
    estado: str
    municipio: str


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
    """Evidencia de participación del voluntario (en pantalla). Descriptiva (gate #1), sin PII.

    CR-026: ``capturas`` pasó a contar solo observaciones **confirmadas** (es lo que la app
    presenta) y se agregó ``capturas_totales`` con el total crudo subido. ``horas_totales`` sigue
    calculándose y viajando aunque la app ya no la pinte: es dato de análisis, no evidencia de campo.
    """

    capturas: int  # confirmadas (CR-026)
    capturas_totales: int  # total subido, sin filtrar por revisión
    # CR-030: aceptadas (sin revisar). La app lo deducía restando `capturas_totales - capturas`, resta
    # que contaba las rechazadas como si siguieran en cola.
    en_revision: int = 0
    horas_totales: float
    sesiones: int
    primera: datetime | None
    ultima: datetime | None


class VerdictResponse(BaseModel):
    observation_id: uuid.UUID
    estado_revision: str
    message: str
    # CR-029: True ⇒ el veredicto era igual al estado actual, así que NO se escribió en el log
    # append-only. Permite a la consola decir "ya estaba así" en vez de fingir que cambió algo.
    sin_cambio: bool = False


class ReviewStats(BaseModel):
    """Conteos por estado_revision + throughput de revisión (Monitor del analista)."""

    aceptadas: int
    confirmadas: int
    rechazadas: int
    total: int
    pendientes_de_revision: int  # = aceptadas (aún sin veredicto humano)
    revisiones_totales: int  # filas en human_review (EVENTOS, no observaciones)
    # CR-029: observaciones DISTINTAS con al menos un veredicto. Sin esto, el Monitor mostraba
    # `total` (observaciones) junto a `revisiones_totales` (eventos) y la diferencia parecía un bug.
    observaciones_revisadas: int


# --- Reportar un problema (CR-019) ---


class ProblemReportCreate(BaseModel):
    """Reporte de problema del voluntario (CR-019). Diagnóstico SIN PII (gate #2).

    Todos los campos son opcionales (un reporte mínimo es válido); el backend NUNCA pide
    email/nombre/teléfono. ``context`` distingue el origen (p.ej. 'camera'/'general').
    """

    context: str | None = None
    message: str | None = None
    error_detail: str | None = None
    user_agent: str | None = None
    platform: str | None = None
    app_version: str | None = None


class ProblemReportOut(BaseModel):
    """Reporte tal como lo ve el administrador (CR-019). ``handle`` seudónimo o None (anónimo)."""

    id: uuid.UUID
    created_at: datetime
    status: str
    handle: str | None
    context: str | None
    message: str | None
    error_detail: str | None
    user_agent: str | None
    platform: str | None
    app_version: str | None


class ProblemReportStatusIn(BaseModel):
    """El administrador mueve el reporte entre 'nuevo'/'visto'/'resuelto' (CR-019)."""

    status: Literal["nuevo", "visto", "resuelto"]
