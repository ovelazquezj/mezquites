"""CR-028 (2026-07-28): una institución por nombre — índice único sobre el nombre canónico.

Origen: en producción convivían dos "Global University" (una con estado, otra sin él) porque nada
—ni la tabla, ni la API, ni la app— comprobaba si el nombre ya existía. Esta migración pone la
última línea de defensa en la base: dos nombres que solo difieren en acentos, mayúsculas o espacios
no pueden coexistir.

⚠️ **Si ya hay duplicados, esta migración se detiene y los enumera.** Es deliberado: fusionar dos
instituciones implica decidir cuál sobrevive y repuntar las cuentas que cuelgan de la otra, y eso
es una decisión de datos, no algo que una migración deba adivinar. Fusiónalos antes de reintentar.

La expresión del índice se importa de ``backend.app.institution_names`` (que ``env.py`` ya deja
importable) en vez de copiarse: si la regla y el índice se separaran, la unicidad dejaría de
significar lo mismo en la base y en el código.

Revision ID: 0007_institucion_nombre_unico
Revises: 0006_problem_reports
Create Date: 2026-07-28
"""

from __future__ import annotations

from alembic import op

from backend.app.institution_names import NORMALIZED_NAME_INDEX, NORMALIZED_NAME_SQL

revision = "0007_institucion_nombre_unico"
down_revision = "0006_problem_reports"
branch_labels = None
depends_on = None


def _abortar_si_hay_duplicados() -> None:
    filas = (
        op.get_bind()
        .exec_driver_sql(
            f"""
            SELECT {NORMALIZED_NAME_SQL} AS canonico,
                   count(*) AS veces,
                   string_agg(name || ' [' || status || ']', ' | ' ORDER BY name) AS variantes
            FROM institution
            GROUP BY 1
            HAVING count(*) > 1
            ORDER BY 2 DESC
            """
        )
        .fetchall()
    )
    if not filas:
        return
    detalle = "\n".join(f"  - {r.canonico!r} ×{r.veces}: {r.variantes}" for r in filas)
    raise RuntimeError(
        "No se puede crear el índice único: ya hay instituciones duplicadas.\n"
        f"{detalle}\n"
        "Fusiónalas antes de migrar (repunta account.institution_id a la que se conserva y borra "
        "la otra); account.institution_id es la única FK que apunta a institution."
    )


def upgrade() -> None:
    _abortar_si_hay_duplicados()
    op.execute(f"CREATE UNIQUE INDEX {NORMALIZED_NAME_INDEX} ON institution (({NORMALIZED_NAME_SQL}))")


def downgrade() -> None:
    op.execute(f"DROP INDEX IF EXISTS {NORMALIZED_NAME_INDEX}")
