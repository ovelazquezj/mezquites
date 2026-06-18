"""Analítica para el analista (CR-010) — resúmenes y exportación CSV.

- ``GET /admin/analytics/summary`` — conteos agregados por estado_revision/municipio/nivel_g4 +
  total (para tableros del analista). Descriptivo (gate #1: no promete control fitosanitario).
- ``GET /admin/analytics/observations.csv`` — exportación CSV de observaciones con filtros.

GATE #5 (BLOQUEANTE): el analista (y la consola) NO son ``aliado_firmante``. El CSV expone SOLO la
celda de obfuscación (CR-009: 300 m) vía ``geo.obfuscate_to_grid``; NUNCA coords exactas. El backend
extrae lat/lon exactas únicamente para obfuscarlas server-side antes de escribir cada fila.

Gate #2 (sin PII): solo el ``handle`` seudónimo; nunca email/nombre.
"""

from __future__ import annotations

import csv
import io

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, require_role
from ..geo import obfuscate_to_grid
from ..models import REVIEW_ROLES
from ..schemas import AnalyticsSummary

router = APIRouter(prefix="/admin/analytics", tags=["analytics"])

# Roles de consola con acceso a la analítica (igual que la revisión, lectura). `analista` incluido.
_analyst = require_role(*REVIEW_ROLES)

# Columnas del CSV (gate #5: coords SOLO a celda 300 m; gate #2: handle seudónimo, sin PII).
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
    user: CurrentUser = Depends(_analyst),
    db: Session = Depends(get_db),
) -> list[dict]:
    """Tabla de observaciones para el analista (CR-010 #3). Sin coords exactas (gate #5):
    expone solo estado/municipio agregables; las coords NO se incluyen en esta vista."""
    params = _filter_params(estado, municipio, nivel_g4, estado_revision, desde, hasta)
    params["limit"] = limit
    rows = db.execute(
        text(
            f"""
            SELECT id, captured_at, handle, estado, municipio, nivel_g4,
                   flag_cuscuta, flag_danio, estado_revision
            FROM observation
            WHERE {_FILTER_WHERE}
            ORDER BY captured_at DESC
            LIMIT :limit
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
    """Exportación CSV (CR-010).

    GATE #5 (BLOQUEANTE): coords SOLO a celda de obfuscación (300 m) vía ``obfuscate_to_grid``;
    NUNCA exactas. El backend extrae lat/lon exactas solo para obfuscarlas antes de escribir.
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

    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(_CSV_COLUMNS)
    for r in rows:
        lat_celda, lon_celda = obfuscate_to_grid(float(r["lat"]), float(r["lon"]))
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
                lat_celda,
                lon_celda,
            ]
        )

    buf.seek(0)
    return StreamingResponse(
        iter([buf.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="observations.csv"'},
    )
