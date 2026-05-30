"""Worker del mock: consume jobs (§6.2) → evalúa → publica resultados (§6.3)."""

from __future__ import annotations

import logging
import random
import time
from typing import Callable

from mezquite_contract.broker import MessageBroker
from mezquite_contract.channels import JOBS_STREAM, RESULTS_STREAM, VALIDATOR_GROUP
from mezquite_contract.models import Scores, ValidationJob, ValidationResult

from .config import Config
from .strategies import evaluate

log = logging.getLogger("mock_validator")


class MockValidator:
    def __init__(self, broker: MessageBroker, cfg: Config) -> None:
        self.broker = broker
        self.cfg = cfg
        self._rng = random.Random(cfg.seed)

    # -- mapeo puro job → resultado (sin IO ni latencia: facil de testear) --
    def build_result(self, job: ValidationJob) -> ValidationResult:
        ev = evaluate(self.cfg, str(job.observation_id), rng=self._rng)
        return ValidationResult.build(
            observation_id=job.observation_id,
            es_arbol=ev.es_arbol,
            parasitos_presentes=ev.parasitos_presentes,
            scores=Scores(arbol=ev.score_arbol, parasitos=ev.score_parasitos),
            model_version=self.cfg.model_version,
        )

    def process_message(self, msg: dict) -> dict:
        job = ValidationJob.from_message(msg)  # valida el job §6.2
        return self.build_result(job).to_message()

    def _latency_seconds(self) -> float:
        lo, hi = self.cfg.latency_ms_min, self.cfg.latency_ms_max
        ms = self._rng.uniform(lo, hi) if hi > lo else lo
        return ms / 1000.0

    def run_once(self, *, sleep_latency: bool = True, block_ms: int = 0) -> int:
        """Procesa un lote disponible. Devuelve cuántos jobs validó. Reutilizable en pruebas."""
        self.broker.ensure_group(JOBS_STREAM, VALIDATOR_GROUP)
        batch = self.broker.consume(
            JOBS_STREAM, VALIDATOR_GROUP, self.cfg.consumer_name, count=10, block_ms=block_ms
        )
        processed = 0
        for msg_id, msg in batch:
            try:
                if sleep_latency:
                    time.sleep(self._latency_seconds())
                result_msg = self.process_message(msg)
                self.broker.publish(RESULTS_STREAM, result_msg)
                self.broker.ack(JOBS_STREAM, VALIDATOR_GROUP, msg_id)
                processed += 1
                log.info(
                    "validado obs=%s veredicto=%s",
                    result_msg["observation_id"],
                    result_msg["veredicto"],
                )
            except Exception:
                # No se ackea ⇒ el job queda PENDIENTE y será reintentado (§6.4).
                log.exception("error procesando job %s; queda pendiente", msg_id)
        return processed

    def run_forever(
        self, should_stop: Callable[[], bool] = lambda: False, *, sleep_latency: bool = True
    ) -> None:
        self.broker.ensure_group(JOBS_STREAM, VALIDATOR_GROUP)
        log.info(
            "mock-validator listo (mode=%s broker=%s model_version=%s)",
            self.cfg.mode,
            self.cfg.broker_kind,
            self.cfg.model_version,
        )
        while not should_stop():
            self.run_once(sleep_latency=sleep_latency, block_ms=2000)
