"""Revisión humana (CR-001, 2026-06-15): retiro de la validación automática YOLO.

Cambios:
- ``account``: amplía el CHECK de rol con ``administrador``/``evaluador``/``analista``.
- ``observation``: renombra ``validation_state`` → ``estado_revision``; sustituye el CHECK
  ``ck_obs_validation_state`` por ``ck_obs_estado_revision IN ('aceptada','confirmada','rechazada')``
  con default ``'aceptada'``; índice por ``estado_revision``. Los datos de dev son desechables, así
  que el remapeo de valores antiguos (pendiente/valida → aceptada; ruido → rechazada) es best-effort.
- Tabla nueva ``human_review`` (log append-only de veredictos, gate #7).
- ``validation_event`` se **conserva** (auditoría histórica) pero deja de escribirse.

Revision ID: 0002_revision_humana
Revises: 0001_initial
Create Date: 2026-06-15
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0002_revision_humana"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- account: roles nuevos en el CHECK (CR-001) ---
    op.drop_constraint("ck_account_role", "account", type_="check")
    op.create_check_constraint(
        "ck_account_role",
        "account",
        "role IN ('voluntario','aliado_firmante','admin_consorcio',"
        "'administrador','evaluador','analista')",
    )

    # --- observation: validation_state → estado_revision ---
    # Quita el CHECK viejo antes de tocar valores/columna.
    op.drop_constraint("ck_obs_validation_state", "observation", type_="check")
    # Renombra la columna conservando los datos (dev desechable; remapeo best-effort abajo).
    op.alter_column("observation", "validation_state", new_column_name="estado_revision")
    # Remapea valores del modelo viejo al nuevo (best-effort; dev se arranca limpio en la práctica).
    op.execute(
        "UPDATE observation SET estado_revision = "
        "CASE estado_revision "
        "WHEN 'ruido' THEN 'rechazada' "
        "WHEN 'valida' THEN 'confirmada' "
        "ELSE 'aceptada' END"
    )
    # Nuevo default y CHECK.
    op.alter_column(
        "observation",
        "estado_revision",
        server_default="aceptada",
        existing_type=sa.Text(),
        existing_nullable=False,
    )
    op.create_check_constraint(
        "ck_obs_estado_revision",
        "observation",
        "estado_revision IN ('aceptada','confirmada','rechazada')",
    )
    op.create_index(
        "observation_estado_revision_idx", "observation", ["estado_revision"]
    )

    # --- human_review: log append-only de veredictos humanos (gate #7) ---
    op.create_table(
        "human_review",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "observation_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("observation.id"),
            nullable=False,
        ),
        sa.Column(
            "reviewer_account_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("account.id"),
            nullable=False,
        ),
        sa.Column("veredicto", sa.Text(), nullable=False),
        sa.Column("nota", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "veredicto IN ('confirmada','rechazada')", name="ck_human_review_veredicto"
        ),
    )
    op.create_index(
        "human_review_obs_idx", "human_review", ["observation_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_index("human_review_obs_idx", table_name="human_review")
    op.drop_table("human_review")

    op.drop_index("observation_estado_revision_idx", table_name="observation")
    op.drop_constraint("ck_obs_estado_revision", "observation", type_="check")
    op.execute(
        "UPDATE observation SET estado_revision = "
        "CASE estado_revision "
        "WHEN 'rechazada' THEN 'ruido' "
        "WHEN 'confirmada' THEN 'valida' "
        "ELSE 'pendiente' END"
    )
    op.alter_column(
        "observation",
        "estado_revision",
        server_default="pendiente",
        existing_type=sa.Text(),
        existing_nullable=False,
    )
    op.alter_column("observation", "estado_revision", new_column_name="validation_state")
    op.create_check_constraint(
        "ck_obs_validation_state",
        "observation",
        "validation_state IN ('pendiente','valida','ruido')",
    )

    op.drop_constraint("ck_account_role", "account", type_="check")
    op.create_check_constraint(
        "ck_account_role",
        "account",
        "role IN ('voluntario','aliado_firmante','admin_consorcio')",
    )
