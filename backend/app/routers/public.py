"""Vistas públicas (sin auth).

- ``GET /public/observations`` — coords **obfuscadas a la celda** (gate #5; CR-009: 300 m), handle
  por observación (atribución I2), y ``snapshot_quarter`` ("Qn"). Entran al dataset público todas
  las observaciones **no rechazadas** (``estado_revision <> 'rechazada'``): aceptadas + confirmadas
  (revisión humana, CR-001).
- ``GET /public/grid`` — mapa de calor agregado por celda de obfuscación (CR-009): conteos por
  celda, NUNCA coords más finas que la celda ni listas de árboles (gate #5).
- ``GET /public/indicators`` — indicadores Q6 calculados automáticamente, **sin umbrales** (U1).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..db import get_db
from ..geo import obfuscate_to_grid
from ..indicators import CAVEAT, compute_indicators
from ..schemas import Indicators, PublicGridCell, PublicObservation
from ..snapshots import latest_snapshot_label

router = APIRouter(prefix="/public", tags=["public"])

# Mapeo del nivel G4 autodeclarado (gate #8) a un índice 0..3 para promediar en el mapa de calor.
_G4_INDICE = {"sano": 0, "leve": 1, "moderado": 2, "severo": 3}


@router.get("/observations", response_model=list[PublicObservation])
def public_observations(
    estado: str | None = Query(None),
    limit: int = Query(500, le=5000),
    db: Session = Depends(get_db),
) -> list[PublicObservation]:
    """Dataset público: coords NUNCA más finas que la celda (gate #5; CR-009: 300 m). No-rechazadas (CR-001).

    El backend extrae lat/lon exactas SOLO para obfuscarlas server-side; lo que sale por el wire
    ya es el centro de celda. La query nunca devuelve coords exactas al público.
    """
    quarter = latest_snapshot_label(db)
    rows = db.execute(
        text(
            """
            SELECT handle, ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lon,
                   nivel_g4, flag_cuscuta, flag_danio, estado, municipio, captured_at
            FROM observation
            WHERE estado_revision <> 'rechazada'
              AND (CAST(:estado AS text) IS NULL OR estado = :estado)
            ORDER BY captured_at DESC
            LIMIT :limit
            """
        ),
        {"estado": estado, "limit": limit},
    ).mappings().all()

    out: list[PublicObservation] = []
    for r in rows:
        lat_obf, lon_obf = obfuscate_to_grid(float(r["lat"]), float(r["lon"]))
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


@router.get("/grid", response_model=list[PublicGridCell])
def public_grid(
    estado: str | None = Query(None),
    limit: int = Query(500, le=5000),
    db: Session = Depends(get_db),
) -> list[PublicGridCell]:
    """Mapa de calor agregado por celda de obfuscación (CR-009; gate #5).

    Toma las observaciones **no-rechazadas** (igual que ``/public/observations``), obfusca cada una
    al centro de su celda (CR-009: 300 m), agrupa por ``(lat, lon)`` de celda y devuelve solo
    conteos agregados. **Nunca** sale al wire una coord más fina que la celda ni una lista de
    árboles individuales. Especie y nivel G4 son AUTODECLARADOS (gate #8); ningún umbral (U1).
    """
    quarter = latest_snapshot_label(db)
    rows = db.execute(
        text(
            """
            SELECT ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lon,
                   nivel_g4, flag_cuscuta, flag_danio
            FROM observation
            WHERE estado_revision <> 'rechazada'
              AND (CAST(:estado AS text) IS NULL OR estado = :estado)
            ORDER BY captured_at DESC
            LIMIT :limit
            """
        ),
        {"estado": estado, "limit": limit},
    ).mappings().all()

    # Agrega en memoria por celda obfuscada: el wire nunca ve la coord exacta (gate #5).
    cells: dict[tuple[float, float], dict] = {}
    for r in rows:
        key = obfuscate_to_grid(float(r["lat"]), float(r["lon"]))
        cell = cells.get(key)
        if cell is None:
            cell = {"n": 0, "n_paxtle": 0, "n_cuscuta": 0, "g4_sum": 0}
            cells[key] = cell
        cell["n"] += 1
        if r["flag_danio"]:
            cell["n_paxtle"] += 1
        if r["flag_cuscuta"]:
            cell["n_cuscuta"] += 1
        cell["g4_sum"] += _G4_INDICE.get(r["nivel_g4"], 0)

    out: list[PublicGridCell] = []
    for (lat_obf, lon_obf), c in cells.items():
        out.append(
            PublicGridCell(
                lat=lat_obf,
                lon=lon_obf,
                n=c["n"],
                n_paxtle=c["n_paxtle"],
                n_cuscuta=c["n_cuscuta"],
                g4_indice=round(c["g4_sum"] / c["n"], 4) if c["n"] else 0.0,
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
