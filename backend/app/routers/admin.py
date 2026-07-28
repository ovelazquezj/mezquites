"""Endpoints de la web admin del consorcio — rol ``admin_consorcio`` (Q6 amendment, Q4 F3, Q5.B).

- ``POST /admin/indicators/organizational`` — captura manual de indicadores organizacionales.
- ``POST /admin/allies`` — promueve una cuenta a ``aliado_firmante`` (acceso a coords exactas).
- ``POST /admin/snapshots`` — snapshot trimestral del dataset público.
- ``GET/POST /admin/institutions`` — lista F3 + "solicitar agregar" (status=solicitada, ticket EA3).
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, require_role
from ..institution_names import find_by_normalized_name
from ..models import Account, Institution, OrganizationalIndicator
from ..schemas import (
    AllyIn,
    InstitutionIn,
    InstitutionUpdateIn,
    OrganizationalIndicatorIn,
    SnapshotResponse,
)
from ..snapshots import create_snapshot

router = APIRouter(prefix="/admin", tags=["admin"])

# Consola del proyecto: el `administrador` (CR-002) y el legacy `admin_consorcio` (CR-011).
_admin = require_role("admin_consorcio", "administrador")


@router.post("/indicators/organizational", status_code=status.HTTP_201_CREATED)
def add_organizational_indicator(
    body: OrganizationalIndicatorIn,
    user: CurrentUser = Depends(_admin),
    db: Session = Depends(get_db),
) -> dict:
    """Captura manual de un indicador organizacional Q6 (mesas, eventos W3, menciones)."""
    ind = OrganizationalIndicator(key=body.key, value=body.value, estado=body.estado)
    db.add(ind)
    db.commit()
    return {"id": str(ind.id), "key": ind.key, "value": ind.value, "estado": ind.estado}


@router.post("/allies", status_code=status.HTTP_200_OK)
def add_ally(
    body: AllyIn, user: CurrentUser = Depends(_admin), db: Session = Depends(get_db)
) -> dict:
    """Promueve una cuenta existente a ``aliado_firmante`` (habilita coords exactas)."""
    account = db.query(Account).filter(Account.handle == body.handle).one_or_none()
    if account is None:
        raise HTTPException(status_code=404, detail="cuenta no encontrada")
    account.role = "aliado_firmante"
    db.commit()
    return {"handle": account.handle, "role": account.role}


@router.post("/snapshots", response_model=SnapshotResponse, status_code=status.HTTP_201_CREATED)
def make_snapshot(
    user: CurrentUser = Depends(_admin), db: Session = Depends(get_db)
) -> SnapshotResponse:
    snap = create_snapshot(db)
    db.commit()
    return SnapshotResponse(
        quarter=snap.quarter, created_at=snap.created_at, observations_total=snap.observations_total
    )


@router.get("/institutions")
def list_institutions(
    user: CurrentUser = Depends(_admin), db: Session = Depends(get_db)
) -> list[dict]:
    """Lista F3 completa (aprobadas + solicitadas)."""
    rows = db.query(Institution).order_by(Institution.name).all()
    return [
        {"id": str(i.id), "name": i.name, "estado": i.estado, "status": i.status} for i in rows
    ]


def _ya_existe(inst: Institution, consejo: str = "Úsala en vez de crear otra.") -> str:
    """Detalle del 409: nombra la institución existente para que el admin actúe sobre ESA (CR-028)."""
    situacion = "ya aprobada" if inst.status == "aprobada" else "pendiente de aprobación"
    return f'Ya existe la institución "{inst.name}" ({situacion}). {consejo}'


@router.post("/institutions", status_code=status.HTTP_201_CREATED)
def add_institution(
    body: InstitutionIn, user: CurrentUser = Depends(_admin), db: Session = Depends(get_db)
) -> dict:
    """Alta directa (aprobada) o "solicitar agregar" (solicitada → ticket a EA3).

    CR-028 (antiduplicados): si ya existe una con el mismo nombre canónico (sin acentos,
    minúsculas, espacios colapsados) responde **409** en vez de crear una gemela. Aquí sí conviene
    el error y no el reuso silencioso de ``/institutions/request``: el administrador ve la lista
    completa —incluidas las ``solicitada``—, así que puede aprobar o renombrar la que ya está; un
    alta que "no hace nada" le ocultaría que su captura era redundante.
    """
    existente = find_by_normalized_name(db, body.name)
    if existente is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=_ya_existe(existente))

    inst = Institution(
        name=body.name,
        estado=body.estado,
        status="solicitada" if body.request_only else "aprobada",
    )
    db.add(inst)
    try:
        db.commit()
    except IntegrityError:
        # Carrera con otra alta simultánea: el índice único la atrapó.
        db.rollback()
        existente = find_by_normalized_name(db, body.name)
        if existente is None:  # pragma: no cover - el índice solo falla por duplicado
            raise
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail=_ya_existe(existente)
        ) from None
    return {"id": str(inst.id), "name": inst.name, "estado": inst.estado, "status": inst.status}


@router.patch("/institutions/{institution_id}")
def update_institution(
    institution_id: uuid.UUID,
    body: InstitutionUpdateIn,
    user: CurrentUser = Depends(_admin),
    db: Session = Depends(get_db),
) -> dict:
    """Corrige el **nombre** y/o el **estado** de una institución del catálogo (CR-029).

    Antes no había forma de arreglar un nombre mal escrito sin entrar a la base (la deuda que dejó
    anotada CR-028). Notas de diseño:

    - **No cambia `status`**: para aprobar está ``POST .../approve``, en un solo sentido. Degradar
      una ``aprobada`` la sacaría del catálogo con voluntarios ya afiliados.
    - **Respeta el índice único de CR-028**: renombrar a un nombre que ya usa **otra** institución
      responde 409. La comprobación **excluye la propia fila**, así que corregir la escritura de una
      institución (mayúsculas, acentos, espacios) es legítimo aunque su nombre canónico no cambie.
    - **Renombrar no repunta nada**: las cuentas cuelgan del ``id``, no del nombre.
    """
    inst = db.get(Institution, institution_id)
    if inst is None:
        raise HTTPException(status_code=404, detail="institución no encontrada")

    if body.name is not None:
        otra = find_by_normalized_name(db, body.name)
        if otra is not None and otra.id != inst.id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=_ya_existe(otra, "Elige otro nombre."),
            )
        inst.name = body.name

    # `estado` se distingue por presencia, no por valor: mandar null explícitamente lo LIMPIA.
    if "estado" in body.model_fields_set:
        inst.estado = body.estado

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        otra = find_by_normalized_name(db, body.name or "")
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=_ya_existe(otra, "Elige otro nombre.")
            if otra is not None
            else "Ya existe una institución con ese nombre.",
        ) from None
    db.refresh(inst)
    return {"id": str(inst.id), "name": inst.name, "estado": inst.estado, "status": inst.status}


@router.post("/institutions/{institution_id}/approve")
def approve_institution(
    institution_id: uuid.UUID,
    user: CurrentUser = Depends(_admin),
    db: Session = Depends(get_db),
) -> dict:
    """Aprueba una institución **solicitada** (CR-011): pasa a ``aprobada`` y entra al catálogo
    público (``GET /institutions``), donde el voluntario ya puede elegirla."""
    inst = db.get(Institution, institution_id)
    if inst is None:
        raise HTTPException(status_code=404, detail="institución no encontrada")
    inst.status = "aprobada"
    db.commit()
    return {"id": str(inst.id), "name": inst.name, "estado": inst.estado, "status": inst.status}
