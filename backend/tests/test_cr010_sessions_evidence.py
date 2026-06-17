"""CR-010 (#7): sesiones de participación + evidencia (capturas + horas).

- POST /me/sessions calcula duration_seconds y persiste (auth voluntario).
- GET /me/evidence devuelve capturas (nº observaciones propias), horas (Σ duration/3600),
  sesiones, primera y ultima.
- ended_at < started_at ⇒ 422. Sin token ⇒ 401.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from .helpers import auth_header, register, submit_observation


def test_create_session_computes_duration(client, db_session):
    reg = register(client)
    start = datetime(2026, 6, 17, 10, 0, 0, tzinfo=timezone.utc)
    end = start + timedelta(minutes=90)  # 1.5 h
    resp = client.post(
        "/api/v1/me/sessions",
        headers=auth_header(reg["token"]),
        json={"started_at": start.isoformat(), "ended_at": end.isoformat()},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["duration_seconds"] == 90 * 60


def test_evidence_aggregates_captures_and_hours(client, db_session):
    reg = register(client)
    # 2 capturas.
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    submit_observation(client, reg["token"], lat=21.89, lon=-102.30)

    # 2 sesiones: 1 h + 30 min = 1.5 h.
    base = datetime(2026, 6, 17, 9, 0, 0, tzinfo=timezone.utc)
    client.post(
        "/api/v1/me/sessions",
        headers=auth_header(reg["token"]),
        json={
            "started_at": base.isoformat(),
            "ended_at": (base + timedelta(hours=1)).isoformat(),
        },
    )
    later = base + timedelta(hours=2)
    client.post(
        "/api/v1/me/sessions",
        headers=auth_header(reg["token"]),
        json={
            "started_at": later.isoformat(),
            "ended_at": (later + timedelta(minutes=30)).isoformat(),
        },
    )

    resp = client.get("/api/v1/me/evidence", headers=auth_header(reg["token"]))
    assert resp.status_code == 200, resp.text
    ev = resp.json()
    assert ev["capturas"] == 2
    assert ev["sesiones"] == 2
    assert abs(ev["horas_totales"] - 1.5) < 1e-6
    assert ev["primera"] is not None
    assert ev["ultima"] is not None
    # primera <= ultima (rango por inicio de sesión).
    assert ev["primera"] <= ev["ultima"]


def test_evidence_empty_for_new_account(client, db_session):
    reg = register(client)
    ev = client.get("/api/v1/me/evidence", headers=auth_header(reg["token"])).json()
    assert ev["capturas"] == 0
    assert ev["horas_totales"] == 0.0
    assert ev["sesiones"] == 0
    assert ev["primera"] is None
    assert ev["ultima"] is None


def test_session_rejects_negative_duration(client, db_session):
    reg = register(client)
    start = datetime(2026, 6, 17, 10, 0, 0, tzinfo=timezone.utc)
    resp = client.post(
        "/api/v1/me/sessions",
        headers=auth_header(reg["token"]),
        json={
            "started_at": start.isoformat(),
            "ended_at": (start - timedelta(minutes=5)).isoformat(),
        },
    )
    assert resp.status_code == 422


def test_session_without_token_is_401(client, db_session):
    start = datetime(2026, 6, 17, 10, 0, 0, tzinfo=timezone.utc)
    resp = client.post(
        "/api/v1/me/sessions",
        json={
            "started_at": start.isoformat(),
            "ended_at": (start + timedelta(hours=1)).isoformat(),
        },
    )
    assert resp.status_code == 401
