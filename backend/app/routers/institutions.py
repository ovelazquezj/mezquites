"""Catálogo público de instituciones (lista F3) — Q4.

``GET /institutions`` lista las instituciones **aprobadas**, **sin auth**, para que el voluntario
pueda elegir afiliación durante el alta (antes de tener token). Las **solicitadas** (ticket a EA3)
NO se exponen aquí. El alta y la gestión completa (aprobadas + solicitadas) viven en
``/admin/institutions`` (rol ``admin_consorcio``).

Boundary/gates: solo lectura de catálogo; sin PII; no gatea nada (Q4 sin gating).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, require_role
from ..institution_names import find_by_normalized_name
from ..models import Account, Institution
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
    response: Response,
    user: CurrentUser = Depends(_requester),
    db: Session = Depends(get_db),
) -> InstitutionRequestResponse:
    """El voluntario registra una institución nueva (CR-010). Queda ``solicitada`` (ticket a EA3).

    NO aparece en el catálogo público (``GET /institutions`` solo lista aprobadas) hasta que el
    administrador la apruebe. Sin PII (gate #2); no gatea nada (gate #3).

    CR-011 (decisión A): la institución solicitada se **asocia** a la cuenta que la registra (su
    ``institution_id``), para que el flujo de alta desde el login quede completo aunque la institución
    siga pendiente de aprobación.

    CR-028 (antiduplicados): si ya existe una institución con el **mismo nombre canónico** no se
    crea otra — la cuenta queda afiliada a la existente y se responde **200** con
    ``ya_existia=True`` (crear devuelve 201). Reusar en vez de rechazar es deliberado: el catálogo
    público solo muestra las ``aprobada``, así que quien escribe el nombre de una institución
    todavía ``solicitada`` no la ve en la lista y no tiene forma de "elegirla"; un 409 lo dejaría
    sin salida y rompería el gate #3 (nada bloquea al voluntario). Este reuso es lo que cierra el
    lazo que venía fabricando duplicados.
    """
    existente = find_by_normalized_name(db, body.name)
    ya_existia = existente is not None
    if existente is not None:
        inst = existente
    else:
        inst = Institution(name=body.name, estado=body.estado, status="solicitada")
        db.add(inst)
        try:
            db.flush()  # obtiene inst.id antes de asociar
        except IntegrityError:
            # El índice único ganó: otra alta simultánea creó el mismo nombre entre la búsqueda y
            # el flush. Se descarta el INSERT y se reusa la que quedó.
            db.rollback()
            inst = find_by_normalized_name(db, body.name)
            if inst is None:  # pragma: no cover - el índice solo puede fallar por un duplicado
                raise
            ya_existia = True

    account = db.get(Account, user.account_id)
    if account is not None:
        account.institution_id = inst.id
    db.commit()
    db.refresh(inst)
    if ya_existia:
        response.status_code = status.HTTP_200_OK
    return InstitutionRequestResponse(
        id=inst.id, name=inst.name, status=inst.status, ya_existia=ya_existia
    )
