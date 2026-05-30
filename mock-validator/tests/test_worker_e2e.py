"""Integración E2E de la frontera §6 contra el MOCK, sin Redis (broker en memoria).

Simula el lazo completo:

    backend ──publish(JOBS_STREAM)──▶  mock.run_once()  ──publish(RESULTS_STREAM)──▶ backend

y comprueba que el backend, siendo AUTORITATIVO, etiqueta válida/ruido segun §6.3. Este es el
mismo flujo que correra contra el validador real: cambiar mock→real no toca este test salvo
quien consume JOBS_STREAM.
"""

import uuid
from datetime import datetime, timezone

from mezquite_contract.broker import InMemoryBroker
from mezquite_contract.channels import (
    BACKEND_GROUP,
    JOBS_STREAM,
    RESULTS_STREAM,
)
from mezquite_contract.models import ValidationJob, ValidationResult

from mock_validator.config import Config
from mock_validator.worker import MockValidator


def _encolar_job(broker, *, lat=21.88, lon=-102.29) -> uuid.UUID:
    obs_id = uuid.uuid4()
    job = ValidationJob(
        observation_id=obs_id,
        image_ref=f"obs/{obs_id}.jpg",
        captured_at=datetime(2026, 5, 30, 12, 0, tzinfo=timezone.utc),
        lat=lat,
        lon=lon,
    )
    broker.publish(JOBS_STREAM, job.to_message())
    return obs_id


def _leer_resultado(broker) -> ValidationResult:
    broker.ensure_group(RESULTS_STREAM, BACKEND_GROUP)
    batch = broker.consume(RESULTS_STREAM, BACKEND_GROUP, "backend-1", count=10)
    assert len(batch) == 1, "el backend debe recibir exactamente un resultado"
    msg_id, msg = batch[0]
    broker.ack(RESULTS_STREAM, BACKEND_GROUP, msg_id)
    return ValidationResult.from_message(msg)


def test_flujo_valida():
    broker = InMemoryBroker()
    obs_id = _encolar_job(broker)

    mock = MockValidator(broker, Config(mode="fijo", fixed_es_arbol=True, fixed_parasitos=True, broker_kind="memory"))
    assert mock.run_once(sleep_latency=False) == 1

    result = _leer_resultado(broker)
    assert result.observation_id == obs_id
    assert result.model_version == "mock"
    # El backend recomputa el veredicto (autoritativo): valida ⟺ es_arbol ∧ parasitos.
    assert result.authoritative_verdict == "valida"
    assert result.is_consistent


def test_flujo_ruido_sin_parasitos():
    broker = InMemoryBroker()
    _encolar_job(broker)

    mock = MockValidator(broker, Config(mode="fijo", fixed_es_arbol=True, fixed_parasitos=False, broker_kind="memory"))
    mock.run_once(sleep_latency=False)

    result = _leer_resultado(broker)
    assert result.authoritative_verdict == "ruido"


def test_job_pendiente_si_el_worker_no_corre():
    # fire-and-forget: el job queda encolado y NO hay resultado hasta que el mock corre.
    broker = InMemoryBroker()
    _encolar_job(broker)
    broker.ensure_group(RESULTS_STREAM, BACKEND_GROUP)
    assert broker.consume(RESULTS_STREAM, BACKEND_GROUP, "backend-1") == []


def test_job_no_ackeado_queda_pendiente_para_reintento():
    broker = InMemoryBroker()
    _encolar_job(broker)
    from mezquite_contract.channels import VALIDATOR_GROUP

    broker.ensure_group(JOBS_STREAM, VALIDATOR_GROUP)
    batch = broker.consume(JOBS_STREAM, VALIDATOR_GROUP, "mock-1")
    assert len(batch) == 1
    # sin ack (simula caida del worker antes de publicar) ⇒ permanece pendiente
    assert broker.pending(JOBS_STREAM, VALIDATOR_GROUP) == {batch[0][0]}


def test_lote_de_observaciones():
    broker = InMemoryBroker()
    ids = [_encolar_job(broker) for _ in range(5)]
    mock = MockValidator(broker, Config(mode="regla", broker_kind="memory"))
    assert mock.run_once(sleep_latency=False) == 5

    broker.ensure_group(RESULTS_STREAM, BACKEND_GROUP)
    resultados = broker.consume(RESULTS_STREAM, BACKEND_GROUP, "backend-1", count=100)
    recibidos = {ValidationResult.from_message(m).observation_id for _, m in resultados}
    assert recibidos == set(ids)
