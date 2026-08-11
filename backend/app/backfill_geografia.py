"""Backfill de la geografía derivada — CR-036.

Re-deriva ``estado``/``municipio`` y llena ``cve_ent``/``cve_mun`` de las observaciones
**históricas**, resolviendo cada punto contra ``admin_boundary``. Es la contraparte del cambio de
precedencia: sin esto, las capturas nuevas quedarían bien y las viejas conservarían para siempre la
etiqueta que puso el dropdown de la app.

**Por qué hace falta.** El valor histórico no salió de un polígono sino de "el centroide más cercano
entre 11", y ese método falla de dos maneras: cruza líneas estatales (39 capturas de Zacatecas
etiquetadas "Calvillo") y también se equivoca *dentro* del estado, que es el caso mayoritario y el
que nadie podía ver (196 observaciones del municipio de Aguascalientes contadas como Jesús María).

**Se corre en dos pasos, siempre.** Primero ``--simulacro``, que calcula dentro de una transacción
que se revierte y reporta exactamente qué se movería. Solo después ``--aplicar --esperado N``, que
**aborta si el número no coincide** con el del simulacro: entre uno y otro pueden haber entrado
capturas nuevas, y escribir a ciegas sobre un conteo que ya no es el que se revisó sería justo el
tipo de descuido que este CR existe para corregir.

Uso (en la VM, dentro del contenedor del API)::

    docker compose --env-file .env.prod exec api python -m backend.app.backfill_geografia --simulacro
    docker compose --env-file .env.prod exec api python -m backend.app.backfill_geografia --aplicar --esperado 235

Notas de gates:
- **Gate #7 intacto:** ``human_review`` no se toca. ``estado``/``municipio`` es metadato derivado de
  la coordenada, no historia de revisión; corregirlo no reescribe ningún veredicto.
- **Gate #9 intacto:** no se altera ningún ``estado_revision``. El total de observaciones tampoco
  cambia — esto re-etiqueta, no borra ni crea.
"""

from __future__ import annotations

import argparse
import sys

from sqlalchemy import text
from sqlalchemy.orm import Session

from .db import get_sessionmaker

# Cada observación contra el municipio que la contiene. `LEFT JOIN LATERAL` para no perder las que
# no caen en ningún polígono: hay que poder CONTARLAS, no que desaparezcan de la comparación.
_SQL_RESUELTO = """
CREATE TEMPORARY TABLE _backfill_geo ON COMMIT DROP AS
SELECT o.id,
       o.estado    AS estado_actual,
       o.municipio AS municipio_actual,
       b.estado    AS estado_nuevo,
       b.municipio AS municipio_nuevo,
       b.cve_ent,
       b.cve_mun
FROM observation o
LEFT JOIN LATERAL (
    SELECT estado, municipio, cve_ent, cve_mun
    FROM admin_boundary
    WHERE ST_Intersects(geom, o.geom)
    ORDER BY cve_ent, cve_mun
    LIMIT 1
) b ON TRUE
"""

_SQL_CONTEOS = """
SELECT count(*)                                                        AS total,
       count(*) FILTER (WHERE estado_nuevo IS NULL)                    AS sin_resolver,
       count(*) FILTER (
           WHERE estado_nuevo IS NOT NULL
             AND (estado_nuevo, municipio_nuevo)
                 IS DISTINCT FROM (estado_actual, municipio_actual)
       )                                                               AS cambian
FROM _backfill_geo
"""

_SQL_DESGLOSE = """
SELECT coalesce(estado_actual, '(sin dato)') || ' / ' || coalesce(municipio_actual, '(sin dato)') AS antes,
       estado_nuevo || ' / ' || municipio_nuevo                                                   AS despues,
       count(*)                                                                                   AS n
FROM _backfill_geo
WHERE estado_nuevo IS NOT NULL
  AND (estado_nuevo, municipio_nuevo) IS DISTINCT FROM (estado_actual, municipio_actual)
GROUP BY 1, 2
ORDER BY n DESC
"""

# Solo se escriben las filas que SÍ resolvieron. Una observación fuera de todo polígono conserva lo
# que tenía: el backfill corrige etiquetas equivocadas, no borra las que no puede verificar.
_SQL_APLICAR = """
UPDATE observation o
SET estado = r.estado_nuevo,
    municipio = r.municipio_nuevo,
    cve_ent = r.cve_ent,
    cve_mun = r.cve_mun
FROM _backfill_geo r
WHERE o.id = r.id
  AND r.estado_nuevo IS NOT NULL
"""

# El árbol arrastra la misma dimensión geográfica (se propaga en el submit); si no se corrige aquí,
# `tree` quedaría contradiciendo a `observation`.
_SQL_APLICAR_TREE = """
UPDATE tree t
SET estado = r.estado_nuevo,
    municipio = r.municipio_nuevo
FROM _backfill_geo r
JOIN observation o ON o.id = r.id
WHERE t.id = o.tree_id
  AND r.estado_nuevo IS NOT NULL
"""


def _analizar(db: Session) -> tuple[int, int, int, list[tuple[str, str, int]]]:
    db.execute(text(_SQL_RESUELTO))
    total, sin_resolver, cambian = db.execute(text(_SQL_CONTEOS)).one()
    desglose = [(r[0], r[1], int(r[2])) for r in db.execute(text(_SQL_DESGLOSE)).all()]
    return int(total), int(sin_resolver), int(cambian), desglose


def _reportar(total: int, sin_resolver: int, cambian: int, desglose) -> None:
    print(f"observaciones:      {total}")
    print(f"sin resolver:       {sin_resolver}")
    print(f"cambian:            {cambian}")
    print(f"se quedan igual:    {total - sin_resolver - cambian}")
    if desglose:
        print("\ndesglose de los cambios:")
        for antes, despues, n in desglose:
            print(f"  {n:6d}  {antes}  ->  {despues}")


def main(argv: list[str] | None = None) -> int:  # pragma: no cover - envoltorio CLI
    p = argparse.ArgumentParser(description=__doc__)
    grupo = p.add_mutually_exclusive_group(required=True)
    grupo.add_argument("--simulacro", action="store_true", help="calcula y revierte")
    grupo.add_argument("--aplicar", action="store_true", help="escribe (exige --esperado)")
    p.add_argument(
        "--esperado",
        type=int,
        default=None,
        help="nº de filas que deben cambiar; si no coincide, aborta sin escribir",
    )
    a = p.parse_args(argv)

    if a.aplicar and a.esperado is None:
        print("--aplicar exige --esperado N (el número que arrojó el simulacro)", file=sys.stderr)
        return 2

    SessionLocal = get_sessionmaker()
    db = SessionLocal()
    try:
        limites = db.execute(text("SELECT count(*) FROM admin_boundary")).scalar_one()
        print(f"límites cargados:   {limites} municipios")
        if limites == 0:
            print("admin_boundary está VACÍA: cargue los límites antes del backfill.", file=sys.stderr)
            return 1

        total, sin_resolver, cambian, desglose = _analizar(db)
        _reportar(total, sin_resolver, cambian, desglose)

        if a.simulacro:
            db.rollback()
            print("\nsimulacro: nada se escribió.")
            return 0

        if cambian != a.esperado:
            db.rollback()
            print(
                f"\nABORTADO: cambian {cambian} filas, se esperaban {a.esperado}. "
                "Vuelva a correr el simulacro y confirme el número.",
                file=sys.stderr,
            )
            return 1

        obs = db.execute(text(_SQL_APLICAR)).rowcount
        arb = db.execute(text(_SQL_APLICAR_TREE)).rowcount
        db.commit()
        print(f"\naplicado: {obs} observaciones y {arb} árboles actualizados.")
        return 0
    finally:
        db.close()


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
