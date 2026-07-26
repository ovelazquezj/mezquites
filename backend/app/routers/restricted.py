"""Vista restringida — coords **exactas** + ``estado_revision`` para la consola autenticada.

Sirve la ubicación exacta del árbol a los roles de ``EXACT_LOCATION_ROLES``. Por decisión de
gobernanza del Club (CR-025), todos los roles de la consola reciben las coords exactas (incluido
``evaluador``); ``voluntario`` no tiene acceso a la consola.

CR-026: el mapa público pasó a mostrar solo observaciones ``confirmada``, pero **esta vista sigue
alcanzando todos los estados** mediante el filtro opcional ``estado_revision``. Es deliberado: es la
vista de trabajo de la consola, y restringirla a confirmadas le escondería al evaluador justamente
lo que le falta revisar. La consola la usa con selector (default ``confirmada``, igual que el mapa
público).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, require_role
from ..models import EXACT_LOCATION_ROLES
from ..schemas import RestrictedObservation
from ..snapshots import latest_snapshot_label

router = APIRouter(prefix="/restricted", tags=["restricted"])


@router.get("/observations", response_model=list[RestrictedObservation])
def restricted_observations(
    estado: str | None = Query(None),
    estado_revision: str | None = Query(
        None,
        description=(
            "Filtra por estado de revisión (aceptada|confirmada|rechazada). "
            "Sin valor devuelve TODOS los estados (vista de trabajo de la consola, CR-026)."
        ),
    ),
    limit: int = Query(2000, le=20000),
    user: CurrentUser = Depends(require_role(*EXACT_LOCATION_ROLES)),
    db: Session = Depends(get_db),
) -> list[RestrictedObservation]:
    """Coords EXACTAS + ``estado_revision`` para la consola. Requiere un rol de
    ``EXACT_LOCATION_ROLES`` (CR-025): todos los roles de la consola (incluido ``evaluador``).

    CR-026: ``estado_revision`` permite al mapa de la consola conmutar entre confirmadas y el resto;
    omitirlo devuelve todo, para no ocultar la cola de revisión."""
    _ = latest_snapshot_label(db)
    rows = db.execute(
        text(
            """
            SELECT handle, ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lon,
                   nivel_g4, flag_cuscuta, flag_danio, estado, municipio,
                   captured_at, estado_revision
            FROM observation
            WHERE (CAST(:estado AS text) IS NULL OR estado = :estado)
              AND (CAST(:estado_revision AS text) IS NULL OR estado_revision = :estado_revision)
            ORDER BY captured_at DESC
            LIMIT :limit
            """
        ),
        {"estado": estado, "estado_revision": estado_revision, "limit": limit},
    ).mappings().all()

    return [
        RestrictedObservation(
            handle=r["handle"],
            lat=float(r["lat"]),
            lon=float(r["lon"]),
            nivel_g4=r["nivel_g4"],
            flag_cuscuta=r["flag_cuscuta"],
            flag_danio=r["flag_danio"],
            estado=r["estado"],
            municipio=r["municipio"],
            captured_at=r["captured_at"],
            estado_revision=r["estado_revision"],
        )
        for r in rows
    ]
