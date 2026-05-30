"""Lógica geoespacial (T3, gate #5, gate de escalamiento Q8).

- ``obfuscate_1km`` — redondea (lat, lon) a una celda métrica de 1 km usando una proyección
  métrica (EPSG:6372, México) y reproyecta el centro de la celda a WGS84. Las **vistas públicas
  NUNCA exponen coords más finas que 1 km** (gate #5).
- ``assign_tree`` — agrupa observaciones dentro de ``tree_radius_m`` (10 m, R3) vía ``ST_DWithin``
  sobre ``geography`` (metros reales); crea o reutiliza un ``tree`` (gate T3).
- ``compute_observation_seq`` — posición en la serie temporal del árbol (gap > 30 días, R3).
- ``derive_estado_municipio`` — join espacial a ``admin_boundary`` (Q8); deriva estado/municipio
  del EXIF. Sin límites cargados ⇒ (None, None) sin romper el flujo.

Las funciones que tocan PostGIS reciben una ``Session`` SQLAlchemy.
"""

from __future__ import annotations

import uuid
from functools import lru_cache

from pyproj import Transformer
from sqlalchemy import text
from sqlalchemy.orm import Session

from .config import get_settings
from .models import Tree


@lru_cache(maxsize=4)
def _transformers(metric_srid: int) -> tuple[Transformer, Transformer]:
    """(WGS84→métrico, métrico→WGS84), cacheados por SRID."""
    fwd = Transformer.from_crs(4326, metric_srid, always_xy=True)
    inv = Transformer.from_crs(metric_srid, 4326, always_xy=True)
    return fwd, inv


def obfuscate_1km(lat: float, lon: float) -> tuple[float, float]:
    """Redondea (lat, lon) al centro de una celda métrica de 1 km (gate #5).

    Proyecta a EPSG:6372 (metros, México), aplica ``floor`` a la celda de 1000 m, toma el centro
    de celda y reproyecta a WGS84. Devuelve (lat_obf, lon_obf). Idéntico en intención a
    ``ST_SnapToGrid`` sobre proyección métrica, pero ejecutable sin DB (vistas públicas y pruebas).
    """
    settings = get_settings()
    grid = settings.obfuscation_grid_m
    fwd, inv = _transformers(settings.metric_srid)
    x, y = fwd.transform(lon, lat)
    cx = (x // grid) * grid + grid / 2.0
    cy = (y // grid) * grid + grid / 2.0
    lon_obf, lat_obf = inv.transform(cx, cy)
    return round(lat_obf, 6), round(lon_obf, 6)


def assign_tree(
    db: Session, *, lat: float, lon: float, estado: str | None, municipio: str | None
) -> uuid.UUID:
    """Asigna ``tree_id`` agrupando dentro de ``tree_radius_m`` (10 m) — gate T3.

    Usa ``ST_DWithin(centroid, :geom, radio)`` sobre ``geography`` (metros reales). Si existe un
    árbol a ≤ radio, reutiliza su id; si no, crea uno nuevo con centroide en el punto capturado.
    """
    settings = get_settings()
    radius = settings.tree_radius_m
    row = db.execute(
        text(
            """
            SELECT id
            FROM tree
            WHERE ST_DWithin(
                centroid,
                ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                :radius
            )
            ORDER BY ST_Distance(
                centroid,
                ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
            )
            LIMIT 1
            """
        ),
        {"lon": lon, "lat": lat, "radius": radius},
    ).first()
    if row is not None:
        return row[0]

    point_wkt = f"SRID=4326;POINT({lon} {lat})"
    tree = Tree(centroid=point_wkt, estado=estado, municipio=municipio)
    db.add(tree)
    db.flush()  # asigna id sin commit
    return tree.id


def compute_observation_seq(db: Session, tree_id: uuid.UUID, captured_at) -> int:
    """Posición en la serie temporal del árbol (R3): 1 + nº de observaciones previas.

    Cuenta las observaciones existentes del árbol con ``captured_at`` estrictamente anterior.
    La regla de "punto independiente si gap > 30 días" se materializa en el indicador ecológico
    (serie temporal ≥ 2 obs con gap > 30 días); aquí asignamos el ordinal temporal.
    """
    row = db.execute(
        text(
            """
            SELECT count(*)
            FROM observation
            WHERE tree_id = :tree_id AND captured_at < :captured_at
            """
        ),
        {"tree_id": tree_id, "captured_at": captured_at},
    ).scalar_one()
    return int(row) + 1


def derive_estado_municipio(db: Session, *, lat: float, lon: float) -> tuple[str | None, str | None]:
    """Deriva (estado, municipio) por join espacial a ``admin_boundary`` (Q8).

    Si no hay límites cargados o el punto no cae en ninguno, devuelve (None, None) sin romper el
    flujo de submit (el escalamiento no depende de tener los límites cargados).
    """
    row = db.execute(
        text(
            """
            SELECT estado, municipio
            FROM admin_boundary
            WHERE ST_Contains(
                geom::geometry,
                ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)
            )
            LIMIT 1
            """
        ),
        {"lon": lon, "lat": lat},
    ).first()
    if row is None:
        return None, None
    return row[0], row[1]
