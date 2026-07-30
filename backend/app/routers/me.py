"""Perfil y feedback del voluntario.

- ``GET /me/feedback`` — resumen **agregado** de aportaciones ("subiste N, M confirmadas").
  Revisión humana (CR-001): toda observación se acepta al subir; un rechazo humano no se expone de
  forma individual. NUNCA acusación individual (gate Q5.A-D1).
- ``GET /me/profile`` — lifelist, etiqueta de identidad L3, insignias (sin desbloquear funciones).
- ``POST /me/sessions`` / ``GET /me/evidence`` (CR-010, #7) — evidencia por tiempo de sesión: el
  cliente reporta inicio/fin de sesión; la evidencia agrega capturas + horas (descriptiva, gate #1).

**CR-026 (solicitud de las universidades participantes):** lo que se *presenta* como participación
son las observaciones **confirmadas**; las horas de sesión se retiran de la pantalla de la app por
medir tiempo de app abierta y no trabajo de campo. Nada se deja de capturar: ``horas_totales``,
``sesiones`` y el total crudo de capturas se siguen calculando y viajando en la respuesta.

**CR-030 (reporte de voluntarios: "solo deja registrar 20"):** los tres endpoints presentan ahora el
**total real subido** junto al confirmado. El resumen de ``/me/feedback`` dejó de calcularse sobre
"las últimas 20" (la ventana era un recorte que se leía como tope de captura) y ``en_revision`` viaja
explícito para que la app no lo deduzca restando. El criterio de CR-026 sobre qué cuenta como
*válida* **no se toca**: se añade el dato crudo al lado.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, get_current_user, require_role
from ..gamification import (
    account_lifelist,
    account_points,
    account_review_counts,
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
    """Resumen AGREGADO de TODAS las observaciones de la cuenta (sin acusación individual, CR-001).

    CR-026: ``validas`` cuenta las **confirmadas** por revisión humana. El mensaje nombra además las
    que siguen en revisión, para que la diferencia entre lo subido y lo confirmado no se lea como un
    rechazo: la mayor parte de esa brecha es cola de revisión, no calidad. Nunca se expone el
    resultado de una foto en particular (gate Q5.A-D1).

    **CR-030:** se retiró la ventana de 20 (``settings.feedback_window``). El texto resultante decía
    "de tus últimas 20 observaciones" y **se congelaba en 20** para quien pasara de 20 — voluntarios
    con 22, 27, 31 y 37 capturas reales lo leyeron como un tope de registro. Ahora el mensaje abre
    con el **total real subido**, que es el número que el voluntario reconoce.

    El mensaje NO nombra las rechazadas (decisión del usuario, 2026-07-29): sigue el criterio de
    CR-001 de no dar feedback de rechazo, ni siquiera agregado. Consecuencia asumida: para quien
    tenga rechazos, confirmadas + en revisión no suman el total, y esa diferencia no se explica.
    """
    counts = account_review_counts(db, user.account_id)
    total = counts["total"]
    validas = counts["confirmada"]
    en_revision = counts["aceptada"]
    if total == 0:
        message = "Aún no tienes observaciones para mostrar tu resumen."
    else:
        # Concordancia explícita: el texto lo lee un voluntario, no un log.
        subidas = "observación" if total == 1 else "observaciones"
        confirmadas_frase = (
            "1 ya está confirmada" if validas == 1 else f"{validas} ya están confirmadas"
        )
        revision_frase = (
            "1 sigue en revisión" if en_revision == 1 else f"{en_revision} siguen en revisión"
        )
        message = f"Subiste {total} {subidas}. {confirmadas_frase} y {revision_frase}."
    return FeedbackAggregate(
        # `window` queda deprecado (CR-030) pero se sigue enviando por los bundles en caché.
        window=total,
        total_considered=total,
        validas=validas,
        en_revision=en_revision,
        message=message,
    )


@router.get("/profile", response_model=ProfileResponse)
def profile(
    user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)
) -> ProfileResponse:
    account = db.get(Account, user.account_id)
    institution = account.institution.name if account and account.institution else None
    # CR-026: el perfil presenta lo confirmado (conteo, insignias, lifelist y puntos).
    # CR-030: además viaja el total crudo subido, para que la app pueda mostrar el número que el
    # voluntario reconoce junto al confirmado. No redefine nada: `total_observations` sigue igual.
    counts = account_review_counts(db, user.account_id)
    confirmed = counts["confirmada"]
    return ProfileResponse(
        handle=user.handle,
        identity_label=account.identity_label if account else "nuevo_observador",
        institution=institution,
        lifelist_trees=account_lifelist(db, user.account_id),
        total_observations=confirmed,
        total_uploaded=counts["total"],
        en_revision=counts["aceptada"],
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
    # CR-030: los tres conteos salen de una sola consulta agregada, y `en_revision` viaja explícito
    # para que la app no lo deduzca restando (esa resta contaba las rechazadas como si estuvieran
    # en cola: con 13 subidas / 12 confirmadas / 1 rechazada decía "1 sigue en revisión").
    counts = account_review_counts(db, user.account_id)
    capturas = counts["confirmada"]
    capturas_totales = counts["total"]
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
        en_revision=counts["aceptada"],
        horas_totales=horas,
        sesiones=int(row["n_sesiones"]),
        primera=row["primera"],
        ultima=row["ultima"],
    )
