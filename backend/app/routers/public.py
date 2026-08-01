"""Vistas públicas (sin auth).

- ``GET /public/observations`` — ubicación **EXACTA** del árbol, handle por observación (atribución
  I2) y ``snapshot_quarter`` ("Qn"). Entran al dataset público **solo las observaciones
  confirmadas** por revisión humana (``estado_revision = 'confirmada'``).
- ``GET /public/grid`` — mapa de calor agregado: agrupa (*binning*) las observaciones confirmadas
  en una malla de celdas y devuelve conteos/promedios por celda. El binning es AGREGACIÓN de
  densidad/severidad del heatmap, no una capa de presentación de la ubicación.
- ``GET /public/indicators`` — indicadores Q6 calculados automáticamente, **sin umbrales** (U1).

⚠️ **CR-026 (solicitud de las universidades participantes) ENMIENDA el criterio público del
gate #9.** CR-001 lo fijó en "no-rechazada" (aceptadas + confirmadas), lo que publicaba también lo
que nadie había revisado todavía — incluida una foto que podía no ser un mezquite. El criterio pasa
a **confirmada**: al mapa público solo llega lo que una persona revisó y confirmó. Consecuencia
operativa asumida: el mapa refleja el ritmo de revisión de la consola, no el de captura.
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
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
) -> list[PublicObservation]:
    """Dataset público: ubicación EXACTA del árbol. Solo CONFIRMADAS (CR-026).

    Devuelve la ubicación exacta capturada (``ST_Y``/``ST_X`` del ``geom``) tal cual. Especie y nivel
    G4 siguen siendo AUTODECLARADOS (gate #8) — la confirmación humana avala que la foto corresponde
    a un mezquite observado, no el nivel declarado. Ningún umbral (U1).

    CR-034: ``offset`` permite al cliente recorrer el dataset completo por páginas (el ``limit``
    solo, sin offset, era un tope silencioso para las vistas de lista).
    """
    quarter = latest_snapshot_label(db)
    rows = db.execute(
        text(
            """
            SELECT handle, ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lon,
                   nivel_g4, flag_cuscuta, flag_danio, estado, municipio, captured_at
            FROM observation
            WHERE estado_revision = 'confirmada'
              AND (CAST(:estado AS text) IS NULL OR estado = :estado)
            ORDER BY captured_at DESC
            LIMIT :limit OFFSET :offset
            """
        ),
        {"estado": estado, "limit": limit, "offset": offset},
    ).mappings().all()

    out: list[PublicObservation] = []
    for r in rows:
        out.append(
            PublicObservation(
                handle=r["handle"],
                lat=float(r["lat"]),
                lon=float(r["lon"]),
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
    """Mapa de calor agregado por celda (CR-009).

    Toma las observaciones **confirmadas** (igual que ``/public/observations``, CR-026) y las agrupa
    (*binning*) en celdas métricas vía ``obfuscate_to_grid`` (CR-009: 300 m), agrupando por
    ``(lat, lon)`` de celda para devolver conteos/promedios. Aquí el snap a celda es **agregación de
    densidad/severidad del heatmap** (reduce miles de puntos a una malla pintable), no una capa de
    presentación de la ubicación. Especie y nivel G4 son AUTODECLARADOS (gate #8); ningún umbral (U1).
    """
    quarter = latest_snapshot_label(db)
    rows = db.execute(
        text(
            """
            SELECT ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lon,
                   nivel_g4, flag_cuscuta, flag_danio
            FROM observation
            WHERE estado_revision = 'confirmada'
              AND (CAST(:estado AS text) IS NULL OR estado = :estado)
            ORDER BY captured_at DESC
            LIMIT :limit
            """
        ),
        {"estado": estado, "limit": limit},
    ).mappings().all()

    # Agrega en memoria: cada observación se asigna (binning) a la celda de su heatmap.
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
