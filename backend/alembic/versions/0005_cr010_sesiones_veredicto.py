"""CR-010 (2026-06-17): sesiones de participación + veredicto 'aceptada'.

Cambios:
- Tabla nueva ``participation_session`` (#7): evidencia por tiempo de sesión del voluntario. Gate #2
  (sin PII): solo ``account_id`` (seudónimo) + tiempos.
- ``human_review.veredicto`` ahora admite ``aceptada`` (revertir a pendiente de revisión) además de
  ``confirmada``/``rechazada``: se reemplaza el CHECK ``ck_human_review_veredicto``.
  (``observation.estado_revision`` ya permitía 'aceptada' desde 0002; no se toca.)

Revision ID: 0005_cr010_sesiones_veredicto
Revises: 0004_arco_cancelacion
Create Date: 2026-06-17
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0005_cr010_sesiones_veredicto"
down_revision = "0004_arco_cancelacion"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- Sesiones de participación (#7) ---
    op.create_table(
        "participation_session",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "account_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("account.id"),
            nullable=False,
        ),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "participation_session_account_idx",
        "participation_session",
        ["account_id", "started_at"],
    )

    # --- Veredicto humano admite 'aceptada' (CR-010) ---
    op.drop_constraint("ck_human_review_veredicto", "human_review", type_="check")
    op.create_check_constraint(
        "ck_human_review_veredicto",
        "human_review",
        "veredicto IN ('aceptada','confirmada','rechazada')",
    )


def downgrade() -> None:
    op.drop_constraint("ck_human_review_veredicto", "human_review", type_="check")
    op.create_check_constraint(
        "ck_human_review_veredicto",
        "human_review",
        "veredicto IN ('confirmada','rechazada')",
    )

    op.drop_index("participation_session_account_idx", table_name="participation_session")
    op.drop_table("participation_session")
