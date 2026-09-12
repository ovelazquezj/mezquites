"""CR-042 (2026-09-12): descripción del indicador organizacional + índice de lectura.

Origen: la pantalla "Indicadores" de la consola solo sabía **escribir**. Al revisar por qué los
capturados "desaparecían" salieron tres fallas, y dos son de datos:

- **``estado`` se usaba como descripción.** Es un filtro geográfico (comparte nombre y semántica con
  ``observation.estado``: el panel público filtra por él), pero la consola lo pedía como texto libre
  bajo la etiqueta "Estado (opcional)" y ahí se tecleaba lo que había pasado ("Visita Rotaract
  Ejecutivo"). Resultado: el filtro no casaba con ninguna entidad y el relato del evento vivía en un
  campo que nadie mostraba como tal. Esta migración abre ``descripcion`` para que cada campo haga su
  trabajo; ``estado`` **se conserva** (no se borra ni se renombra) y a partir de ahora la consola lo
  llena con una de las 32 entidades o con "Otro".
- **El panel público contaba de menos.** La agregación era ``{key: value}`` sobre un SELECT sin
  ``GROUP BY``, así que dos filas de la misma ``key`` se pisaban: dos menciones en medios de valor 1
  se publicaban como **1**. El arreglo es ``SUM(value) … GROUP BY key`` en ``indicators.py`` —no hay
  cambio de esquema para eso—, y el índice que se crea aquí es justo el que esa agrupación y la
  lista de la consola (por ``key``, más reciente primero) necesitan.

Dos notas de forma:

- **``descripcion`` nullable y sin CHECK.** Las filas históricas no la tienen y no se puede inventar
  lo que pasó; el largo máximo (500) se valida en el esquema pydantic, donde un texto de más da un
  422 legible. A diferencia de las notas de CR-041 —append-only, donde la base es la última línea de
  defensa— aquí el campo es editable por PATCH, así que una restricción de base solo convertiría un
  422 en un 500.
- **``estado`` NO pasa a NOT NULL.** Hacerlo exigiría inventar una entidad para las filas ya
  capturadas (que precisamente traen texto libre en ese campo), y perdería la única evidencia de qué
  se quiso decir. La obligatoriedad vive en la API, sobre las capturas nuevas.

Revision ID: 0011_indicadores_descripcion
Revises: 0010_notas_observacion
Create Date: 2026-09-12
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0011_indicadores_descripcion"
down_revision = "0010_notas_observacion"
branch_labels = None
depends_on = None

TABLA = "organizational_indicator"
IDX_KEY = "organizational_indicator_key_idx"


def upgrade() -> None:
    op.add_column(TABLA, sa.Column("descripcion", sa.Text(), nullable=True))
    op.execute(f"CREATE INDEX IF NOT EXISTS {IDX_KEY} ON {TABLA} (key, created_at)")


def downgrade() -> None:
    op.execute(f"DROP INDEX IF EXISTS {IDX_KEY}")
    op.drop_column(TABLA, "descripcion")
