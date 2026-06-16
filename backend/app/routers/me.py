"""Perfil y feedback del voluntario.

- ``GET /me/feedback`` — resumen **agregado** de aportaciones ("de tus últimas N, M aceptadas").
  Revisión humana (CR-001): toda observación se acepta al subir; un rechazo humano no se expone de
  forma individual. NUNCA acusación individual (gate Q5.A-D1).
- ``GET /me/profile`` — lifelist, etiqueta de identidad L3, insignias (sin desbloquear funciones).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..config import get_settings
from ..db import get_db
from ..deps import CurrentUser, get_current_user
from ..gamification import (
    account_lifelist,
    account_observation_count,
    account_points,
    compute_badges,
)
from ..models import Account
from ..schemas import FeedbackAggregate, ProfileResponse

router = APIRouter(prefix="/me", tags=["me"])


@router.get("/feedback", response_model=FeedbackAggregate)
def feedback(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> FeedbackAggregate:
    """Resumen AGREGADO sobre las últimas N observaciones (sin acusación individual, CR-001).

    Toda observación se acepta al subir; ``validas`` cuenta las **no-rechazadas** en la ventana.
    """
    settings = get_settings()
    window = settings.feedback_window
    rows = db.execute(
        text(
            """
            SELECT estado_revision FROM observation
            WHERE account_id = :a
            ORDER BY captured_at DESC
            LIMIT :n
            """
        ),
        {"a": user.account_id, "n": window},
    ).all()
    total = len(rows)
    validas = sum(1 for r in rows if r[0] != "rechazada")
    if total == 0:
        message = "Aún no tienes observaciones para mostrar tu resumen."
    else:
        message = f"De tus últimas {total} observaciones, {validas} siguen aceptadas."
    return FeedbackAggregate(
        window=window, total_considered=total, validas=validas, message=message
    )


@router.get("/profile", response_model=ProfileResponse)
def profile(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> ProfileResponse:
    account = db.get(Account, user.account_id)
    institution = account.institution.name if account and account.institution else None
    obs_count = account_observation_count(db, user.account_id)
    return ProfileResponse(
        handle=user.handle,
        identity_label=account.identity_label if account else "nuevo_observador",
        institution=institution,
        lifelist_trees=account_lifelist(db, user.account_id),
        total_observations=obs_count,
        total_points=account_points(db, user.account_id),
        badges=compute_badges(obs_count),
    )
