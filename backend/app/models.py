"""Modelo de datos PostGIS (materializa `docs/data-model/postgis-model.md`).

Mapeo 1:1 con el DDL de referencia. Gates relevantes:
- Gate #2 (sin PII): `account` NO tiene email/teléfono/nombre; solo handle + recovery_hash.
- Revisión humana (CR-001, 2026-06-15): `nivel_g4`, `flag_cuscuta`, `flag_danio` son AUTODECLARADOS;
  el backend nunca los "valida". La calidad la decide un humano y se refleja en `estado_revision`
  (`aceptada` por defecto → `confirmada`/`rechazada`). La validación automática (YOLO) queda inactiva
  (gates #8/#9/#10 superados en la bitácora).
- Trazabilidad/auditoría (gate #7): `human_review` es un log append-only (varias filas por
  observación); el estado actual vive en `observation.estado_revision`. `points_ledger` tiene
  UNIQUE(observation_id, kind) → cada recompensa se otorga una sola vez.
"""

from __future__ import annotations

import uuid
from datetime import datetime

from geoalchemy2 import Geography
from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base

ROLES = (
    "voluntario",
    "aliado_firmante",
    "admin_consorcio",
    "administrador",
    "evaluador",
    "analista",
)
# Roles con acceso a la cola de revisión humana (CR-001). `analista` es solo lectura.
REVIEW_ROLES = ("evaluador", "analista", "administrador")
REVIEW_VERDICT_ROLES = ("evaluador", "administrador")  # pueden emitir veredicto
# Estado de revisión humana (CR-001): default 'aceptada'; un humano confirma/rechaza.
ESTADOS_REVISION = ("aceptada", "confirmada", "rechazada")
REVIEW_VERDICTS = ("confirmada", "rechazada")
# Legado de la validación automática YOLO (conservado, inactivo — gate #10 superado).
VALIDATION_STATES = ("pendiente", "valida", "ruido")
NIVELES_G4 = ("sano", "leve", "moderado", "severo")
TAMANIOS = ("pequeno", "mediano", "grande", "no_estimable")
CONTEXTOS = ("campo_abierto", "borde_cultivo", "urbano", "ripario", "otro")


def _uuid_pk():
    # Default tanto en Python (ORM) como en DB (gen_random_uuid, pgcrypto) para que los INSERT
    # por SQL crudo (p.ej. en validation_apply) también obtengan un id (gate #9).
    return mapped_column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=func.gen_random_uuid(),
    )


class Institution(Base):
    """Lista F3 (Q4)."""

    __tablename__ = "institution"

    id: Mapped[uuid.UUID] = _uuid_pk()
    name: Mapped[str] = mapped_column(Text, nullable=False)
    estado: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, nullable=False, default="aprobada")

    __table_args__ = (
        CheckConstraint("status IN ('aprobada','solicitada')", name="ck_institution_status"),
    )


class Account(Base):
    """Cuenta seudonimizada (Q5.D-D1). SIN PII (gate #2)."""

    __tablename__ = "account"

    id: Mapped[uuid.UUID] = _uuid_pk()
    handle: Mapped[str] = mapped_column(Text, unique=True, nullable=False)
    recovery_hash: Mapped[str] = mapped_column(Text, nullable=False)
    role: Mapped[str] = mapped_column(Text, nullable=False, default="voluntario")
    institution_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("institution.id")
    )
    identity_label: Mapped[str] = mapped_column(Text, nullable=False, default="nuevo_observador")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    institution: Mapped[Institution | None] = relationship()

    __table_args__ = (
        CheckConstraint(
            "role IN ('voluntario','aliado_firmante','admin_consorcio',"
            "'administrador','evaluador','analista')",
            name="ck_account_role",
        ),
    )


class Tree(Base):
    """Identidad de árbol por radio 10 m (Q2/R3)."""

    __tablename__ = "tree"

    id: Mapped[uuid.UUID] = _uuid_pk()
    centroid = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False), nullable=False
    )
    estado: Mapped[str | None] = mapped_column(Text)
    municipio: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    __table_args__ = (Index("tree_centroid_gix", "centroid", postgresql_using="gist"),)


class Observation(Base):
    """8 etiquetas de captura (Q2, Q3) + agrupamiento + dimensión geográfica + revisión humana."""

    __tablename__ = "observation"

    id: Mapped[uuid.UUID] = _uuid_pk()
    account_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("account.id"), nullable=False
    )
    handle: Mapped[str] = mapped_column(Text, nullable=False)  # atribución I2 (denormalizado)
    image_ref: Mapped[str] = mapped_column(Text, nullable=False)  # clave StorageProvider; nunca el binario
    # EXIF (cámara nativa; gate #4)
    geom = mapped_column(
        Geography(geometry_type="POINT", srid=4326, spatial_index=False), nullable=False
    )
    captured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    # triple etiqueta M3 (Q3) — AUTODECLARADAS, no validadas (gate #8)
    nivel_g4: Mapped[str] = mapped_column(Text, nullable=False)
    flag_cuscuta: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    flag_danio: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    # campos adicionales V3 (Q2)
    tamanio: Mapped[str | None] = mapped_column(Text)
    contexto: Mapped[str | None] = mapped_column(Text)
    # agrupamiento / serie temporal (R3)
    tree_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("tree.id")
    )
    observation_seq: Mapped[int | None] = mapped_column(Integer)
    # dimensión geográfica (Q8)
    estado: Mapped[str | None] = mapped_column(Text)
    municipio: Mapped[str | None] = mapped_column(Text)
    # revisión humana (CR-001) — 'aceptada' por defecto; un humano la confirma/rechaza.
    estado_revision: Mapped[str] = mapped_column(Text, nullable=False, default="aceptada")
    model_version: Mapped[str | None] = mapped_column(Text)  # legado YOLO (inactivo)
    validated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    __table_args__ = (
        CheckConstraint("nivel_g4 IN ('sano','leve','moderado','severo')", name="ck_obs_nivel"),
        CheckConstraint(
            "tamanio IS NULL OR tamanio IN ('pequeno','mediano','grande','no_estimable')",
            name="ck_obs_tamanio",
        ),
        CheckConstraint(
            "contexto IS NULL OR contexto IN "
            "('campo_abierto','borde_cultivo','urbano','ripario','otro')",
            name="ck_obs_contexto",
        ),
        CheckConstraint(
            "estado_revision IN ('aceptada','confirmada','rechazada')",
            name="ck_obs_estado_revision",
        ),
        Index("observation_geom_gix", "geom", postgresql_using="gist"),
        Index("observation_tree_idx", "tree_id", "captured_at"),
        Index("observation_estado_revision_idx", "estado_revision"),
    )


class HumanReview(Base):
    """Log append-only de revisión humana (CR-001, gate #7).

    Cada veredicto humano (confirmada/rechazada) inserta una fila; pueden existir varias por
    observación (re-revisión). El estado ACTUAL vive en ``observation.estado_revision``; esta tabla
    es la auditoría de **quién** decidió **qué** y **cuándo**.
    """

    __tablename__ = "human_review"

    id: Mapped[uuid.UUID] = _uuid_pk()
    observation_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("observation.id"), nullable=False
    )
    reviewer_account_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("account.id"), nullable=False
    )
    veredicto: Mapped[str] = mapped_column(Text, nullable=False)
    nota: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    __table_args__ = (
        CheckConstraint(
            "veredicto IN ('confirmada','rechazada')", name="ck_human_review_veredicto"
        ),
        Index("human_review_obs_idx", "observation_id", "created_at"),
    )


class ValidationEvent(Base):
    """Idempotencia y auditoría (§6.4). PK por observation_id ⇒ un resultado aplicado por obs.

    LEGADO de la validación automática YOLO (CR-001): la tabla se **conserva** para auditoría
    histórica pero ya **no se escribe** (la frontera §6 quedó inactiva).
    """

    __tablename__ = "validation_event"

    observation_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("observation.id"), primary_key=True
    )
    es_arbol: Mapped[bool] = mapped_column(Boolean, nullable=False)
    parasitos: Mapped[bool] = mapped_column(Boolean, nullable=False)
    veredicto: Mapped[str] = mapped_column(Text, nullable=False)
    score_arbol: Mapped[float | None] = mapped_column(Float)
    score_parasitos: Mapped[float | None] = mapped_column(Float)
    model_version: Mapped[str] = mapped_column(Text, nullable=False)
    applied_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    __table_args__ = (
        CheckConstraint("veredicto IN ('valida','ruido')", name="ck_valevent_veredicto"),
    )


class PointsLedger(Base):
    """Recompensa base/diferida (Q4). UNIQUE(observation_id, kind) ⇒ diferida una sola vez."""

    __tablename__ = "points_ledger"

    id: Mapped[uuid.UUID] = _uuid_pk()
    account_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("account.id"), nullable=False
    )
    observation_id: Mapped[uuid.UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("observation.id")
    )
    kind: Mapped[str] = mapped_column(Text, nullable=False)
    points: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    __table_args__ = (
        CheckConstraint("kind IN ('base','diferida')", name="ck_points_kind"),
        UniqueConstraint("observation_id", "kind", name="uq_points_obs_kind"),
    )


class AdminBoundary(Base):
    """Límites administrativos para el join geográfico (Q8). Cargados por separado (opcional)."""

    __tablename__ = "admin_boundary"

    id: Mapped[uuid.UUID] = _uuid_pk()
    estado: Mapped[str | None] = mapped_column(Text)
    municipio: Mapped[str | None] = mapped_column(Text)
    geom = mapped_column(
        Geography(geometry_type="MULTIPOLYGON", srid=4326, spatial_index=False), nullable=False
    )

    __table_args__ = (Index("admin_boundary_geom_gix", "geom", postgresql_using="gist"),)


class OrganizationalIndicator(Base):
    """Indicadores organizacionales Q6 — capturados MANUALMENTE en la web admin (amendment Q6).

    No se calculan automáticamente (mesas formales, eventos W3, menciones mediáticas): los teclea
    el ``admin_consorcio``. Alimentan el mismo dashboard público.
    """

    __tablename__ = "organizational_indicator"

    id: Mapped[uuid.UUID] = _uuid_pk()
    key: Mapped[str] = mapped_column(Text, nullable=False)
    value: Mapped[float] = mapped_column(Float, nullable=False)
    estado: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class Snapshot(Base):
    """Snapshot trimestral del dataset público (Q5.B, cadencia trimestral)."""

    __tablename__ = "snapshot"

    id: Mapped[uuid.UUID] = _uuid_pk()
    quarter: Mapped[str] = mapped_column(Text, nullable=False)  # "Qn" / "2026-Q2"
    observations_total: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
