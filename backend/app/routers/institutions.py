"""Catálogo público de instituciones (lista F3) — Q4.

``GET /institutions`` lista las instituciones **aprobadas**, **sin auth**, para que el voluntario
pueda elegir afiliación durante el alta (antes de tener token). Las **solicitadas** (ticket a EA3)
NO se exponen aquí. El alta y la gestión completa (aprobadas + solicitadas) viven en
``/admin/institutions`` (rol ``admin_consorcio``).

Boundary/gates: solo lectura de catálogo; sin PII; no gatea nada (Q4 sin gating).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Institution

router = APIRouter(prefix="/institutions", tags=["institutions"])


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
