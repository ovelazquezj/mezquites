"""CR-019 (2026-06-28): "Reportar un problema" — tabla ``problem_report``.

Endpoint público (gate #3, sin gating) para que los voluntarios reporten fallas (cámara, etc.) y el
administrador las consulte para depurar. Gate #2 (sin PII): solo metadatos técnicos de diagnóstico +
handle seudónimo (nullable); nunca email/nombre/teléfono. ``account_id``/``handle`` nullable ⇒
reportes anónimos permitidos.

Revision ID: 0006_problem_reports
Revises: 0005_cr010_sesiones_veredicto
Create Date: 2026-06-28
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0006_problem_reports"
down_revision = "0005_cr010_sesiones_veredicto"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "problem_report",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "account_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("account.id"),
            nullable=True,
        ),
        sa.Column("handle", sa.Text(), nullable=True),
        sa.Column("user_agent", sa.Text(), nullable=True),
        sa.Column("platform", sa.Text(), nullable=True),
        sa.Column("app_version", sa.Text(), nullable=True),
        sa.Column("context", sa.Text(), nullable=True),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column("error_detail", sa.Text(), nullable=True),
        sa.Column("status", sa.Text(), nullable=False, server_default="nuevo"),
        sa.CheckConstraint(
            "status IN ('nuevo','visto','resuelto')", name="ck_problem_report_status"
        ),
    )
    op.create_index("problem_report_created_idx", "problem_report", ["created_at"])


def downgrade() -> None:
    op.drop_index("problem_report_created_idx", table_name="problem_report")
    op.drop_table("problem_report")
