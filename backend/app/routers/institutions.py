"""Catálogo público de instituciones (lista F3) — Q4.

``GET /institutions`` lista las instituciones **aprobadas**, **sin auth**, para que el voluntario
pueda elegir afiliación durante el alta (antes de tener token). Las **solicitadas** (ticket a EA3)
NO se exponen aquí. El alta y la gestión completa (aprobadas + solicitadas) viven en
``/admin/institutions`` (rol ``admin_consorcio``).

Boundary/gates: solo lectura de catálogo; sin PII; no gatea nada (Q4 sin gating).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, require_role
from ..models import Institution
from ..schemas import InstitutionRequestIn, InstitutionRequestResponse

router = APIRouter(prefix="/institutions", tags=["institutions"])

# CR-010: el voluntario (también aliado_firmante/admin_consorcio) puede solicitar una institución
# nueva desde la app. Queda `solicitada` (ticket a EA3); no se aprueba sola (gate #3: no gatea nada).
_requester = require_role("voluntario", "aliado_firmante", "admin_consorcio")


@router.get("")
def list_public_institutions(
    estado: str | None = Query(None),
    db: Session = Depends(get_db),
) -> list[dict]:
    """Instituciones **aprobadas** (lista F3 pública), opcionalmente filtradas por estado (Q8)."""
    q = db.query(Institution).filter(Institution.status == "aprobada")
    if estado is not None:
        q = q.filter(Institution.estado == estado)
    rows = q.order_by(Institution.name).all()
    return [
        {"id": str(i.id), "name": i.name, "estado": i.estado, "status": i.status} for i in rows
    ]


@router.post(
    "/request",
    response_model=InstitutionRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
def request_institution(
    body: InstitutionRequestIn,
    user: CurrentUser = Depends(_requester),
    db: Session = Depends(get_db),
) -> InstitutionRequestResponse:
    """El voluntario registra una institución nueva (CR-010). Queda ``solicitada`` (ticket a EA3).

    NO aparece en el catálogo público (``GET /institutions`` solo lista aprobadas) hasta que el
    ``admin_consorcio`` la apruebe. Sin PII (gate #2); no gatea nada (gate #3).
    """
    inst = Institution(name=body.name, estado=body.estado, status="solicitada")
    db.add(inst)
    db.commit()
    db.refresh(inst)
    return InstitutionRequestResponse(id=inst.id, name=inst.name, status=inst.status)
