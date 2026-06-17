"""CR-010: el veredicto humano admite revertir a 'aceptada' (pendiente de revisión).

- Tras confirmar/rechazar, un veredicto 'aceptada' devuelve la observación al estado aceptada.
- Mensaje específico "Observación devuelta a aceptada (pendiente de revisión).".
- Vuelve a aparecer en el dataset público (no-rechazada). Queda fila en human_review (gate #7).
- analista sigue sin poder emitir veredicto (solo lectura, CR-001).
"""

from __future__ import annotations

from sqlalchemy import text

from .helpers import auth_header, register, submit_observation


def _verdict(client, token, obs_id, veredicto, nota=None):
    return client.post(
        f"/api/v1/review/observations/{obs_id}/verdict",
        headers=auth_header(token),
        json={"veredicto": veredicto, "nota": nota},
    )


def test_aceptada_reverts_rejected_observation(client, db_session):
    volunteer = register(client)
    obs_id = submit_observation(
        client, volunteer["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    evaluador = register(client, role="evaluador")

    # Rechazar: sale del público.
    assert _verdict(client, evaluador["token"], obs_id, "rechazada").status_code == 200
    assert client.get("/api/v1/public/observations").json() == []

    # Revertir a aceptada.
    resp = _verdict(client, evaluador["token"], obs_id, "aceptada", nota="reabrir")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["estado_revision"] == "aceptada"
    assert body["message"] == "Observación devuelta a aceptada (pendiente de revisión)."

    # Vuelve al dataset público (no-rechazada).
    assert len(client.get("/api/v1/public/observations").json()) == 1

    # Estado en DB = aceptada; hay 2 filas en human_review (rechazada + aceptada), gate #7.
    estado = db_session.execute(
        text("SELECT estado_revision FROM observation WHERE id=:i"), {"i": obs_id}
    ).scalar_one()
    assert estado == "aceptada"
    n = db_session.execute(
        text("SELECT count(*) FROM human_review WHERE observation_id=:i"), {"i": obs_id}
    ).scalar_one()
    assert n == 2


def test_aceptada_reverts_confirmed_observation(client, db_session):
    volunteer = register(client)
    obs_id = submit_observation(
        client, volunteer["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    admin = register(client, role="administrador")
    assert _verdict(client, admin["token"], obs_id, "confirmada").status_code == 200
    resp = _verdict(client, admin["token"], obs_id, "aceptada")
    assert resp.status_code == 200
    assert resp.json()["estado_revision"] == "aceptada"


def test_analista_cannot_revert_to_aceptada(client, db_session):
    volunteer = register(client)
    obs_id = submit_observation(
        client, volunteer["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    analista = register(client, role="analista")
    assert _verdict(client, analista["token"], obs_id, "aceptada").status_code == 403
