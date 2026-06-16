"""Autenticación con identidad real (CR-002, 2026-06-15): cuenta multi-método.

Enmienda ACOTADA del gate #2 (ver bitácora, amendment Q5.D-D1):
- ``account`` pasa a multi-método:
  - ``auth_provider`` Text NOT NULL (``social_google`` | ``password``), default ``social_google``.
  - ``provider_subject`` Text UNIQUE (id opaco de Google ``sub``; sin PII).
  - ``username`` Text UNIQUE + ``password_hash`` Text (roles de backend, hash argon2).
  - ``email`` Text — SOLO ``administrador`` (reset por SMTP). Un CHECK lo impone.
  - ``must_change_password`` Boolean (contraseña temporal de invitación).
  - ``recovery_hash`` pasa a NULLABLE (legado del código de respaldo; arranque limpio).

Arranque limpio (decisión del usuario): las cuentas seudónimas previas se descartan, así que el
remapeo de filas existentes es best-effort (en dev se arranca con DB vacía). Para filas legadas se
asigna ``auth_provider='social_google'`` por defecto.

Revision ID: 0003_auth_identidad
Revises: 0002_revision_humana
Create Date: 2026-06-15
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0003_auth_identidad"
down_revision = "0002_revision_humana"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- Nuevas columnas de auth multi-método (CR-002) ---
    op.add_column(
        "account",
        sa.Column(
            "auth_provider",
            sa.Text(),
            nullable=False,
            server_default="social_google",
        ),
    )
    op.add_column("account", sa.Column("provider_subject", sa.Text(), nullable=True))
    op.add_column("account", sa.Column("username", sa.Text(), nullable=True))
    op.add_column("account", sa.Column("password_hash", sa.Text(), nullable=True))
    op.add_column("account", sa.Column("email", sa.Text(), nullable=True))
    op.add_column(
        "account",
        sa.Column(
            "must_change_password",
            sa.Boolean(),
            nullable=False,
            server_default="false",
        ),
    )

    # recovery_hash deja de ser obligatorio (arranque limpio; el código de respaldo es legado).
    op.alter_column(
        "account",
        "recovery_hash",
        existing_type=sa.Text(),
        nullable=True,
    )

    # --- Restricciones de unicidad e integridad ---
    op.create_unique_constraint("uq_account_provider_subject", "account", ["provider_subject"])
    op.create_unique_constraint("uq_account_username", "account", ["username"])
    op.create_check_constraint(
        "ck_account_auth_provider",
        "account",
        "auth_provider IN ('social_google','password')",
    )
    # Gate #2 acotado: SOLO administrador puede portar email.
    op.create_check_constraint(
        "ck_account_email_only_admin",
        "account",
        "email IS NULL OR role = 'administrador'",
    )


def downgrade() -> None:
    op.drop_constraint("ck_account_email_only_admin", "account", type_="check")
    op.drop_constraint("ck_account_auth_provider", "account", type_="check")
    op.drop_constraint("uq_account_username", "account", type_="unique")
    op.drop_constraint("uq_account_provider_subject", "account", type_="unique")

    # Revertir recovery_hash a NOT NULL (best-effort; rellena vacíos para no romper el constraint).
    op.execute("UPDATE account SET recovery_hash = '' WHERE recovery_hash IS NULL")
    op.alter_column(
        "account",
        "recovery_hash",
        existing_type=sa.Text(),
        nullable=False,
    )

    op.drop_column("account", "must_change_password")
    op.drop_column("account", "email")
    op.drop_column("account", "password_hash")
    op.drop_column("account", "username")
    op.drop_column("account", "provider_subject")
    op.drop_column("account", "auth_provider")
