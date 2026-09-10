"""CR-041 (2026-09-10): notas escritas sobre una observación, independientes del veredicto.

Origen: el ``analista`` es solo lectura y no puede anotar nada. Las notas existen desde CR-001
(``human_review.nota``, 1 891 en producción sobre 6 367 filas de revisión), pero van **pegadas a un
veredicto**, cuyo endpoint está restringido a evaluador/administrador. Para dejar una nota, el
analista tendría que emitir un veredicto — y desde CR-026 el veredicto decide qué sale en el mapa
público, cuánto suma el voluntario y qué insignias gana. **Una anotación no puede tener ese efecto.**

Tabla nueva y no una columna en ``human_review``: esa tabla exige ``veredicto`` NOT NULL con un
CHECK de tres valores, así que una nota sin veredicto obligaría a relajar el CHECK y a inventar un
veredicto falso, y contaminaría el contador de "veredictos emitidos" del Monitor, que CR-029 dejó
honesto tras el incidente de las re-revisiones. Separadas, el log de veredictos queda intacto.

Tres decisiones de forma:

- **Append-only** (gate #7, mismo criterio que ``human_review``): no hay endpoint de edición ni de
  borrado, así que la tabla no necesita ``updated_at`` ni bandera de baja. Lo escrito queda.
- **CHECK sobre el texto recortado.** ``char_length(btrim(texto)) BETWEEN 1 AND 2000``: una nota de
  solo espacios no dice nada (y pasaría un simple ``<> ''``), y sin techo el campo libre es una
  puerta abierta a pegar un documento entero. El esquema pydantic valida lo mismo para dar un 422
  limpio; el CHECK está para que la garantía sea de la base, no del framework.
- **``author_account_id`` NOT NULL, séptima FK a ``account``.** El borrado ARCO la repunta a la
  cuenta centinela en su misma transacción (``routers/accounts.py``); sin eso, eliminar a un
  analista con notas fallaría por FK con un 500, justo para las cuentas más activas.

Revision ID: 0010_notas_observacion
Revises: 0009_geografia_derivada
Create Date: 2026-09-10
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

revision = "0010_notas_observacion"
down_revision = "0009_geografia_derivada"
branch_labels = None
depends_on = None

TABLA = "observation_note"
CK_TEXTO = "ck_observation_note_texto"
IDX_OBS = "observation_note_obs_idx"


def upgrade() -> None:
    op.create_table(
        TABLA,
        sa.Column(
            "id",
            PG_UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "observation_id",
            PG_UUID(as_uuid=True),
            sa.ForeignKey("observation.id"),
            nullable=False,
        ),
        sa.Column(
            "author_account_id",
            PG_UUID(as_uuid=True),
            sa.ForeignKey("account.id"),
            nullable=False,
        ),
        sa.Column("texto", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint("char_length(btrim(texto)) BETWEEN 1 AND 2000", name=CK_TEXTO),
    )
    # El detalle lee las notas de una observación en orden cronológico: ese es el índice.
    op.execute(f"CREATE INDEX {IDX_OBS} ON {TABLA} (observation_id, created_at)")


def downgrade() -> None:
    op.execute(f"DROP INDEX IF EXISTS {IDX_OBS}")
    op.drop_table(TABLA)
