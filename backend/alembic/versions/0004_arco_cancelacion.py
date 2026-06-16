"""ARCO — Cancelación de cuenta (CR-006, 2026-06-16): eliminación + anonimización.

Refuerza el gate #2 (tras eliminar no queda PII de la persona) y usa el gate #7 (auditoría sin PII).

Cambios:
- Tabla nueva ``account_deletion``: auditoría append-only de cancelaciones **sin PII** (id opaco de
  la cuenta eliminada, quién la ejecutó, rol, motivo, conteo, fecha). ``deleted_account_id`` NO es
  FK (la fila de `account` ya no existe al auditar).
- **Cuenta centinela "eliminada"** (id/handle fijos, sin PII): destino al que se repuntan las
  observaciones/puntos/revisiones de cuentas canceladas, para conservar el dato ecológico rompiendo
  el vínculo a la persona. Se siembra idempotentemente.

Revision ID: 0004_arco_cancelacion
Revises: 0003_auth_identidad
Create Date: 2026-06-16
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0004_arco_cancelacion"
down_revision = "0003_auth_identidad"
branch_labels = None
depends_on = None

# Espejo de models.SENTINEL_ACCOUNT_ID / SENTINEL_HANDLE (sin importar la app en la migración).
SENTINEL_ACCOUNT_ID = "00000000-0000-0000-0000-0000000de1e7"
SENTINEL_HANDLE = "cuenta-eliminada"


def upgrade() -> None:
    op.create_table(
        "account_deletion",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("deleted_account_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "executed_by_account_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("account.id"),
            nullable=False,
        ),
        sa.Column("deleted_role", sa.Text(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column(
            "observations_anonymized", sa.Integer(), nullable=False, server_default="0"
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("account_deletion_created_idx", "account_deletion", ["created_at"])

    # Cuenta centinela "eliminada" (idempotente, sin PII).
    op.execute(
        sa.text(
            "INSERT INTO account (id, handle, auth_provider, role, identity_label) "
            "VALUES (:id, :handle, 'social_google', 'voluntario', 'cuenta_eliminada') "
            "ON CONFLICT (id) DO NOTHING"
        ).bindparams(id=SENTINEL_ACCOUNT_ID, handle=SENTINEL_HANDLE)
    )


def downgrade() -> None:
    op.drop_index("account_deletion_created_idx", table_name="account_deletion")
    op.drop_table("account_deletion")
    op.execute(
        sa.text("DELETE FROM account WHERE id = :id").bindparams(id=SENTINEL_ACCOUNT_ID)
    )
