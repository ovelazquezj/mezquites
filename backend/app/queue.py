"""Productor de la cola §6 (T6 / gate #10).

Usa **exclusivamente** la frontera del contrato `mezquite_contract` (no se reimplementa):
``make_broker`` (conmutable memory/redis, gate #6), ``ValidationJob`` y ``channels.JOBS_STREAM``.

El backend es **productor** de jobs aquí y **consumidor** de resultados en ``result_worker.py``.
El submit es *fire-and-forget*: encola y responde de inmediato (no espera al validador).
"""

from __future__ import annotations

import uuid
from datetime import datetime

from mezquite_contract.broker import MessageBroker, make_broker
from mezquite_contract.channels import JOBS_STREAM
from mezquite_contract.models import ValidationJob

from .config import get_settings

_broker: MessageBroker | None = None


def get_broker() -> MessageBroker:
    """Singleton del broker conmutable (``BROKER=memory|redis``)."""
    global _broker
    if _broker is None:
        settings = get_settings()
        _broker = make_broker(settings.broker, url=settings.redis_url)
    return _broker


def set_broker(broker: MessageBroker) -> None:
    """Inyección para pruebas / arranque (p.ej. compartir un InMemoryBroker en proceso)."""
    global _broker
    _broker = broker


def enqueue_validation_job(
    *,
    observation_id: uuid.UUID,
    image_ref: str,
    captured_at: datetime,
    lat: float,
    lon: float,
    broker: MessageBroker | None = None,
) -> str:
    """Encola un job de validación (§6.2). Devuelve el id del mensaje. NO espera resultado."""
    broker = broker or get_broker()
    job = ValidationJob(
        observation_id=observation_id,
        image_ref=image_ref,
        captured_at=captured_at,
        lat=lat,
        lon=lon,
    )
    return broker.publish(JOBS_STREAM, job.to_message())
