"""Filtro geográfico compartido por los endpoints de lista y analítica — CR-036.

Antes cada router escribía su propio ``AND (CAST(:estado AS text) IS NULL OR estado = :estado)``, y
el municipio solo existía en algunos. Al volverse el dataset multi-estado hay que filtrar por los dos
niveles **y** admitir las claves INEGI, así que la condición se define una sola vez.

**Por qué se aceptan clave y nombre.** La clave (``cve_ent``/``cve_mun``) es la identidad estable y
es lo que manda la consola: inmune a acentos y, sobre todo, a los homónimos —"Jesús María" existe en
Aguascalientes, en Jalisco y en Nayarit—. El nombre se conserva porque los clientes anteriores a
CR-036 filtran así y romperlos no aporta nada; para las observaciones históricas sin clave (las
anteriores al backfill) el nombre es además el único filtro posible.
"""

from __future__ import annotations

from typing import Any

def clausula_geo(alias: str | None = None) -> str:
    """Condición ``AND …`` que filtra por estado/municipio, por nombre o por clave INEGI.

    ``alias`` califica las columnas para las consultas con JOIN (``clausula_geo("o")``). El ``CAST``
    explícito es necesario: psycopg3 no infiere el tipo de un parámetro usado como ``:p IS NULL``.
    """
    pre = f"{alias}." if alias else ""
    return "".join(
        f"\n              AND (CAST(:{campo} AS text) IS NULL OR {pre}{campo} = :{campo})"
        for campo in ("estado", "municipio", "cve_ent", "cve_mun")
    )


# Se aplica sobre cualquier consulta que tenga las columnas de `observation` en alcance.
CLAUSULA_GEO = clausula_geo()


def params_geo(
    *,
    estado: str | None = None,
    municipio: str | None = None,
    cve_ent: str | None = None,
    cve_mun: str | None = None,
) -> dict[str, Any]:
    """Parámetros que espera :data:`CLAUSULA_GEO`.

    ``cve_mun`` sin ``cve_ent`` filtraría por un ordinal que se repite en las 32 entidades (el "001"
    de Aguascalientes y el "001" de Zacatecas son municipios distintos), así que se ignora: pedir un
    municipio exige decir de qué estado.
    """
    if cve_mun is not None and cve_ent is None:
        cve_mun = None
    return {
        "estado": estado,
        "municipio": municipio,
        "cve_ent": cve_ent,
        "cve_mun": cve_mun,
    }
