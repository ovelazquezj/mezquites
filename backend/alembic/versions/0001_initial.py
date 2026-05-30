"""Migración inicial: extensión PostGIS + modelo de datos (postgis-model.md).

Habilita las extensiones ``postgis`` y ``pgcrypto`` (para gen_random_uuid si se usara en DB) y
crea todas las tablas núcleo con sus constraints, índices GiST y reglas de idempotencia (gate #9).

Revision ID: 0001_initial
Revises:
Create Date: 2026-05-30
"""

from __future__ import annotations

import geoalchemy2
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Extensiones (gate #6 dev/QA: la imagen postgis/postgis ya las trae disponibles).
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    op.create_table(
        "institution",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("estado", sa.Text(), nullable=True),
        sa.Column("status", sa.Text(), nullable=False, server_default="aprobada"),
        sa.CheckConstraint("status IN ('aprobada','solicitada')", name="ck_institution_status"),
    )

    op.create_table(
        "account",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("handle", sa.Text(), nullable=False, unique=True),
        sa.Column("recovery_hash", sa.Text(), nullable=False),
        sa.Column("role", sa.Text(), nullable=False, server_default="voluntario"),
        sa.Column(
            "institution_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("institution.id"),
            nullable=True,
        ),
        sa.Column("identity_label", sa.Text(), nullable=False, server_default="nuevo_observador"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint(
            "role IN ('voluntario','aliado_firmante','admin_consorcio')", name="ck_account_role"
        ),
    )

    op.create_table(
        "tree",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "centroid",
            geoalchemy2.Geography(geometry_type="POINT", srid=4326, spatial_index=False),
            nullable=False,
        ),
        sa.Column("estado", sa.Text(), nullable=True),
        sa.Column("municipio", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    op.create_table(
        "observation",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "account_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("account.id"),
            nullable=False,
        ),
        sa.Column("handle", sa.Text(), nullable=False),
        sa.Column("image_ref", sa.Text(), nullable=False),
        sa.Column(
            "geom",
            geoalchemy2.Geography(geometry_type="POINT", srid=4326, spatial_index=False),
            nullable=False,
        ),
        sa.Column("captured_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("nivel_g4", sa.Text(), nullable=False),
        sa.Column("flag_cuscuta", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("flag_danio", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("tamanio", sa.Text(), nullable=True),
        sa.Column("contexto", sa.Text(), nullable=True),
        sa.Column("tree_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tree.id"), nullable=True),
        sa.Column("observation_seq", sa.Integer(), nullable=True),
        sa.Column("estado", sa.Text(), nullable=True),
        sa.Column("municipio", sa.Text(), nullable=True),
        sa.Column("validation_state", sa.Text(), nullable=False, server_default="pendiente"),
        sa.Column("model_version", sa.Text(), nullable=True),
        sa.Column("validated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("nivel_g4 IN ('sano','leve','moderado','severo')", name="ck_obs_nivel"),
        sa.CheckConstraint(
            "tamanio IS NULL OR tamanio IN ('pequeno','mediano','grande','no_estimable')",
            name="ck_obs_tamanio",
        ),
        sa.CheckConstraint(
            "contexto IS NULL OR contexto IN "
            "('campo_abierto','borde_cultivo','urbano','ripario','otro')",
            name="ck_obs_contexto",
        ),
        sa.CheckConstraint(
            "validation_state IN ('pendiente','valida','ruido')", name="ck_obs_validation_state"
        ),
    )
    op.create_index("observation_tree_idx", "observation", ["tree_id", "captured_at"])

    op.create_table(
        "validation_event",
        sa.Column(
            "observation_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("observation.id"),
            primary_key=True,
        ),
        sa.Column("es_arbol", sa.Boolean(), nullable=False),
        sa.Column("parasitos", sa.Boolean(), nullable=False),
        sa.Column("veredicto", sa.Text(), nullable=False),
        sa.Column("score_arbol", sa.Float(), nullable=True),
        sa.Column("score_parasitos", sa.Float(), nullable=True),
        sa.Column("model_version", sa.Text(), nullable=False),
        sa.Column("applied_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("veredicto IN ('valida','ruido')", name="ck_valevent_veredicto"),
    )

    op.create_table(
        "points_ledger",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column(
            "account_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("account.id"), nullable=False
        ),
        sa.Column(
            "observation_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("observation.id"),
            nullable=True,
        ),
        sa.Column("kind", sa.Text(), nullable=False),
        sa.Column("points", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("kind IN ('base','diferida')", name="ck_points_kind"),
        sa.UniqueConstraint("observation_id", "kind", name="uq_points_obs_kind"),
    )

    op.create_table(
        "admin_boundary",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("estado", sa.Text(), nullable=True),
        sa.Column("municipio", sa.Text(), nullable=True),
        sa.Column(
            "geom",
            geoalchemy2.Geography(geometry_type="MULTIPOLYGON", srid=4326, spatial_index=False),
            nullable=False,
        ),
    )

    op.create_table(
        "organizational_indicator",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("key", sa.Text(), nullable=False),
        sa.Column("value", sa.Float(), nullable=False),
        sa.Column("estado", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    op.create_table(
        "snapshot",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("quarter", sa.Text(), nullable=False),
        sa.Column("observations_total", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    # Índices GiST geoespaciales (GeoAlchemy2 los crea automáticamente vía evento, pero
    # los declaramos explícitos para que la migración sea autónoma).
    op.execute("CREATE INDEX IF NOT EXISTS tree_centroid_gix ON tree USING gist (centroid)")
    op.execute("CREATE INDEX IF NOT EXISTS observation_geom_gix ON observation USING gist (geom)")
    op.execute(
        "CREATE INDEX IF NOT EXISTS admin_boundary_geom_gix ON admin_boundary USING gist (geom)"
    )


def downgrade() -> None:
    for tbl in (
        "snapshot",
        "organizational_indicator",
        "admin_boundary",
        "points_ledger",
        "validation_event",
        "observation",
        "tree",
        "account",
        "institution",
    ):
        op.drop_table(tbl)
