"""Vistas públicas (sin auth).

- ``GET /public/observations`` — coords **obfuscadas a grid 1 km** (gate #5), handle por
  observación (atribución I2), y ``snapshot_quarter`` ("Qn"). Solo observaciones **válidas**
  entran al dataset público (gate #9).
- ``GET /public/indicators`` — indicadores Q6 calculados automáticamente, **sin umbrales** (U1).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..db import get_db
from ..geo import obfuscate_1km
from ..indicators import CAVEAT, compute_indicators
from ..schemas import Indicators, PublicObservation
from ..snapshots import latest_snapshot_label

router = APIRouter(prefix="/public", tags=["public"])


@router.get("/observations", response_model=list[PublicObservation])
def public_observations(
    estado: str | None = Query(None),
    limit: int = Query(500, le=5000),
    db: Session = Depends(get_db),
) -> list[PublicObservation]:
    """Dataset público: coords NUNCA más finas que 1 km (gate #5). Solo válidas (gate #9).

    El backend extrae lat/lon exactas SOLO para obfuscarlas server-side; lo que sale por el wire
    ya es el centro de celda de 1 km. La query nunca devuelve coords exactas al público.
    """
    quarter = latest_snapshot_label(db)
    rows = db.execute(
        text(
            """
            SELECT handle, ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lon,
                   nivel_g4, flag_cuscuta, flag_danio, estado, municipio, captured_at
            FROM observation
            WHERE validation_state = 'valida'
              AND (CAST(:estado AS text) IS NULL OR estado = :estado)
            ORDER BY captured_at DESC
            LIMIT :limit
            """
        ),
        {"estado": estado, "limit": limit},
    ).mappings().all()

    out: list[PublicObservation] = []
    for r in rows:
        lat_obf, lon_obf = obfuscate_1km(float(r["lat"]), float(r["lon"]))
        out.append(
            PublicObservation(
                handle=r["handle"],
                lat=lat_obf,
                lon=lon_obf,
                nivel_g4=r["nivel_g4"],
                flag_cuscuta=r["flag_cuscuta"],
                flag_danio=r["flag_danio"],
                estado=r["estado"],
                municipio=r["municipio"],
                captured_at=r["captured_at"],
                snapshot_quarter=quarter,
            )
        )
    return out


@router.get("/indicators", response_model=Indicators)
def public_indicators(
    estado: str | None = Query(None), db: Session = Depends(get_db)
) -> Indicators:
    """Indicadores Q6 automáticos. SIN umbrales/aprobación (U1, gate boundary)."""
    data = compute_indicators(db, estado=estado)
    return Indicators(
        snapshot_quarter=latest_snapshot_label(db),
        caveat=CAVEAT,
        social=data["social"],
        educativo=data["educativo"],
        ecologico=data["ecologico"],
        organizacional=data["organizacional"],
    )
