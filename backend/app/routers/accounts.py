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
- ``GET    /admin/accounts`` — busca cuentas por handle **o username** (CR-040).
- ``DELETE /admin/accounts/{id}`` — Cancelación ARCO (anonimiza + elimina identidad + audita).

**CR-040 (administración de cuentas desde la consola):** el borrado de un usuario de consola pasa
por este mismo endpoint, así que la búsqueda mira también el ``username`` (el handle de esas cuentas
es autogenerado y nadie lo conoce) y el repunte cubre las **6** FKs a ``account`` — faltaban
``participation_session`` (NOT NULL: el borrado fallaba para cualquiera con sesiones),
``problem_report`` y ``account_deletion.executed_by_account_id``. La cuenta de administrador
principal (``BOOTSTRAP_ADMIN_USERNAME``) queda **protegida**: eliminarla dejaría el sistema sin
forma de crear administradores desde la API.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from ..bootstrap import es_cuenta_protegida
from ..config import get_settings
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
    ParticipationSession,
    PointsLedger,
    ProblemReport,
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
    handle: str | None = Query(
        None, description="Busca por coincidencia parcial en el handle O el nombre de usuario."
    ),
    q: str | None = Query(
        None, description="Alias de `handle` (mismo significado). Gana el primero no vacío."
    ),
    limit: int = Query(50, le=200),
    user: CurrentUser = Depends(_administrador),
    db: Session = Depends(get_db),
) -> list[AdminAccountSummary]:
    """Busca cuentas para localizar la que se va a cancelar. No expone PII (solo ``has_email``).

    CR-040: la búsqueda mira **handle y username**. Antes solo miraba el handle, así que un usuario
    de consola era **inencontrable**: su handle es autogenerado (``obs-XXXXXX``) y nadie lo conoce —
    se le conoce por el `username` con el que entra. El administrador que intentaba eliminarlo no
    obtenía ninguna fila y no había forma de llegar al `id` para el DELETE.
    """
    termino = next((t.strip() for t in (handle, q) if t and t.strip()), None)
    consulta = db.query(Account).filter(Account.id != SENTINEL_ACCOUNT_ID)
    if termino:
        patron = f"%{termino}%"
        # `username` es NULL en las cuentas del voluntario: el OR con NULL no las excluye porque el
        # otro lado (handle) decide; una fila solo se filtra si NINGÚN lado coincide.
        consulta = consulta.filter(
            or_(Account.handle.ilike(patron), Account.username.ilike(patron))
        )
    rows = consulta.order_by(Account.created_at.desc()).limit(limit).all()
    settings = get_settings()
    return [
        AdminAccountSummary(
            id=a.id,
            handle=a.handle,
            username=a.username,
            role=a.role,
            auth_provider=a.auth_provider,
            has_email=bool(a.email),
            observations=_count_observations(db, a.id),
            protected=es_cuenta_protegida(a, settings),
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
    colgando. No se puede eliminar la cuenta centinela, la propia cuenta del administrador ni la
    cuenta de administrador principal (CR-040).
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
    if es_cuenta_protegida(account, get_settings()):
        raise HTTPException(
            status_code=400, detail="la cuenta de administrador principal no se puede eliminar"
        )

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

    # 2) Repunta TODO lo que apunta a la cuenta (no romper FKs) — la misma transacción.
    #    Son las 6 FKs a `account.id` que existen en el modelo; si alguna se olvida, el DELETE
    #    revienta con IntegrityError (500) justo para las cuentas más activas. CR-040 añadió
    #    `participation_session` (NOT NULL, sin ON DELETE ⇒ el borrado FALLABA para cualquier
    #    voluntario con sesiones registradas), `problem_report` y `account_deletion`.
    db.query(PointsLedger).filter(PointsLedger.account_id == account_id).update(
        {PointsLedger.account_id: sentinel.id}, synchronize_session=False
    )
    db.query(HumanReview).filter(HumanReview.reviewer_account_id == account_id).update(
        {HumanReview.reviewer_account_id: sentinel.id}, synchronize_session=False
    )
    db.query(ParticipationSession).filter(
        ParticipationSession.account_id == account_id
    ).update({ParticipationSession.account_id: sentinel.id}, synchronize_session=False)
    # El reporte de problema conserva el dato de diagnóstico (user_agent/plataforma/mensaje) y
    # pierde el vínculo con la persona: handle anónimo, igual que las observaciones (gate #2).
    db.query(ProblemReport).filter(ProblemReport.account_id == account_id).update(
        {ProblemReport.account_id: sentinel.id, ProblemReport.handle: ANON_HANDLE},
        synchronize_session=False,
    )
    # Auditorías que ESTA cuenta ejecutó (si era administradora). `deleted_account_id` no es FK y no
    # se toca: el registro de QUÉ se eliminó sobrevive intacto (gate #7). Lo que se anonimiza es
    # QUIÉN lo ejecutó — su identidad está desapareciendo en esta misma operación, igual que ya se
    # hacía con el revisor de `human_review`.
    db.query(AccountDeletion).filter(
        AccountDeletion.executed_by_account_id == account_id
    ).update({AccountDeletion.executed_by_account_id: sentinel.id}, synchronize_session=False)

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
