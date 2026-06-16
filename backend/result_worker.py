"""Worker consumidor de resultados de validación (entrypoint separado).

INACTIVO desde CR-001 (2026-06-15): se conserva en el repo pero no se arranca por defecto (compose lo
puso tras el perfil `yolo`). El submit ya no encola jobs; la calidad la decide la revisión humana.
Reactivar requiere reabrir la frontera §6 (y actualizar ``validation_apply`` al nuevo esquema).

    python -m backend.result_worker

Consume ``channels.RESULTS_STREAM`` por el contrato §6, **recomputa el veredicto autoritativo**
(gate #9, vía ``apply_validation_result`` → ``ValidationResult.authoritative_verdict``), aplica de
forma **idempotente** (``validation_event`` PK por observation_id) y otorga **puntos diferidos solo
si válida**. Hace ``ack`` solo tras aplicar (semántica at-least-once + idempotencia → no duplica).

Si no llega resultado (timeout / validador caído), la observación permanece ``pendiente``: este
worker nunca auto-etiqueta sin un mensaje explícito (§6.4).

NOTA mock↔real (gate #10): el worker es agnóstico de quién produce los resultados; el paso del
mock al YOLO real no toca este archivo.
"""

from __future__ import annotations

import logging
import signal
import sys

from mezquite_contract.broker import make_broker
from mezquite_contract.channels import BACKEND_GROUP, RESULTS_STREAM
from mezquite_contract.models import ValidationResult
from pydantic import ValidationError

from backend.app.config import get_settings
from backend.app.db import get_sessionmaker
from backend.app.validation_apply import apply_validation_result

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("mezquite.result_worker")

_running = True


def _stop(*_args) -> None:  # pragma: no cover - señal del SO
    global _running
    _running = False
    log.info("Señal de parada recibida; cerrando worker…")


def process_once(broker, consumer: str = "backend-1", *, block_ms: int = 5000) -> int:
    """Procesa un lote de resultados disponibles. Devuelve cuántos mensajes se procesaron."""
    Session = get_sessionmaker()
    deliveries = broker.consume(
        RESULTS_STREAM, BACKEND_GROUP, consumer, count=50, block_ms=block_ms
    )
    processed = 0
    for msg_id, message in deliveries:
        try:
            result = ValidationResult.from_message(message)
        except ValidationError as exc:
            # Mensaje malformado: no podemos aplicarlo. Lo ackeamos para no bloquear la cola
            # (queda registrado); una observación sin resultado válido permanece 'pendiente'.
            log.error("Resultado malformado (%s): %s", msg_id, exc)
            broker.ack(RESULTS_STREAM, BACKEND_GROUP, msg_id)
            continue

        session = Session()
        try:
            outcome = apply_validation_result(session, result)
            log.info(
                "obs=%s veredicto=%s aplicado=%s duplicado=%s puntos=%s",
                result.observation_id,
                outcome.verdict,
                outcome.applied,
                outcome.duplicate,
                outcome.points_awarded,
            )
            # Solo ackeamos si la aplicación no lanzó: at-least-once + idempotencia.
            broker.ack(RESULTS_STREAM, BACKEND_GROUP, msg_id)
            processed += 1
        except Exception:  # pragma: no cover - error transitorio: NO ack → reintento
            session.rollback()
            log.exception("Error aplicando resultado obs=%s; se reintentará", result.observation_id)
        finally:
            session.close()
    return processed


def main() -> int:  # pragma: no cover - bucle de servicio
    settings = get_settings()
    signal.signal(signal.SIGINT, _stop)
    signal.signal(signal.SIGTERM, _stop)

    broker = make_broker(settings.broker, url=settings.redis_url)
    broker.ensure_group(RESULTS_STREAM, BACKEND_GROUP)
    log.info(
        "result_worker iniciado (broker=%s, stream=%s, group=%s)",
        settings.broker,
        RESULTS_STREAM,
        BACKEND_GROUP,
    )

    while _running:
        try:
            process_once(broker)
        except Exception:
            log.exception("Error en el bucle del worker; continuando")
    broker.close()
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
