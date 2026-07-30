"""Observaciones del voluntario (Q2, Q3, Q5.A — revisión humana, CR-001).

``POST /observations`` (multipart: 8 etiquetas JSON + imagen):
  1. Persiste la observación en ``estado_revision='aceptada'`` (aceptación por defecto, CR-001).
  2. Sube la imagen vía StorageProvider (la DB guarda solo la clave).
  3. Asigna ``tree_id`` (ST_DWithin 10 m, R3) y ``observation_seq`` (serie temporal).
  4. Deriva estado/municipio del EXIF (join admin_boundary, Q8).
  5. Registra la recompensa **base y diferida al instante** en ``points_ledger`` (ya no hay
     validador asíncrono). **CR-026:** ese registro es la bitácora cruda; los puntos solo se
     *cuentan* cuando la observación queda ``confirmada`` (el filtro vive en
     ``gamification.account_points``, al leer). Así un rechazo —o revertir una confirmación— ajusta
     el total sin tener que compensar filas.
  6. Responde de inmediato. **NO encola** ningún job (la frontera §6/YOLO quedó inactiva, gate #10
     superado); sin estado de validación individual al voluntario (Q5.A-D1 intacto).
"""

from __future__ import annotations

import json
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, Response, UploadFile, status
from pydantic import ValidationError
from sqlalchemy.orm import Session

from ..config import get_settings
from ..db import get_db
from ..deps import CurrentUser, require_role
from ..gamification import refresh_identity_label
from ..geo import assign_tree, compute_observation_seq, derive_estado_municipio
from ..models import Observation, PointsLedger
from ..schemas import ObservationCreate, ObservationMine, ObservationSubmitResponse
from ..storage import get_storage, new_image_key

router = APIRouter(tags=["observations"])


@router.post(
    "/observations",
    response_model=ObservationSubmitResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_observation(
    response: Response,
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

    # (0) CR-031 — idempotencia. Si esta captura ya se registró (mismo `client_capture_id` de la
    # misma cuenta), NO se crea nada: se devuelve la observación original con 200 y `ya_existia`.
    # Es lo que permite a la app reintentar sin miedo cuando la respuesta se perdió de vuelta.
    # Se comprueba ANTES de leer la imagen y de tocar el storage: un reintento no debe subir de nuevo
    # 200 KB ni dejar un objeto huérfano.
    if data.client_capture_id is not None:
        previa = (
            db.query(Observation)
            .filter(
                Observation.account_id == user.account_id,
                Observation.client_capture_id == data.client_capture_id,
            )
            .one_or_none()
        )
        if previa is not None:
            response.status_code = status.HTTP_200_OK
            return ObservationSubmitResponse(
                observation_id=previa.id,
                base_points=settings.points_base,
                message="Esta captura ya estaba registrada. No se duplicó.",
                ya_existia=True,
            )

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=422, detail="imagen vacía")

    obs_id = uuid.uuid4()

    # (4) dimensión geográfica (Q8) — antes del tree para propagar al árbol.
    # CR-010: si el cliente declara estado/municipio (auto-detectados del GPS y editables, gate #8),
    # se usan; si no, se DERIVAN del EXIF por join espacial (respaldo, admin_boundary).
    if data.estado or data.municipio:
        estado, municipio = data.estado, data.municipio
    else:
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

    # (1) persiste en estado 'aceptada' (aceptación por defecto, CR-001).
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
        estado_revision="aceptada",
        client_capture_id=data.client_capture_id,  # CR-031: sella la captura contra reintentos
    )
    db.add(obs)

    # (5) recompensa al subir: BASE + DIFERIDA en el mismo submit (CR-001).
    # CR-026: estas filas son el registro crudo; no se suman al total del voluntario hasta que la
    # observación esté `confirmada`. No hay que revertirlas ante un rechazo: el filtro es al leer.
    db.add(
        PointsLedger(
            account_id=user.account_id,
            observation_id=obs_id,
            kind="base",
            points=settings.points_base,
        )
    )
    db.add(
        PointsLedger(
            account_id=user.account_id,
            observation_id=obs_id,
            kind="diferida",
            points=settings.points_deferred,
        )
    )
    # Etiqueta de identidad L3 según observaciones no-rechazadas (antes lo hacía el validador).
    refresh_identity_label(db, user.account_id)
    db.commit()

    # (6) responde de inmediato. NO se encola ningún job (frontera §6 inactiva, gate #10 superado).
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
