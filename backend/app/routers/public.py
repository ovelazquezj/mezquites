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

from ..config import get_settings
from ..db import get_db
from ..geo_filtros import CLAUSULA_GEO, params_geo
from ..indicators import CAVEAT, compute_indicators
from ..schemas import Indicators, PublicGridCell, PublicObservation
from ..snapshots import latest_snapshot_label

router = APIRouter(prefix="/public", tags=["public"])

# Mapeo del nivel G4 autodeclarado (gate #8) a un índice 0..3 para promediar en el mapa de calor.
_G4_INDICE = {"sano": 0, "leve": 1, "moderado": 2, "severo": 3}


@router.get("/observations", response_model=list[PublicObservation])
def public_observations(
    estado: str | None = Query(None),
    municipio: str | None = Query(None),
    cve_ent: str | None = Query(None, min_length=2, max_length=2),
    cve_mun: str | None = Query(None, min_length=3, max_length=3),
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
            """
            + CLAUSULA_GEO
            + """
            ORDER BY captured_at DESC
            LIMIT :limit OFFSET :offset
            """
        ),
        {
            **params_geo(
                estado=estado, municipio=municipio, cve_ent=cve_ent, cve_mun=cve_mun
            ),
            "limit": limit,
            "offset": offset,
        },
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
    municipio: str | None = Query(None),
    cve_ent: str | None = Query(None, min_length=2, max_length=2),
    cve_mun: str | None = Query(None, min_length=3, max_length=3),
    db: Session = Depends(get_db),
) -> list[PublicGridCell]:
    """Mapa de calor agregado por celda (CR-009).

    Toma las observaciones **confirmadas** (igual que ``/public/observations``, CR-026) y las agrupa
    (*binning*) en celdas métricas de ``obfuscation_grid_m`` (CR-009: 300 m), devolviendo
    conteos/promedios por celda. El snap a celda es **agregación de densidad/severidad del heatmap**
    (reduce miles de puntos a una malla pintable), no una capa de presentación de la ubicación.
    Especie y nivel G4 son AUTODECLARADOS (gate #8); ningún umbral (U1).

    **CR-036: la agregación pasó de Python a SQL y el parámetro ``limit`` desapareció.** Antes se
    traían a lo más 5 000 filas y se agrupaban en memoria, lo que convertía el mapa en una vista
    silenciosamente truncada en cuanto el piloto rebasara ese número — y con 78–374 capturas al día
    faltaban semanas, no años. Agregando en la base no hay nada que topar: el resultado es una celda
    por cuadrícula ocupada, que es intrínsecamente pequeño, sin importar cuántas observaciones haya
    detrás. Retirar el parámetro es compatible: un cliente que siga enviando ``limit`` es ignorado
    por FastAPI, y su mapa mejora sin recompilar.

    El binning replica exactamente ``geo.obfuscate_to_grid`` (proyectar a ``metric_srid``, ``floor``
    a la celda, tomar su centro, volver a WGS84) para que ambos caminos produzcan las mismas celdas.
    """
    settings = get_settings()
    quarter = latest_snapshot_label(db)
    rows = db.execute(
        text(
            """
            WITH filtradas AS (
                SELECT ST_Transform(geom::geometry, :srid) AS p,
                       nivel_g4, flag_cuscuta, flag_danio
                FROM observation
                WHERE estado_revision = 'confirmada'
            """
            + CLAUSULA_GEO
            + """
            ), celdas AS (
                SELECT ST_Transform(
                           ST_SetSRID(
                               ST_MakePoint(
                                   floor(ST_X(p) / :grid) * :grid + :grid / 2.0,
                                   floor(ST_Y(p) / :grid) * :grid + :grid / 2.0
                               ),
                               :srid
                           ),
                           4326
                       ) AS centro,
                       nivel_g4, flag_cuscuta, flag_danio
                FROM filtradas
            )
            SELECT round(ST_Y(centro)::numeric, 6) AS lat,
                   round(ST_X(centro)::numeric, 6) AS lon,
                   count(*)                        AS n,
                   count(*) FILTER (WHERE flag_danio)   AS n_paxtle,
                   count(*) FILTER (WHERE flag_cuscuta) AS n_cuscuta,
                   avg(CASE nivel_g4
                           WHEN 'sano' THEN 0 WHEN 'leve' THEN 1
                           WHEN 'moderado' THEN 2 WHEN 'severo' THEN 3
                           ELSE 0 END)             AS g4_indice
            FROM celdas
            GROUP BY 1, 2
            """
        ),
        {
            **params_geo(
                estado=estado, municipio=municipio, cve_ent=cve_ent, cve_mun=cve_mun
            ),
            "srid": settings.metric_srid,
            "grid": settings.obfuscation_grid_m,
        },
    ).mappings().all()

    return [
        PublicGridCell(
            lat=float(r["lat"]),
            lon=float(r["lon"]),
            n=int(r["n"]),
            n_paxtle=int(r["n_paxtle"]),
            n_cuscuta=int(r["n_cuscuta"]),
            g4_indice=round(float(r["g4_indice"]), 4),
            snapshot_quarter=quarter,
        )
        for r in rows
    ]


@router.get("/indicators", response_model=Indicators)
def public_indicators(
    estado: str | None = Query(None),
    municipio: str | None = Query(None),
    cve_ent: str | None = Query(None, min_length=2, max_length=2),
    cve_mun: str | None = Query(None, min_length=3, max_length=3),
    db: Session = Depends(get_db),
) -> Indicators:
    """Indicadores Q6 automáticos. SIN umbrales/aprobación (U1, gate boundary)."""
    data = compute_indicators(
        db, estado=estado, municipio=municipio, cve_ent=cve_ent, cve_mun=cve_mun
    )
    return Indicators(
        snapshot_quarter=latest_snapshot_label(db),
        caveat=CAVEAT,
        social=data["social"],
        educativo=data["educativo"],
        ecologico=data["ecologico"],
        organizacional=data["organizacional"],
    )
