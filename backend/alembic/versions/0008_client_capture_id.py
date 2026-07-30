"""CR-031 (2026-07-29): submit idempotente — ``client_capture_id`` por captura.

Origen: al hacer que la app guarde capturas sin conexión y las reintente, aparece un riesgo que hoy
no existe. Si el POST **llega** al servidor, se guarda, y la respuesta se pierde de vuelta (red de
campo), el reintento crearía una **segunda observación del mismo árbol**. Y como ``assign_tree``
crea siempre un árbol nuevo (CR-022), serían **dos mezquites distintos en el mapa público** — sin
ningún nombre que delate la copia, a diferencia de las instituciones duplicadas de CR-028, así que
nadie las volvería a unir.

La app genera un UUID **en el momento de capturar** y lo repite en todos los reintentos de esa misma
foto. El índice único convierte "no duplicar" en una garantía de la base y no en una promesa del
código de aplicación.

Dos decisiones de forma:

- **La columna es nullable a propósito.** Las observaciones ya existentes (331 al escribir esto) no
  tienen id de captura, y un cliente anterior a CR-031 sigue subiendo sin él. El índice es
  **parcial** (``WHERE client_capture_id IS NOT NULL``): en Postgres varios ``NULL`` no chocan entre
  sí, pero decirlo explícitamente evita indexar lo que no sirve y documenta la intención.
- **La unicidad es por cuenta, no global.** Una colisión de UUID entre dos cuentas es
  prácticamente imposible; acotarla a ``account_id`` impide además que un id ajeno pueda reclamar la
  observación de otra cuenta.

Revision ID: 0008_client_capture_id
Revises: 0007_institucion_nombre_unico
Create Date: 2026-07-29
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

revision = "0008_client_capture_id"
down_revision = "0007_institucion_nombre_unico"
branch_labels = None
depends_on = None

INDEX_NAME = "ux_observation_client_capture"


def upgrade() -> None:
    op.add_column(
        "observation",
        sa.Column("client_capture_id", PG_UUID(as_uuid=True), nullable=True),
    )
    # Índice PARCIAL: solo las filas que traen id de captura. Las históricas quedan fuera.
    op.execute(
        f"CREATE UNIQUE INDEX {INDEX_NAME} ON observation (account_id, client_capture_id) "
        "WHERE client_capture_id IS NOT NULL"
    )


def downgrade() -> None:
    op.execute(f"DROP INDEX IF EXISTS {INDEX_NAME}")
    op.drop_column("observation", "client_capture_id")
