"""Revisión humana de observaciones desde el backend (CR-001).

Reemplaza la validación automática (YOLO). Personas con rol de revisión deciden la calidad de cada
observación; el veredicto y el etiquetado son **autoritativos en el backend** y quedan registrados en
el log append-only ``human_review`` (gate #7).

RBAC (``deps.require_role``):
- ``evaluador``, ``analista``, ``administrador``  → cola, detalle, imagen, stats.
- ``evaluador``, ``administrador``                → emitir veredicto (POST).
- ``analista``                                    → **solo lectura** (recibe 403 al emitir veredicto).

La imagen de revisión se sirve **cruda** (con su EXIF original, incluido el GPS de la cámara) a
todos los roles de revisión. El saneo de GPS (``exif.strip_gps``) quedó **ocioso** (CR-025): ya no
se aplica al servir la imagen.
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..db import get_db
from ..deps import CurrentUser, require_role
from ..gamification import refresh_identity_label
from ..models import REVIEW_ROLES, REVIEW_VERDICT_ROLES, HumanReview, Observation
from ..schemas import (
    HumanReviewEntry,
    ReviewObservationDetail,
    ReviewQueueItem,
    ReviewStats,
    VerdictRequest,
    VerdictResponse,
)
from ..storage import get_storage

router = APIRouter(prefix="/review", tags=["review"])

# Roles que pueden ver la cola de revisión (lectura). `analista` es solo lectura.
_reviewer = require_role(*REVIEW_ROLES)
# Roles que pueden emitir veredicto (NO incluye `analista`).
_verdict_role = require_role(*REVIEW_VERDICT_ROLES)
# Acceso a la imagen: roles de revisión + `aliado_firmante`. La imagen se sirve cruda (sin saneo de
# GPS): el saneo (`exif.strip_gps`) quedó ocioso (CR-025).
_image_role = require_role(*REVIEW_ROLES, "aliado_firmante")


@router.get("/queue", response_model=list[ReviewQueueItem])
def review_queue(
    estado_revision: str | None = Query(
        None, description="Filtra por estado de revisión (aceptada|confirmada|rechazada)."
    ),
    municipio: str | None = Query(None),
    estado: str | None = Query(None),
    desde: str | None = Query(None, description="ISO date/datetime: captured_at >= desde."),
    hasta: str | None = Query(None, description="ISO date/datetime: captured_at <= hasta."),
    limit: int = Query(100, le=1000),
    offset: int = Query(0, ge=0),
    user: CurrentUser = Depends(_reviewer),
    db: Session = Depends(get_db),
) -> list[ReviewQueueItem]:
    """Cola de revisión con filtros + paginación. No incluye coords (solo estado/municipio)."""
    rows = db.execute(
        text(
            """
            SELECT id, handle, captured_at, estado_revision, nivel_g4,
                   flag_cuscuta, flag_danio, tamanio, contexto, estado, municipio
            FROM observation
            WHERE (CAST(:estado_revision AS text) IS NULL OR estado_revision = :estado_revision)
              AND (CAST(:municipio AS text) IS NULL OR municipio = :municipio)
              AND (CAST(:estado AS text) IS NULL OR estado = :estado)
              AND (CAST(:desde AS timestamptz) IS NULL OR captured_at >= CAST(:desde AS timestamptz))
              AND (CAST(:hasta AS timestamptz) IS NULL OR captured_at <= CAST(:hasta AS timestamptz))
            ORDER BY captured_at DESC
            LIMIT :limit OFFSET :offset
            """
        ),
        {
            "estado_revision": estado_revision,
            "municipio": municipio,
            "estado": estado,
            "desde": desde,
            "hasta": hasta,
            "limit": limit,
            "offset": offset,
        },
    ).mappings().all()
    return [
        ReviewQueueItem(
            observation_id=r["id"],
            handle=r["handle"],
            captured_at=r["captured_at"],
            estado_revision=r["estado_revision"],
            nivel_g4=r["nivel_g4"],
            flag_cuscuta=r["flag_cuscuta"],
            flag_danio=r["flag_danio"],
            tamanio=r["tamanio"],
            contexto=r["contexto"],
            estado=r["estado"],
            municipio=r["municipio"],
        )
        for r in rows
    ]


@router.get("/observations/{observation_id}", response_model=ReviewObservationDetail)
def review_detail(
    observation_id: uuid.UUID,
    user: CurrentUser = Depends(_reviewer),
    db: Session = Depends(get_db),
) -> ReviewObservationDetail:
    """Detalle de una observación + historial de veredictos (no incluye coord)."""
    obs = db.get(Observation, observation_id)
    if obs is None:
        raise HTTPException(status_code=404, detail="observación no encontrada")

    historial_rows = db.execute(
        text(
            """
            SELECT hr.veredicto, hr.nota, a.handle AS reviewer_handle, hr.created_at
            FROM human_review hr
            JOIN account a ON a.id = hr.reviewer_account_id
            WHERE hr.observation_id = :oid
            ORDER BY hr.created_at ASC
            """
        ),
        {"oid": observation_id},
    ).mappings().all()

    return ReviewObservationDetail(
        observation_id=obs.id,
        handle=obs.handle,
        captured_at=obs.captured_at,
        estado_revision=obs.estado_revision,
        nivel_g4=obs.nivel_g4,
        flag_cuscuta=obs.flag_cuscuta,
        flag_danio=obs.flag_danio,
        tamanio=obs.tamanio,
        contexto=obs.contexto,
        estado=obs.estado,
        municipio=obs.municipio,
        historial=[
            HumanReviewEntry(
                veredicto=h["veredicto"],
                nota=h["nota"],
                reviewer_handle=h["reviewer_handle"],
                created_at=h["created_at"],
            )
            for h in historial_rows
        ],
    )


@router.get("/observations/{observation_id}/image")
def review_image(
    observation_id: uuid.UUID,
    user: CurrentUser = Depends(_image_role),
    db: Session = Depends(get_db),
) -> Response:
    """Sirve la imagen para revisión, **cruda** (con su EXIF original).

    El saneo de GPS del EXIF (``exif.strip_gps``) quedó ocioso (CR-025): la imagen se entrega tal
    cual a todos los roles de revisión.
    """
    obs = db.get(Observation, observation_id)
    if obs is None:
        raise HTTPException(status_code=404, detail="observación no encontrada")

    storage = get_storage()
    try:
        data = storage.get(obs.image_ref)
    except Exception:
        raise HTTPException(status_code=404, detail="imagen no encontrada")

    content_type = "image/jpeg"
    if obs.image_ref.lower().endswith(".png"):
        content_type = "image/png"

    return Response(content=data, media_type=content_type)


@router.post("/observations/{observation_id}/verdict", response_model=VerdictResponse)
def review_verdict(
    observation_id: uuid.UUID,
    body: VerdictRequest,
    user: CurrentUser = Depends(_verdict_role),
    db: Session = Depends(get_db),
) -> VerdictResponse:
    """Emite un veredicto humano (aceptada|confirmada|rechazada). Autoritativo en backend (CR-001).

    Inserta una fila en ``human_review`` (log append-only, gate #7) y actualiza
    ``observation.estado_revision``. CR-010: ``aceptada`` revierte la observación a "pendiente de
    revisión" (deshace una confirmación/rechazo previo).

    **CR-026:** el veredicto es lo que hace contar (o dejar de contar) la observación en el perfil
    del voluntario, en sus insignias, en sus puntos y en el mapa público. Las filas de
    ``points_ledger`` no se tocan —el filtro se aplica al leer—, pero sí hay que recomputar la
    etiqueta de identidad L3, que está persistida en ``account``.
    """
    obs = db.get(Observation, observation_id)
    if obs is None:
        raise HTTPException(status_code=404, detail="observación no encontrada")

    db.add(
        HumanReview(
            observation_id=observation_id,
            reviewer_account_id=user.account_id,
            veredicto=body.veredicto,
            nota=body.nota,
        )
    )
    obs.estado_revision = body.veredicto
    db.flush()
    # La L3 depende del nº de confirmadas (CR-026): sin esto quedaría congelada en el valor que
    # tenía al subir la observación.
    refresh_identity_label(db, obs.account_id)
    db.commit()

    if body.veredicto == "rechazada":
        message = "Observación rechazada: deja de aparecer en el panel público."
    elif body.veredicto == "aceptada":
        message = "Observación devuelta a aceptada (pendiente de revisión)."
    else:
        message = "Observación confirmada."
    return VerdictResponse(
        observation_id=observation_id, estado_revision=body.veredicto, message=message
    )


@router.get("/stats", response_model=ReviewStats)
def review_stats(
    user: CurrentUser = Depends(_reviewer),
    db: Session = Depends(get_db),
) -> ReviewStats:
    """Conteos por estado_revision + throughput de revisión (Monitor del analista)."""
    counts = {
        row[0]: int(row[1])
        for row in db.execute(
            text("SELECT estado_revision, count(*) FROM observation GROUP BY estado_revision")
        ).all()
    }
    aceptadas = counts.get("aceptada", 0)
    confirmadas = counts.get("confirmada", 0)
    rechazadas = counts.get("rechazada", 0)
    revisiones = int(
        db.execute(text("SELECT count(*) FROM human_review")).scalar_one()
    )
    return ReviewStats(
        aceptadas=aceptadas,
        confirmadas=confirmadas,
        rechazadas=rechazadas,
        total=aceptadas + confirmadas + rechazadas,
        pendientes_de_revision=aceptadas,
        revisiones_totales=revisiones,
    )
