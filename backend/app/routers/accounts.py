"""ARCO — Cancelación de cuenta (eliminar + anonimizar) por el **administrador** (CR-006).

Derecho ARCO de **Cancelación** (LFPDPPP): el titular pide eliminar su cuenta; por ahora lo ejecuta
el ``administrador`` desde la web admin (no auto-servicio). Al eliminar:

- **Anonimiza** las observaciones de la persona: se repunta ``account_id`` a una **cuenta centinela
  "eliminada"** y el ``handle`` denormalizado pasa a ``anonimo``; geom/etiquetas/estado_revision se
  conservan intactos ⇒ el **dato ecológico permanece** y el **dataset público sigue funcionando**.
- **Elimina la identidad**: se borra la fila de ``account`` (provider_subject/username/password_hash/
  email/recovery_hash desaparecen con ella). Tras esto **no queda PII** de esa persona (gate #2).
- **Audita sin PII** (gate #7): ``account_deletion`` guarda id opaco de la cuenta, quién la ejecutó,
  rol, motivo y conteo — nunca email/sub/username.

Gate de rol: **SOLO ``administrador``** (no `admin_consorcio`). Endpoints:
- ``GET    /admin/accounts`` — busca cuentas por handle (para localizar la cuenta a eliminar).
- ``DELETE /admin/accounts/{id}`` — Cancelación ARCO (anonimiza + elimina identidad + audita).
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, require_role
from ..models import (
    ANON_HANDLE,
    SENTINEL_ACCOUNT_ID,
    SENTINEL_HANDLE,
    Account,
    AccountDeletion,
    HumanReview,
    Observation,
    PointsLedger,
)
from ..schemas import AdminAccountSummary, DeleteAccountRequest, DeleteAccountResponse

router = APIRouter(prefix="/admin/accounts", tags=["admin-accounts"])

_administrador = require_role("administrador")


def ensure_sentinel_account(db: Session) -> Account:
    """Devuelve (creándola si hace falta) la cuenta centinela "eliminada".

    Sin PII: id y handle fijos, rol ``voluntario``, ``social_google`` sin ``provider_subject``. Es el
    destino al que se repuntan observaciones/puntos/revisiones de cuentas canceladas (CR-006).
    """
    sentinel = db.get(Account, SENTINEL_ACCOUNT_ID)
    if sentinel is None:
        sentinel = Account(
            id=SENTINEL_ACCOUNT_ID,
            handle=SENTINEL_HANDLE,
            auth_provider="social_google",
            provider_subject=None,
            role="voluntario",
            identity_label="cuenta_eliminada",
        )
        db.add(sentinel)
        db.flush()
    return sentinel


def _count_observations(db: Session, account_id: uuid.UUID) -> int:
    return (
        db.query(func.count(Observation.id))
        .filter(Observation.account_id == account_id)
        .scalar()
        or 0
    )


@router.get("", response_model=list[AdminAccountSummary])
def search_accounts(
    handle: str | None = Query(None, description="Filtra por coincidencia parcial de handle."),
    limit: int = Query(50, le=200),
    user: CurrentUser = Depends(_administrador),
    db: Session = Depends(get_db),
) -> list[AdminAccountSummary]:
    """Busca cuentas para localizar la que se va a cancelar. No expone PII (solo ``has_email``)."""
    q = db.query(Account).filter(Account.id != SENTINEL_ACCOUNT_ID)
    if handle:
        q = q.filter(Account.handle.ilike(f"%{handle}%"))
    rows = q.order_by(Account.created_at.desc()).limit(limit).all()
    return [
        AdminAccountSummary(
            id=a.id,
            handle=a.handle,
            role=a.role,
            auth_provider=a.auth_provider,
            has_email=bool(a.email),
            observations=_count_observations(db, a.id),
        )
        for a in rows
    ]


@router.delete("/{account_id}", response_model=DeleteAccountResponse)
def delete_account(
    account_id: uuid.UUID,
    body: DeleteAccountRequest | None = None,
    user: CurrentUser = Depends(_administrador),
    db: Session = Depends(get_db),
) -> DeleteAccountResponse:
    """Cancelación ARCO: anonimiza observaciones + elimina identidad + audita (gates #2/#7).

    Atómico: todo ocurre en una transacción; si algo falla, no se rompe el dataset ni quedan FKs
    colgando. No se puede eliminar la cuenta centinela ni la propia cuenta del administrador.
    """
    if account_id == SENTINEL_ACCOUNT_ID:
        raise HTTPException(status_code=400, detail="no se puede eliminar la cuenta centinela")
    if account_id == user.account_id:
        raise HTTPException(
            status_code=400, detail="el administrador no puede eliminar su propia cuenta"
        )

    account = db.get(Account, account_id)
    if account is None:
        raise HTTPException(status_code=404, detail="cuenta no encontrada")

    deleted_role = account.role
    reason = body.reason if body else None

    sentinel = ensure_sentinel_account(db)

    # 1) Anonimiza las observaciones: rompe el vínculo a la persona conservando el dato ecológico.
    obs_count = (
        db.query(Observation)
        .filter(Observation.account_id == account_id)
        .update(
            {Observation.account_id: sentinel.id, Observation.handle: ANON_HANDLE},
            synchronize_session=False,
        )
    )

    # 2) Repunta el ledger de puntos y las revisiones que esta cuenta hizo (no romper FKs NOT NULL).
    db.query(PointsLedger).filter(PointsLedger.account_id == account_id).update(
        {PointsLedger.account_id: sentinel.id}, synchronize_session=False
    )
    db.query(HumanReview).filter(HumanReview.reviewer_account_id == account_id).update(
        {HumanReview.reviewer_account_id: sentinel.id}, synchronize_session=False
    )

    # 3) Auditoría sin PII (gate #7) — ANTES de borrar la fila (executed_by es FK válida).
    db.add(
        AccountDeletion(
            deleted_account_id=account_id,
            executed_by_account_id=user.account_id,
            deleted_role=deleted_role,
            reason=reason,
            observations_anonymized=obs_count,
        )
    )

    # 4) Elimina la identidad: la fila de account (con provider_subject/username/email/hashes) se va.
    db.delete(account)

    db.commit()

    return DeleteAccountResponse(
        deleted_account_id=account_id,
        observations_anonymized=obs_count,
    )
