"""Endpoints de la web admin del consorcio — rol ``admin_consorcio`` (Q6 amendment, Q4 F3, Q5.B).

- ``POST /admin/indicators/organizational`` — captura manual de indicadores organizacionales.
- ``POST /admin/allies`` — promueve una cuenta a ``aliado_firmante`` (acceso a coords exactas).
- ``POST /admin/snapshots`` — snapshot trimestral del dataset público.
- ``GET/POST /admin/institutions`` — lista F3 + "solicitar agregar" (status=solicitada, ticket EA3).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, require_role
from ..models import Account, Institution, OrganizationalIndicator
from ..schemas import AllyIn, InstitutionIn, OrganizationalIndicatorIn, SnapshotResponse
from ..snapshots import create_snapshot

router = APIRouter(prefix="/admin", tags=["admin"])

_admin = require_role("admin_consorcio")


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


@router.post("/institutions", status_code=status.HTTP_201_CREATED)
def add_institution(
    body: InstitutionIn, user: CurrentUser = Depends(_admin), db: Session = Depends(get_db)
) -> dict:
    """Alta directa (aprobada) o "solicitar agregar" (solicitada → ticket a EA3)."""
    inst = Institution(
        name=body.name,
        estado=body.estado,
        status="solicitada" if body.request_only else "aprobada",
    )
    db.add(inst)
    db.commit()
    return {"id": str(inst.id), "name": inst.name, "estado": inst.estado, "status": inst.status}
