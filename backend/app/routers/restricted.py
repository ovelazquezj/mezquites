"""Vista restringida — coords **exactas** para los roles de ``EXACT_LOCATION_ROLES`` (gate #5).

La justificación original (``aliado_firmante``) es protección del árbol (tala/vandalismo), no
privacidad del voluntario. **CR-023** amplía este acceso INTERNO a los roles administrativos/de
análisis (``administrador``/``admin_consorcio``/``analista``) para la presentación de reportes.
Es una enmienda ACOTADA al gate #5: la consola autenticada ve coords exactas, pero **el público
sigue viendo SOLO la celda de 300 m** (obfuscada). ``voluntario`` y ``evaluador`` NO acceden.
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
    limit: int = Query(2000, le=20000),
    user: CurrentUser = Depends(require_role(*EXACT_LOCATION_ROLES)),
    db: Session = Depends(get_db),
) -> list[RestrictedObservation]:
    """Coords EXACTAS. Requiere un rol de ``EXACT_LOCATION_ROLES`` (gate #5, enmendado por CR-023):
    ``aliado_firmante`` (protección del árbol) + ``administrador``/``admin_consorcio``/``analista``
    (presentación de reportes en la consola). El público sigue restringido a la celda de 300 m."""
    _ = latest_snapshot_label(db)
    rows = db.execute(
        text(
            """
            SELECT handle, ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lon,
                   nivel_g4, flag_cuscuta, flag_danio, estado, municipio,
                   captured_at, estado_revision
            FROM observation
            WHERE (CAST(:estado AS text) IS NULL OR estado = :estado)
            ORDER BY captured_at DESC
            LIMIT :limit
            """
        ),
        {"estado": estado, "limit": limit},
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
