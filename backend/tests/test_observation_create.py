"""Submit de observación: 8 etiquetas (Q2), triple etiqueta M3 (Q3), fire-and-forget (T6).

- Backend acepta las 8 etiquetas y persiste en 'pendiente' (gate #8: no valida G4/especie).
- Submit responde de inmediato con recompensa base y NO devuelve estado de validación individual.
- El submit ENCOLA un job en JOBS_STREAM sin esperar al validador (gate #6/T6, InMemoryBroker).
"""

from __future__ import annotations

from mezquite_contract.channels import JOBS_STREAM, VALIDATOR_GROUP

from .helpers import auth_header, register, submit_observation


def test_submit_accepts_eight_labels_and_returns_base_reward(client, db_session):
    reg = register(client)
    resp = submit_observation(
        client, reg["token"], lat=21.88, lon=-102.29,
        nivel_g4="moderado", flag_cuscuta=True, flag_danio=True,
        tamanio="grande", contexto="urbano",
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["base_points"] > 0
    assert "observation_id" in body
    # Gate Q5.A-D1: NO se devuelve estado de validación individual.
    assert "validation_state" not in body


def test_submit_persists_pendiente(client, db_session):
    from sqlalchemy import text

    reg = register(client)
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    state = db_session.execute(text("SELECT validation_state FROM observation")).scalar_one()
    assert state == "pendiente"


def test_submit_enqueues_job_without_waiting(client, db_session):
    """Fire-and-forget: el job queda en JOBS_STREAM; el submit no espera al validador (T6)."""
    reg = register(client)
    resp = submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    obs_id = resp.json()["observation_id"]

    broker = client.broker
    broker.ensure_group(JOBS_STREAM, VALIDATOR_GROUP)
    jobs = broker.consume(JOBS_STREAM, VALIDATOR_GROUP, "test-validator", count=10)
    assert len(jobs) == 1
    _, message = jobs[0]
    assert message["observation_id"] == obs_id
    assert message["image_ref"].startswith("observations/")
    # El job lleva captured_at/lat/lon (contrato §6.2) y NO lleva veredicto.
    assert "veredicto" not in message
    assert message["lat"] == 21.88


def test_submit_rejects_invalid_nivel_g4(client, db_session):
    reg = register(client)
    import json

    resp = client.post(
        "/api/v1/observations",
        headers=auth_header(reg["token"]),
        data={"payload": json.dumps({
            "lat": 21.88, "lon": -102.29, "captured_at": "2026-05-30T10:00:00Z",
            "nivel_g4": "catastrofico",  # inválido
            "tamanio": "mediano", "contexto": "campo_abierto",
        })},
        files={"image": ("o.jpg", b"x", "image/jpeg")},
    )
    assert resp.status_code == 422


def test_mine_does_not_expose_validation_state(client, db_session):
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    resp = client.get("/api/v1/observations/mine", headers=auth_header(reg["token"]))
    assert resp.status_code == 200
    rows = resp.json()
    assert len(rows) == 1
    assert "validation_state" not in rows[0]  # gate Q5.A-D1
