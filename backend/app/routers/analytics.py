"""Analítica para la consola (CR-010) — resúmenes y exportación CSV.

- ``GET /admin/analytics/summary`` — conteos agregados por estado_revision/municipio/nivel_g4 +
  total (para tableros del analista). Descriptivo (gate #1: no promete control fitosanitario).
- ``GET /admin/analytics/observations.csv`` — exportación CSV de observaciones con filtros; presenta
  la ubicación exacta del árbol a la consola.
- ``GET /admin/analytics/participation.csv`` (CR-026) — participación **por día y voluntario**:
  sesiones y horas frente al resultado de revisión (aceptadas / confirmadas / rechazadas), para que
  la institución pueda cruzar tiempo dedicado contra observaciones que sobrevivieron la revisión.

Por decisión de gobernanza del Club (CR-025), el CSV presenta coords **exactas** a los roles de
``EXACT_LOCATION_ROLES``, que ahora incluye a todos los roles de revisión/analítica
(``REVIEW_ROLES``: evaluador/analista/administrador). La rama de binning (``obfuscate_to_grid`` +
``_CSV_COLUMNS``) queda **ociosa** — ningún rol con acceso al endpoint cae en ella hoy — pero se
conserva presente y funcional.

Gate #2 (sin PII): solo el ``handle`` seudónimo; nunca email/nombre.
"""

from __future__ import annotations

import csv
import io

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..config import get_settings
from ..db import get_db
from ..deps import CurrentUser, require_role
from ..geo import obfuscate_to_grid
from ..models import EXACT_LOCATION_ROLES, REVIEW_ROLES
from ..schemas import AnalyticsSummary

router = APIRouter(prefix="/admin/analytics", tags=["analytics"])

# Roles de consola con acceso a la analítica (igual que la revisión, lectura). `analista` incluido.
_analyst = require_role(*REVIEW_ROLES)

# Columnas del CSV con la ubicación en celda de binning (300 m). OCIOSAS hoy: la salida por defecto
# es exacta (``_CSV_COLUMNS_EXACT``) para todos los roles con acceso; se conservan por si el binning
# vuelve a usarse. Gate #2: handle seudónimo, sin PII.
_CSV_COLUMNS = [
    "observation_id",
    "captured_at",
    "handle",
    "estado",
    "municipio",
    "nivel_g4",
    "flag_cuscuta",
    "flag_danio",
    "tamanio",
    "contexto",
    "estado_revision",
    "lat_celda_300m",
    "lon_celda_300m",
]

# Columnas del CSV con la ubicación EXACTA (``lat``/``lon``) — idénticas salvo las 2 últimas. Es la
# salida por defecto para la consola (CR-025), emitida a los roles de ``EXACT_LOCATION_ROLES``.
_CSV_COLUMNS_EXACT = _CSV_COLUMNS[:-2] + ["lat", "lon"]

# WHERE compartido por summary y CSV (filtros opcionales). CAST a text/timestamptz para NULL-safe.
_FILTER_WHERE = """
    (CAST(:estado AS text) IS NULL OR estado = :estado)
    AND (CAST(:municipio AS text) IS NULL OR municipio = :municipio)
    AND (CAST(:nivel_g4 AS text) IS NULL OR nivel_g4 = :nivel_g4)
    AND (CAST(:estado_revision AS text) IS NULL OR estado_revision = :estado_revision)
    AND (CAST(:desde AS timestamptz) IS NULL OR captured_at >= CAST(:desde AS timestamptz))
    AND (CAST(:hasta AS timestamptz) IS NULL OR captured_at <= CAST(:hasta AS timestamptz))
"""


def _filter_params(
    estado, municipio, nivel_g4, estado_revision, desde, hasta
) -> dict:
    return {
        "estado": estado,
        "municipio": municipio,
        "nivel_g4": nivel_g4,
        "estado_revision": estado_revision,
        "desde": desde,
        "hasta": hasta,
    }


@router.get("/summary", response_model=AnalyticsSummary)
def analytics_summary(
    estado: str | None = Query(None),
    municipio: str | None = Query(None),
    nivel_g4: str | None = Query(None),
    estado_revision: str | None = Query(None),
    desde: str | None = Query(None, description="ISO date/datetime: captured_at >= desde."),
    hasta: str | None = Query(None, description="ISO date/datetime: captured_at <= hasta."),
    user: CurrentUser = Depends(_analyst),
    db: Session = Depends(get_db),
) -> AnalyticsSummary:
    """Conteos agregados por estado_revision/municipio/nivel_g4 + total (CR-010). Descriptivo (#1)."""
    params = _filter_params(estado, municipio, nivel_g4, estado_revision, desde, hasta)

    def _group_counts(column: str) -> dict[str, int]:
        rows = db.execute(
            text(
                f"SELECT {column} AS k, count(*) AS n FROM observation "
                f"WHERE {_FILTER_WHERE} GROUP BY {column}"
            ),
            params,
        ).all()
        # NULLs (municipio sin derivar) se reportan bajo "sin_dato" para no perder el conteo.
        return {(r[0] if r[0] is not None else "sin_dato"): int(r[1]) for r in rows}

    por_estado_revision = _group_counts("estado_revision")
    por_municipio = _group_counts("municipio")
    por_nivel_g4 = _group_counts("nivel_g4")
    total = int(
        db.execute(
            text(f"SELECT count(*) FROM observation WHERE {_FILTER_WHERE}"), params
        ).scalar_one()
    )
    return AnalyticsSummary(
        por_estado_revision=por_estado_revision,
        por_municipio=por_municipio,
        por_nivel_g4=por_nivel_g4,
        total=total,
    )


@router.get("/observations")
def analytics_observations(
    estado: str | None = Query(None),
    municipio: str | None = Query(None),
    nivel_g4: str | None = Query(None),
    estado_revision: str | None = Query(None),
    desde: str | None = Query(None, description="ISO date/datetime: captured_at >= desde."),
    hasta: str | None = Query(None, description="ISO date/datetime: captured_at <= hasta."),
    limit: int = Query(1000, le=5000),
    offset: int = Query(0, ge=0),
    user: CurrentUser = Depends(_analyst),
    db: Session = Depends(get_db),
) -> list[dict]:
    """Tabla de observaciones para el analista (CR-010 #3). No incluye coords: expone estado/municipio
    agregables; la ubicación exacta se consulta en ``/restricted/observations`` o el CSV.

    CR-034: ``offset`` permite recorrer el dataset completo por páginas."""
    params = _filter_params(estado, municipio, nivel_g4, estado_revision, desde, hasta)
    params["limit"] = limit
    params["offset"] = offset
    rows = db.execute(
        text(
            f"""
            SELECT id, captured_at, handle, estado, municipio, nivel_g4,
                   flag_cuscuta, flag_danio, estado_revision
            FROM observation
            WHERE {_FILTER_WHERE}
            ORDER BY captured_at DESC
            LIMIT :limit OFFSET :offset
            """
        ),
        params,
    ).mappings().all()
    return [
        {
            "observation_id": str(r["id"]),
            "captured_at": r["captured_at"].isoformat() if r["captured_at"] is not None else None,
            "handle": r["handle"],
            "estado": r["estado"],
            "municipio": r["municipio"],
            "nivel_g4": r["nivel_g4"],
            "flag_cuscuta": r["flag_cuscuta"],
            "flag_danio": r["flag_danio"],
            "estado_revision": r["estado_revision"],
        }
        for r in rows
    ]


@router.get("/observations.csv")
def analytics_csv(
    estado: str | None = Query(None),
    municipio: str | None = Query(None),
    nivel_g4: str | None = Query(None),
    estado_revision: str | None = Query(None),
    desde: str | None = Query(None, description="ISO date/datetime: captured_at >= desde."),
    hasta: str | None = Query(None, description="ISO date/datetime: captured_at <= hasta."),
    user: CurrentUser = Depends(_analyst),
    db: Session = Depends(get_db),
) -> StreamingResponse:
    """Exportación CSV (CR-010; CR-025).

    Presenta la ubicación **exacta** del árbol (columnas ``lat``/``lon``) a los roles de la consola en
    ``EXACT_LOCATION_ROLES`` — hoy, todos los que pueden llamar el endpoint. La rama de binning
    (``obfuscate_to_grid`` → columnas ``lat_celda_300m``/``lon_celda_300m``) se conserva ociosa: ningún
    rol con acceso cae en ella hoy. Gate #2: solo ``handle`` seudónimo, sin PII.
    """
    params = _filter_params(estado, municipio, nivel_g4, estado_revision, desde, hasta)
    rows = db.execute(
        text(
            f"""
            SELECT id, captured_at, handle, estado, municipio, nivel_g4,
                   flag_cuscuta, flag_danio, tamanio, contexto, estado_revision,
                   ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lon
            FROM observation
            WHERE {_FILTER_WHERE}
            ORDER BY captured_at DESC
            """
        ),
        params,
    ).mappings().all()

    # CR-025: exacto para los roles de la consola. La rama de binning (obfuscado 300 m) queda ociosa
    # (ningún rol con acceso cae en ella hoy) pero se conserva.
    exact = user.role in EXACT_LOCATION_ROLES

    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(_CSV_COLUMNS_EXACT if exact else _CSV_COLUMNS)
    for r in rows:
        if exact:
            lat_out, lon_out = float(r["lat"]), float(r["lon"])
        else:
            lat_out, lon_out = obfuscate_to_grid(float(r["lat"]), float(r["lon"]))
        writer.writerow(
            [
                str(r["id"]),
                r["captured_at"].isoformat() if r["captured_at"] is not None else "",
                r["handle"],
                r["estado"] or "",
                r["municipio"] or "",
                r["nivel_g4"],
                r["flag_cuscuta"],
                r["flag_danio"],
                r["tamanio"] or "",
                r["contexto"] or "",
                r["estado_revision"],
                lat_out,
                lon_out,
            ]
        )

    buf.seek(0)
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="observations.csv"'},
    )


# Columnas del reporte de participación por día (CR-026). Gate #2: `handle` seudónimo, sin PII.
_PARTICIPATION_COLUMNS = [
    "fecha",
    "handle",
    "institucion",
    "sesiones",
    "horas",
    "obs_total",
    "obs_aceptadas",
    "obs_confirmadas",
    "obs_rechazadas",
]

# Participación por día × voluntario. Las dos mitades se agregan por separado y se cruzan con FULL
# OUTER JOIN: hay días con sesiones sin capturas (abrió la app y no subió nada) y días con capturas
# cuya sesión no llegó a registrarse (el envío es fire-and-forget). Perder cualquiera de los dos
# lados falsearía justo la comparación que la institución quiere hacer.
_PARTICIPATION_SQL = """
    WITH ses AS (
        SELECT account_id,
               (started_at AT TIME ZONE :tz)::date AS dia,
               count(*) AS sesiones,
               COALESCE(sum(duration_seconds), 0) AS segundos
        FROM participation_session
        WHERE (CAST(:desde AS timestamptz) IS NULL OR started_at >= CAST(:desde AS timestamptz))
          AND (CAST(:hasta AS timestamptz) IS NULL OR started_at <= CAST(:hasta AS timestamptz))
        GROUP BY account_id, dia
    ),
    obs AS (
        SELECT account_id,
               (captured_at AT TIME ZONE :tz)::date AS dia,
               count(*) AS total,
               count(*) FILTER (WHERE estado_revision = 'aceptada') AS aceptadas,
               count(*) FILTER (WHERE estado_revision = 'confirmada') AS confirmadas,
               count(*) FILTER (WHERE estado_revision = 'rechazada') AS rechazadas
        FROM observation
        WHERE (CAST(:estado AS text) IS NULL OR estado = :estado)
          AND (CAST(:municipio AS text) IS NULL OR municipio = :municipio)
          AND (CAST(:desde AS timestamptz) IS NULL OR captured_at >= CAST(:desde AS timestamptz))
          AND (CAST(:hasta AS timestamptz) IS NULL OR captured_at <= CAST(:hasta AS timestamptz))
        GROUP BY account_id, dia
    )
    SELECT COALESCE(s.dia, o.dia) AS dia,
           a.handle AS handle,
           i.name AS institucion,
           COALESCE(s.sesiones, 0) AS sesiones,
           COALESCE(s.segundos, 0) AS segundos,
           COALESCE(o.total, 0) AS obs_total,
           COALESCE(o.aceptadas, 0) AS obs_aceptadas,
           COALESCE(o.confirmadas, 0) AS obs_confirmadas,
           COALESCE(o.rechazadas, 0) AS obs_rechazadas
    FROM ses s
    FULL OUTER JOIN obs o ON o.account_id = s.account_id AND o.dia = s.dia
    JOIN account a ON a.id = COALESCE(s.account_id, o.account_id)
    LEFT JOIN institution i ON i.id = a.institution_id
    ORDER BY dia DESC, a.handle
"""


@router.get("/participation.csv")
def participation_csv(
    estado: str | None = Query(None),
    municipio: str | None = Query(None),
    desde: str | None = Query(None, description="ISO date/datetime: >= desde."),
    hasta: str | None = Query(None, description="ISO date/datetime: <= hasta."),
    user: CurrentUser = Depends(_analyst),
    db: Session = Depends(get_db),
) -> StreamingResponse:
    """Participación por día y voluntario (CR-026, solicitud de las universidades participantes).

    Una fila por (día × voluntario) con **sesiones y horas** de un lado y el **resultado de la
    revisión** del otro (``aceptada`` = pendiente de revisión, ``confirmada``, ``rechazada``), para
    que la institución pueda comparar tiempo dedicado contra observaciones que sobrevivieron la
    revisión, sin tener que consultar la base a mano.

    El día se calcula en el huso de ``report_timezone`` (América/México por defecto): las marcas se
    guardan en UTC y agrupar en UTC empujaría al día siguiente toda la actividad de la tarde.

    ⚠️ Las horas miden **tiempo con la app en primer plano**, no trabajo en campo — es la razón por
    la que CR-026 las retiró de la pantalla del voluntario. Se exportan como dato de análisis, no
    como constancia de servicio; quien lea el reporte debe saberlo.

    Los filtros ``estado``/``municipio`` aplican a las observaciones (las sesiones no tienen
    ubicación): con uno de ellos activo, un día de sesión sin capturas en ese municipio aparece con
    los conteos de observación en cero. Gate #2: solo ``handle`` seudónimo, nunca PII.
    """
    rows = db.execute(
        text(_PARTICIPATION_SQL),
        {
            "tz": get_settings().report_timezone,
            "estado": estado,
            "municipio": municipio,
            "desde": desde,
            "hasta": hasta,
        },
    ).mappings().all()

    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(_PARTICIPATION_COLUMNS)
    for r in rows:
        writer.writerow(
            [
                r["dia"].isoformat() if r["dia"] is not None else "",
                r["handle"],
                r["institucion"] or "",
                int(r["sesiones"]),
                round(float(r["segundos"]) / 3600.0, 4),
                int(r["obs_total"]),
                int(r["obs_aceptadas"]),
                int(r["obs_confirmadas"]),
                int(r["obs_rechazadas"]),
            ]
        )

    buf.seek(0)
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="participation.csv"'},
    )
