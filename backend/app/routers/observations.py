"""Observaciones del voluntario (Q2, Q3, Q5.A — fire-and-forget; T6).

``POST /observations`` (multipart: 8 etiquetas JSON + imagen):
  1. Persiste la observación en ``validation_state='pendiente'``.
  2. Sube la imagen vía StorageProvider (la DB guarda solo la clave).
  3. Asigna ``tree_id`` (ST_DWithin 10 m, R3) y ``observation_seq`` (serie temporal).
  4. Deriva estado/municipio del EXIF (join admin_boundary, Q8).
  5. Otorga recompensa **base** y **encola el job** de validación (productor §6).
  6. Responde de inmediato (NO espera al validador; sin estado de validación individual).
"""

from __future__ import annotations

import json
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from pydantic import ValidationError
from sqlalchemy.orm import Session

from ..config import get_settings
from ..db import get_db
from ..deps import CurrentUser, require_role
from ..geo import assign_tree, compute_observation_seq, derive_estado_municipio
from ..models import Observation, PointsLedger
from ..queue import enqueue_validation_job
from ..schemas import ObservationCreate, ObservationMine, ObservationSubmitResponse
from ..storage import get_storage, new_image_key

router = APIRouter(tags=["observations"])


@router.post(
    "/observations",
    response_model=ObservationSubmitResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_observation(
    payload: str = Form(..., description="JSON con las 8 etiquetas (ObservationCreate)."),
    image: UploadFile = File(..., description="Imagen de cámara nativa (con EXIF)."),
    user: CurrentUser = Depends(require_role("voluntario", "aliado_firmante", "admin_consorcio")),
    db: Session = Depends(get_db),
) -> ObservationSubmitResponse:
    settings = get_settings()
    try:
        data = ObservationCreate.model_validate(json.loads(payload))
    except (json.JSONDecodeError, ValidationError) as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"payload inválido: {exc}"
        )

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=422, detail="imagen vacía")

    obs_id = uuid.uuid4()

    # (4) dimensión geográfica desde EXIF (Q8) — antes del tree para propagar al árbol.
    estado, municipio = derive_estado_municipio(db, lat=data.lat, lon=data.lon)

    # (3) tree_id (10 m) + observation_seq (serie temporal).
    tree_id = assign_tree(db, lat=data.lat, lon=data.lon, estado=estado, municipio=municipio)
    seq = compute_observation_seq(db, tree_id, data.captured_at)

    # (2) imagen vía StorageProvider (la DB guarda solo la clave).
    suffix = ".jpg"
    if image.filename and "." in image.filename:
        suffix = "." + image.filename.rsplit(".", 1)[-1].lower()
    image_key = new_image_key(obs_id, suffix)
    storage = get_storage()
    storage.put(image_key, image_bytes, content_type=image.content_type or "image/jpeg")

    # (1) persiste en estado 'pendiente'.
    point_wkt = f"SRID=4326;POINT({data.lon} {data.lat})"
    obs = Observation(
        id=obs_id,
        account_id=user.account_id,
        handle=user.handle,
        image_ref=image_key,
        geom=point_wkt,
        captured_at=data.captured_at,
        nivel_g4=data.nivel_g4,
        flag_cuscuta=data.flag_cuscuta,
        flag_danio=data.flag_danio,
        tamanio=data.tamanio,
        contexto=data.contexto,
        tree_id=tree_id,
        observation_seq=seq,
        estado=estado,
        municipio=municipio,
        validation_state="pendiente",
    )
    db.add(obs)

    # (5) recompensa BASE (inmediata, fire-and-forget).
    db.add(
        PointsLedger(
            account_id=user.account_id,
            observation_id=obs_id,
            kind="base",
            points=settings.points_base,
        )
    )
    db.commit()

    # (5) encola el job de validación (productor §6). NO espera resultado (T6).
    enqueue_validation_job(
        observation_id=obs_id,
        image_ref=image_key,
        captured_at=data.captured_at,
        lat=data.lat,
        lon=data.lon,
    )

    # (6) responde de inmediato con recompensa base; sin estado de validación individual.
    return ObservationSubmitResponse(observation_id=obs_id, base_points=settings.points_base)


@router.get("/observations/mine", response_model=list[ObservationMine])
def my_observations(
    user: CurrentUser = Depends(require_role("voluntario", "aliado_firmante", "admin_consorcio")),
    db: Session = Depends(get_db),
) -> list[ObservationMine]:
    """Historial propio. SIN estado de validación individual (gate Q5.A-D1)."""
    rows = (
        db.query(Observation)
        .filter(Observation.account_id == user.account_id)
        .order_by(Observation.captured_at.desc())
        .all()
    )
    return [
        ObservationMine(
            observation_id=o.id,
            captured_at=o.captured_at,
            nivel_g4=o.nivel_g4,
            flag_cuscuta=o.flag_cuscuta,
            flag_danio=o.flag_danio,
            tamanio=o.tamanio,
            contexto=o.contexto,
            estado=o.estado,
            municipio=o.municipio,
        )
        for o in rows
    ]
