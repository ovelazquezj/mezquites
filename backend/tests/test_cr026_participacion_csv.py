"""CR-026: exportable de participación por día (solicitud de las universidades participantes).

``GET /admin/analytics/participation.csv`` cruza, por día y voluntario, la actividad de sesión
(sesiones + horas) contra el resultado de la revisión (aceptadas = pendientes, confirmadas,
rechazadas), que es lo que la institución necesita para evaluar a sus estudiantes sin pedir la base.

Criterios verificados:
- AC-F1: una fila por (día × voluntario) con ambos lados del cruce.
- AC-F2: el día se agrupa en ``America/Mexico_City``, no en UTC.
- AC-F3: un día con sesión y sin capturas aparece igual (y viceversa).
- AC-F4: authz — roles de consola sí, voluntario 403, sin token 401.
- Gate #2: solo el handle seudónimo; nunca PII.
"""

from __future__ import annotations

import csv
import io
from datetime import datetime, timedelta, timezone

from .helpers import (
    auth_header,
    confirm_observation,
    register,
    submit_observation,
)

URL = "/api/v1/admin/analytics/participation.csv"


def _rows(client, token: str, query: str = "") -> list[dict]:
    resp = client.get(URL + query, headers=auth_header(token))
    assert resp.status_code == 200, resp.text
    return list(csv.DictReader(io.StringIO(resp.text)))


def _post_session(client, token: str, start: datetime, minutes: int) -> None:
    resp = client.post(
        "/api/v1/me/sessions",
        headers=auth_header(token),
        json={
            "started_at": start.isoformat(),
            "ended_at": (start + timedelta(minutes=minutes)).isoformat(),
        },
    )
    assert resp.status_code == 201, resp.text


def test_participation_crosses_sessions_with_review_outcome(client, db_session):
    """AC-F1: sesiones y horas del día junto al desglose de revisión de ese mismo día."""
    volunteer = register(client)
    analista = register(client, role="analista")

    dia = datetime(2026, 6, 17, 16, 0, 0, tzinfo=timezone.utc)  # 10:00 en México
    _post_session(client, volunteer["token"], dia, minutes=90)

    # 3 capturas ese día: una confirmada, una rechazada, una que sigue pendiente.
    r1 = submit_observation(client, volunteer["token"], lat=21.88, lon=-102.29, captured_at=dia)
    r2 = submit_observation(client, volunteer["token"], lat=21.89, lon=-102.30, captured_at=dia)
    submit_observation(client, volunteer["token"], lat=21.90, lon=-102.31, captured_at=dia)
    confirm_observation(r1.json()["observation_id"])

    from sqlalchemy import text

    db_session.execute(
        text("UPDATE observation SET estado_revision='rechazada' WHERE id=:i"),
        {"i": r2.json()["observation_id"]},
    )
    db_session.commit()

    rows = [r for r in _rows(client, analista["token"]) if r["handle"] == volunteer["handle"]]
    assert len(rows) == 1, rows
    row = rows[0]
    assert row["fecha"] == "2026-06-17"
    assert row["sesiones"] == "1"
    assert abs(float(row["horas"]) - 1.5) < 1e-6
    assert row["obs_total"] == "3"
    assert row["obs_aceptadas"] == "1"  # pendiente de revisión
    assert row["obs_confirmadas"] == "1"
    assert row["obs_rechazadas"] == "1"


def test_day_is_grouped_in_mexico_city_not_utc(client, db_session):
    """AC-F2: 02:00 UTC es todavía el día anterior en México (UTC-6); agrupar en UTC lo correría."""
    volunteer = register(client)
    analista = register(client, role="analista")

    # 2026-06-17T02:00Z == 2026-06-16 20:00 en América/México.
    tarde = datetime(2026, 6, 17, 2, 0, 0, tzinfo=timezone.utc)
    _post_session(client, volunteer["token"], tarde, minutes=30)
    submit_observation(client, volunteer["token"], lat=21.88, lon=-102.29, captured_at=tarde)

    rows = [r for r in _rows(client, analista["token"]) if r["handle"] == volunteer["handle"]]
    assert len(rows) == 1, rows
    assert rows[0]["fecha"] == "2026-06-16"
    assert rows[0]["obs_total"] == "1"


def test_session_without_captures_still_appears(client, db_session):
    """AC-F3: el cruce no pierde los días de solo-sesión ni los de solo-captura."""
    volunteer = register(client)
    analista = register(client, role="analista")

    solo_sesion = datetime(2026, 6, 17, 16, 0, 0, tzinfo=timezone.utc)
    _post_session(client, volunteer["token"], solo_sesion, minutes=45)

    solo_captura = datetime(2026, 6, 19, 16, 0, 0, tzinfo=timezone.utc)
    submit_observation(client, volunteer["token"], lat=21.88, lon=-102.29, captured_at=solo_captura)

    rows = {
        r["fecha"]: r
        for r in _rows(client, analista["token"])
        if r["handle"] == volunteer["handle"]
    }
    assert set(rows) == {"2026-06-17", "2026-06-19"}
    assert rows["2026-06-17"]["sesiones"] == "1"
    assert rows["2026-06-17"]["obs_total"] == "0"
    assert rows["2026-06-19"]["sesiones"] == "0"
    assert rows["2026-06-19"]["obs_total"] == "1"


def test_participation_authz(client, db_session):
    """AC-F4: la consola descarga; el voluntario no; sin token, 401."""
    volunteer = register(client)
    assert client.get(URL, headers=auth_header(volunteer["token"])).status_code == 403
    assert client.get(URL).status_code == 401

    for rol in ("analista", "evaluador", "administrador"):
        cuenta = register(client, role=rol)
        assert client.get(URL, headers=auth_header(cuenta["token"])).status_code == 200


def test_participation_has_no_pii(client, db_session):
    """Gate #2: el reporte identifica por handle seudónimo, nunca por correo/nombre."""
    volunteer = register(client)
    analista = register(client, role="analista")
    submit_observation(client, volunteer["token"], lat=21.88, lon=-102.29)

    resp = client.get(URL, headers=auth_header(analista["token"]))
    assert volunteer["handle"] in resp.text
    assert "@" not in resp.text
    header = resp.text.splitlines()[0]
    assert "email" not in header and "nombre" not in header
