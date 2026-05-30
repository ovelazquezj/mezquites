"""Consumidor de resultados: etiquetado autoritativo, idempotencia y puntos solo si válida (gate #9).

Cubre el contrato §6.3/§6.4 desde el backend:
- 'valida' ⟺ es_arbol ∧ parasitos → etiqueta 'valida' + recompensa diferida.
- cualquier otro caso → 'ruido', SIN puntos diferidos.
- veredicto AUTORITATIVO (no confía en el campo del mensaje).
- idempotencia: reentrega no duplica puntos (validation_event PK + UNIQUE ledger).
- timeout/sin resultado → permanece 'pendiente'.
"""

from __future__ import annotations

import uuid

from mezquite_contract.models import Scores, ValidationResult
from sqlalchemy import text

from backend.app.validation_apply import apply_validation_result
from .helpers import register, submit_observation


def _make_obs(client, db_session) -> str:
    reg = register(client)
    resp = submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    return resp.json()["observation_id"]


def _deferred_points(db, obs_id) -> int:
    return int(
        db.execute(
            text("SELECT COALESCE(sum(points),0) FROM points_ledger "
                 "WHERE observation_id=:i AND kind='diferida'"),
            {"i": obs_id},
        ).scalar_one()
    )


def _state(db, obs_id) -> str:
    return db.execute(
        text("SELECT validation_state FROM observation WHERE id=:i"), {"i": obs_id}
    ).scalar_one()


def test_valid_result_labels_valida_and_awards_deferred(client, db_session):
    obs_id = _make_obs(client, db_session)
    result = ValidationResult.build(
        observation_id=uuid.UUID(obs_id),
        es_arbol=True, parasitos_presentes=True,
        scores=Scores(arbol=0.95, parasitos=0.88), model_version="mock",
    )
    outcome = apply_validation_result(db_session, result)
    assert outcome.applied and outcome.verdict == "valida"
    assert outcome.points_awarded > 0

    fresh = db_session
    assert _state(fresh, obs_id) == "valida"
    assert _deferred_points(fresh, obs_id) > 0


def test_noise_result_labels_ruido_and_no_deferred(client, db_session):
    obs_id = _make_obs(client, db_session)
    result = ValidationResult.build(
        observation_id=uuid.UUID(obs_id),
        es_arbol=True, parasitos_presentes=False,  # sin parásitos → ruido
        scores=Scores(arbol=0.9, parasitos=0.05), model_version="mock",
    )
    outcome = apply_validation_result(db_session, result)
    assert outcome.verdict == "ruido"
    assert outcome.points_awarded == 0
    assert _state(db_session, obs_id) == "ruido"
    assert _deferred_points(db_session, obs_id) == 0


def test_authoritative_verdict_overrides_lying_message(client, db_session):
    """Mensaje miente ('valida') pero parásitos=False → backend etiqueta 'ruido' (gate #9)."""
    obs_id = _make_obs(client, db_session)
    result = ValidationResult(
        observation_id=uuid.UUID(obs_id),
        es_arbol=True, parasitos_presentes=False,
        veredicto="valida",  # incoherente
        scores=Scores(arbol=0.9, parasitos=0.1), model_version="buggy",
    )
    outcome = apply_validation_result(db_session, result)
    assert outcome.verdict == "ruido"
    assert _state(db_session, obs_id) == "ruido"
    assert _deferred_points(db_session, obs_id) == 0


def test_idempotent_reapply_does_not_duplicate_points(client, db_session):
    obs_id = _make_obs(client, db_session)
    result = ValidationResult.build(
        observation_id=uuid.UUID(obs_id),
        es_arbol=True, parasitos_presentes=True,
        scores=Scores(arbol=0.9, parasitos=0.9), model_version="mock",
    )
    first = apply_validation_result(db_session, result)
    points_after_first = _deferred_points(db_session, obs_id)

    second = apply_validation_result(db_session, result)  # reentrega
    points_after_second = _deferred_points(db_session, obs_id)

    assert first.applied and not first.duplicate
    assert second.duplicate and not second.applied
    assert points_after_first == points_after_second  # no duplica (gate #9)
    # Un solo evento de validación registrado.
    assert db_session.execute(
        text("SELECT count(*) FROM validation_event WHERE observation_id=:i"), {"i": obs_id}
    ).scalar_one() == 1


def test_no_result_keeps_pendiente(client, db_session):
    obs_id = _make_obs(client, db_session)
    # Sin aplicar ningún resultado (timeout/validador caído).
    assert _state(db_session, obs_id) == "pendiente"
    assert _deferred_points(db_session, obs_id) == 0


def test_process_once_consumes_results_stream(client, db_session):
    """El worker real (process_once) consume RESULTS_STREAM y aplica (lazo de servicio)."""
    from mezquite_contract.broker import InMemoryBroker
    from mezquite_contract.channels import BACKEND_GROUP, RESULTS_STREAM
    from backend.app import db as db_module
    from backend.result_worker import process_once

    obs_id = _make_obs(client, db_session)
    # El worker usa su propio sessionmaker → apuntarlo al engine de prueba.
    broker = InMemoryBroker()
    broker.ensure_group(RESULTS_STREAM, BACKEND_GROUP)
    result = ValidationResult.build(
        observation_id=uuid.UUID(obs_id),
        es_arbol=True, parasitos_presentes=True,
        scores=Scores(arbol=0.9, parasitos=0.9), model_version="mock",
    )
    broker.publish(RESULTS_STREAM, result.to_message())

    processed = process_once(broker, block_ms=0)
    assert processed == 1
    db_session.expire_all()
    assert _state(db_session, obs_id) == "valida"
    # El mensaje quedó ackeado (no pending).
    assert broker.pending(RESULTS_STREAM, BACKEND_GROUP) == set()
