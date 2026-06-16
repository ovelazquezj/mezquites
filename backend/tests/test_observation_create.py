"""Submit de observación: 8 etiquetas (Q2), triple etiqueta M3 (Q3), aceptación por defecto (CR-001).

- Backend acepta las 8 etiquetas y persiste en 'aceptada' (no valida G4/especie; autodeclarados).
- Submit responde de inmediato con recompensa base y NO devuelve estado individual al voluntario.
- El submit NO encola ningún job (frontera §6/YOLO inactiva, gate #10 superado) — AC7.
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


def test_submit_persists_aceptada(client, db_session):
    """Aceptación por defecto (CR-001): la observación nace 'aceptada'."""
    from sqlalchemy import text

    reg = register(client)
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    state = db_session.execute(text("SELECT estado_revision FROM observation")).scalar_one()
    assert state == "aceptada"


def test_submit_does_not_enqueue_any_job(client, db_session):
    """AC7: el submit NO publica en JOBS_STREAM (frontera §6 inactiva, gate #10 superado)."""
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)

    broker = client.broker
    broker.ensure_group(JOBS_STREAM, VALIDATOR_GROUP)
    jobs = broker.consume(JOBS_STREAM, VALIDATOR_GROUP, "test-validator", count=10)
    assert jobs == []  # no se encoló nada


def test_submit_awards_base_and_deferred_on_upload(client, db_session):
    """CR-001: puntos base + diferida al subir (un rechazo posterior no los revierte)."""
    from sqlalchemy import text

    reg = register(client)
    resp = submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    obs_id = resp.json()["observation_id"]
    kinds = {
        row[0]
        for row in db_session.execute(
            text("SELECT kind FROM points_ledger WHERE observation_id=:i"), {"i": obs_id}
        ).all()
    }
    assert kinds == {"base", "diferida"}


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
