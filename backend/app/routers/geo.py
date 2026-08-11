"""Geografía derivada — CR-036.

Tres rutas que exponen lo que sabe ``admin_boundary``:

- ``GET /geo/resolve`` — a qué municipio pertenece un punto. **La consume la app del voluntario**
  para MOSTRARLE dónde va a quedar su registro, sin pedirle que lo seleccione. Es informativa: el
  servidor vuelve a resolver al recibir el POST, así que la respuesta de aquí nunca es la que se
  guarda. Si el cliente está sin red, no la llama y no pasa nada — la captura offline (CR-031) sigue
  funcionando y la ubicación se resuelve al subir.
- ``GET /geo/estados`` y ``GET /geo/municipios`` — catálogo para los **filtros de la consola**
  (Panel público y Datos). Ya no alimentan ningún dropdown de captura: la app no vuelve a preguntar
  la ubicación.

**Por qué son públicas (sin token).** Los límites municipales del INEGI son información pública, y
el Panel público de la consola filtra por estado sin sesión iniciada. No revelan ningún dato del
piloto: son polígonos administrativos, no observaciones. ``/geo/resolve`` tampoco filtra nada del
dataset — responde lo mismo para un punto haya o no haya mezquites ahí.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..db import get_db
from ..geo import listar_estados, listar_municipios, resolver_ubicacion
from ..schemas import GeoEstado, GeoMunicipio, GeoResolucion

router = APIRouter(prefix="/geo", tags=["geo"])


@router.get("/resolve", response_model=GeoResolucion)
def resolve(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    db: Session = Depends(get_db),
) -> GeoResolucion:
    """Resuelve un punto a su estado/municipio (CR-036).

    Un punto fuera de todo polígono **no es un error**: responde 200 con ``resuelto=false`` y los
    campos en null. El cliente muestra las coordenadas y sigue adelante.
    """
    u = resolver_ubicacion(db, lat=lat, lon=lon)
    return GeoResolucion(
        estado=u.estado,
        municipio=u.municipio,
        cve_ent=u.cve_ent,
        cve_mun=u.cve_mun,
        resuelto=u.resuelto,
    )


@router.get("/estados", response_model=list[GeoEstado])
def estados(db: Session = Depends(get_db)) -> list[GeoEstado]:
    """Entidades federativas con límites cargados, ordenadas por nombre."""
    return [GeoEstado(**e) for e in listar_estados(db)]


@router.get("/municipios", response_model=list[GeoMunicipio])
def municipios(
    cve_ent: str | None = Query(None, min_length=2, max_length=2),
    db: Session = Depends(get_db),
) -> list[GeoMunicipio]:
    """Municipios, opcionalmente acotados a una entidad.

    Sin ``cve_ent`` devuelve los ~2 478 del país: la consola siempre acota, pero se permite el
    catálogo completo para exportaciones y para poblar un selector combinado.
    """
    return [GeoMunicipio(**m) for m in listar_municipios(db, cve_ent=cve_ent)]
