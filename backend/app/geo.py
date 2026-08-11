"""Lógica geoespacial (T3, gate de escalamiento Q8).

- ``obfuscate_to_grid`` — redondea (lat, lon) al centro de la celda métrica configurable
  (``settings.obfuscation_grid_m``; CR-009: 300 m) usando una proyección métrica (EPSG:6372,
  México) y reproyecta el centro de la celda a WGS84. Se usa como **binning del mapa de calor
  público** (``/public/grid``): agrupa las observaciones en una malla de densidad/severidad. Es
  agregación, no una capa de presentación de la ubicación. ``obfuscate_1km`` se conserva como alias
  por compatibilidad.
- ``assign_tree`` — CR-022 (enmienda R3/T3): crea SIEMPRE un árbol nuevo (1:1 observación↔árbol).
  Ya NO reutiliza árboles cercanos (la consulta ``ST_DWithin`` de 10 m queda retirada); la tabla
  ``tree`` se conserva, pero cada captura registra su propio árbol.
- ``compute_observation_seq`` — posición en la serie temporal del árbol (gap > 30 días, R3).
- ``resolver_ubicacion`` — CR-036: join espacial a ``admin_boundary`` (Q8) que devuelve estado,
  municipio y **claves INEGI**. Es la única fuente de verdad de la geografía de una observación: lo
  que declare el cliente no se consulta. Sin límites cargados, o con un punto fuera de todos,
  devuelve una ``Ubicacion`` vacía y el flujo de submit continúa (gate #3).
  ``derive_estado_municipio`` se conserva como envoltorio de compatibilidad.
- ``listar_estados`` / ``listar_municipios`` — catálogo para ``/geo/*`` y los filtros de la consola.

Las funciones que tocan PostGIS reciben una ``Session`` SQLAlchemy.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
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


def obfuscate_to_grid(lat: float, lon: float) -> tuple[float, float]:
    """Redondea (lat, lon) al centro de su celda métrica (binning del mapa de calor).

    Proyecta a EPSG:6372 (metros, México), aplica ``floor`` a la celda de
    ``settings.obfuscation_grid_m`` (CR-009: 300 m; conmutable por config, gate #6), toma el centro
    de celda y reproyecta a WGS84. Devuelve (lat_obf, lon_obf). Se usa para **agrupar** las
    observaciones del ``/public/grid`` en una malla pintable (agregación de densidad/severidad).
    Idéntico en intención a ``ST_SnapToGrid`` sobre proyección métrica, pero ejecutable sin DB
    (heatmap y pruebas).
    """
    settings = get_settings()
    grid = settings.obfuscation_grid_m
    fwd, inv = _transformers(settings.metric_srid)
    x, y = fwd.transform(lon, lat)
    cx = (x // grid) * grid + grid / 2.0
    cy = (y // grid) * grid + grid / 2.0
    lon_obf, lat_obf = inv.transform(cx, cy)
    return round(lat_obf, 6), round(lon_obf, 6)


# Alias por compatibilidad: lo importan `routers/public.py` y `tests/test_obfuscation.py`.
# La celda de binning ya NO es de 1 km (CR-009: 300 m), pero conservamos el nombre por los imports.
obfuscate_1km = obfuscate_to_grid


def assign_tree(
    db: Session, *, lat: float, lon: float, estado: str | None, municipio: str | None
) -> uuid.UUID:
    """Crea SIEMPRE un árbol nuevo — CR-022 (enmienda R3/T3): 1:1 observación↔árbol.

    Antes (R3/gate T3) se agrupaban observaciones dentro de ``tree_radius_m`` (10 m) reutilizando el
    árbol cercano vía ``ST_DWithin``; esa consulta se omite. La tabla ``tree`` y el concepto de árbol
    se conservan, pero la asignación NUNCA reutiliza un árbol existente: crea y devuelve un ``Tree``
    nuevo con centroide en el punto capturado. (``compute_observation_seq`` devolverá 1 por árbol, al
    ser cada uno único.) Se conserva la firma para no tocar a los llamadores.
    """
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


@dataclass(frozen=True)
class Ubicacion:
    """Resultado de resolver un punto contra ``admin_boundary`` (CR-036).

    ``resuelto`` es False cuando el punto no cae en ningún municipio: entonces los cuatro campos van
    en ``None``. No es un error — el submit continúa (gate #3), simplemente la observación queda sin
    dimensión geográfica en vez de con una inventada.
    """

    estado: str | None = None
    municipio: str | None = None
    cve_ent: str | None = None
    cve_mun: str | None = None

    @property
    def resuelto(self) -> bool:
        return self.cve_ent is not None


# El punto se compara como `geography` contra la columna `geography`: así la consulta **usa el
# índice GiST**. La versión anterior casteaba a `geometry` dentro del WHERE (`ST_Contains(
# geom::geometry, ...)`), lo que lo inhabilitaba — con la tabla vacía daba igual, pero con los 2 478
# municipios cargados sería un escaneo secuencial con un test caro por fila.
#
# El ORDER BY hace determinista el desempate cuando un punto cae exactamente sobre una frontera
# compartida (mismo resultado siempre, en vez de "la que devuelva el índice primero").
_SQL_RESOLVER = text(
    """
    SELECT estado, municipio, cve_ent, cve_mun
    FROM admin_boundary
    WHERE ST_Intersects(geom, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography)
    ORDER BY cve_ent, cve_mun
    LIMIT 1
    """
)


def resolver_ubicacion(db: Session, *, lat: float, lon: float) -> Ubicacion:
    """Resuelve un punto a su municipio por join espacial a ``admin_boundary`` (Q8, CR-036).

    Es la **única** fuente de verdad de estado/municipio: lo que declare el cliente no se consulta.
    Sin límites cargados, o con un punto fuera de todos, devuelve una ``Ubicacion`` vacía y el flujo
    de submit continúa igual.
    """
    row = db.execute(_SQL_RESOLVER, {"lon": lon, "lat": lat}).first()
    if row is None:
        return Ubicacion()
    return Ubicacion(estado=row[0], municipio=row[1], cve_ent=row[2], cve_mun=row[3])


def derive_estado_municipio(db: Session, *, lat: float, lon: float) -> tuple[str | None, str | None]:
    """Compatibilidad: solo (estado, municipio). Prefiere ``resolver_ubicacion``."""
    u = resolver_ubicacion(db, lat=lat, lon=lon)
    return u.estado, u.municipio


def listar_estados(db: Session) -> list[dict[str, str]]:
    """Catálogo de entidades presentes en ``admin_boundary`` (CR-036).

    Sale de un ``SELECT DISTINCT`` sobre la capa municipal: no hace falta una tabla aparte de
    entidades, porque cada municipio ya trae su clave y el nombre de su estado.
    """
    rows = db.execute(
        text(
            """
            SELECT DISTINCT cve_ent, estado
            FROM admin_boundary
            WHERE cve_ent IS NOT NULL
            ORDER BY estado
            """
        )
    ).all()
    return [{"cve_ent": r[0], "estado": r[1]} for r in rows]


def listar_municipios(db: Session, *, cve_ent: str | None = None) -> list[dict[str, str]]:
    """Catálogo de municipios, opcionalmente acotado a una entidad (CR-036)."""
    rows = db.execute(
        text(
            """
            SELECT cve_ent, cve_mun, estado, municipio
            FROM admin_boundary
            WHERE cve_mun IS NOT NULL
              AND (CAST(:cve_ent AS text) IS NULL OR cve_ent = :cve_ent)
            ORDER BY estado, municipio
            """
        ),
        {"cve_ent": cve_ent},
    ).all()
    return [
        {"cve_ent": r[0], "cve_mun": r[1], "estado": r[2], "municipio": r[3]} for r in rows
    ]
