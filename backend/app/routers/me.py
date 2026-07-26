"""Perfil y feedback del voluntario.

- ``GET /me/feedback`` — resumen **agregado** de aportaciones ("de tus últimas N, M confirmadas").
  Revisión humana (CR-001): toda observación se acepta al subir; un rechazo humano no se expone de
  forma individual. NUNCA acusación individual (gate Q5.A-D1).
- ``GET /me/profile`` — lifelist, etiqueta de identidad L3, insignias (sin desbloquear funciones).
- ``POST /me/sessions`` / ``GET /me/evidence`` (CR-010, #7) — evidencia por tiempo de sesión: el
  cliente reporta inicio/fin de sesión; la evidencia agrega capturas + horas (descriptiva, gate #1).

**CR-026 (solicitud de las universidades participantes):** lo que se *presenta* como participación
son las observaciones **confirmadas**; las horas de sesión se retiran de la pantalla de la app por
medir tiempo de app abierta y no trabajo de campo. Nada se deja de capturar: ``horas_totales``,
``sesiones`` y el total crudo de capturas se siguen calculando y viajando en la respuesta.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..config import get_settings
from ..db import get_db
from ..deps import CurrentUser, get_current_user, require_role
from ..gamification import (
    account_confirmed_count,
    account_lifelist,
    account_observation_count,
    account_points,
    compute_badges,
)
from ..models import Account, ParticipationSession
from ..schemas import (
    EvidenceResponse,
    FeedbackAggregate,
    ProfileResponse,
    SessionCreate,
    SessionResponse,
)

router = APIRouter(prefix="/me", tags=["me"])

# Sesiones/evidencia: rol del voluntario (también aliado_firmante/admin_consorcio que capturan).
_volunteer = require_role("voluntario", "aliado_firmante", "admin_consorcio")


@router.get("/feedback", response_model=FeedbackAggregate)
def feedback(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> FeedbackAggregate:
    """Resumen AGREGADO sobre las últimas N observaciones (sin acusación individual, CR-001).

    CR-026: ``validas`` cuenta las **confirmadas** por revisión humana. El mensaje nombra además las
    que siguen en revisión, para que la diferencia entre lo subido y lo confirmado no se lea como un
    rechazo: la mayor parte de esa brecha es cola de revisión, no calidad. Nunca se expone el
    resultado de una foto en particular (gate Q5.A-D1).
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
    validas = sum(1 for r in rows if r[0] == "confirmada")
    en_revision = sum(1 for r in rows if r[0] == "aceptada")
    if total == 0:
        message = "Aún no tienes observaciones para mostrar tu resumen."
    else:
        message = (
            f"De tus últimas {total} observaciones, {validas} ya están confirmadas "
            f"y {en_revision} siguen en revisión."
        )
    return FeedbackAggregate(
        window=window, total_considered=total, validas=validas, message=message
    )


@router.get("/profile", response_model=ProfileResponse)
def profile(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> ProfileResponse:
    account = db.get(Account, user.account_id)
    institution = account.institution.name if account and account.institution else None
    # CR-026: el perfil presenta lo confirmado (conteo, insignias, lifelist y puntos).
    confirmed = account_confirmed_count(db, user.account_id)
    return ProfileResponse(
        handle=user.handle,
        identity_label=account.identity_label if account else "nuevo_observador",
        institution=institution,
        lifelist_trees=account_lifelist(db, user.account_id),
        total_observations=confirmed,
        total_points=account_points(db, user.account_id),
        badges=compute_badges(confirmed),
    )


@router.post("/sessions", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
def create_session(
    body: SessionCreate,
    user: CurrentUser = Depends(_volunteer),
    db: Session = Depends(get_db),
) -> SessionResponse:
    """Registra una sesión de participación (CR-010, #7).

    El cliente reporta inicio/fin (lifecycle de la app); el backend calcula ``duration_seconds`` y la
    persiste para la evidencia y la analítica. Gate #2: solo ``account_id`` (seudónimo) + tiempos.
    """
    duration = (body.ended_at - body.started_at).total_seconds()
    if duration < 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="ended_at debe ser >= started_at",
        )
    sesion = ParticipationSession(
        account_id=user.account_id,
        started_at=body.started_at,
        ended_at=body.ended_at,
        duration_seconds=int(duration),
    )
    db.add(sesion)
    db.commit()
    db.refresh(sesion)
    return SessionResponse(
        id=sesion.id,
        started_at=sesion.started_at,
        ended_at=sesion.ended_at,
        duration_seconds=sesion.duration_seconds,
    )


@router.get("/evidence", response_model=EvidenceResponse)
def evidence(
    user: CurrentUser = Depends(_volunteer),
    db: Session = Depends(get_db),
) -> EvidenceResponse:
    """Evidencia de participación del voluntario (CR-010, #7) — en pantalla, descriptiva (gate #1).

    ``capturas`` = observaciones **confirmadas** (CR-026: es lo que la app presenta como
    participación); ``capturas_totales`` = total crudo subido, que se conserva como denominador del
    avance de revisión; ``horas_totales`` = Σ ``duration_seconds`` / 3600; ``sesiones`` = nº de
    sesiones; ``primera``/``ultima`` = rango de inicio de sesión.

    Las horas se siguen calculando y devolviendo aunque la app ya no las pinte (CR-026): son dato de
    análisis para la institución, no evidencia de trabajo de campo.
    """
    capturas = account_confirmed_count(db, user.account_id)
    capturas_totales = account_observation_count(db, user.account_id)
    row = db.execute(
        text(
            """
            SELECT COALESCE(sum(duration_seconds), 0) AS total_seg,
                   count(*) AS n_sesiones,
                   min(started_at) AS primera,
                   max(started_at) AS ultima
            FROM participation_session
            WHERE account_id = :a
            """
        ),
        {"a": user.account_id},
    ).mappings().one()
    horas = round(float(row["total_seg"]) / 3600.0, 4)
    return EvidenceResponse(
        capturas=capturas,
        capturas_totales=capturas_totales,
        horas_totales=horas,
        sesiones=int(row["n_sesiones"]),
        primera=row["primera"],
        ultima=row["ultima"],
    )
