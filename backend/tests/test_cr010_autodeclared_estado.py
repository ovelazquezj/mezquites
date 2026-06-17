"""CR-010: estado/municipio AUTODECLARADOS en el submit (gate #8).

- Si el payload trae estado/municipio (auto-detectados del GPS y editables en el móvil), se guardan.
- Si no vienen, el backend los DERIVA del EXIF (respaldo). Sin admin_boundary cargado ⇒ (None, None).
"""

from __future__ import annotations

import io
import json
from datetime import datetime, timezone

from sqlalchemy import text

from .helpers import auth_header, fake_jpeg, register


def _submit(client, token, *, lat=21.88, lon=-102.29, **extra) -> str:
    payload = {
        "lat": lat,
        "lon": lon,
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "nivel_g4": "leve",
        "flag_cuscuta": False,
        "flag_danio": False,
        "tamanio": "mediano",
        "contexto": "campo_abierto",
        **extra,
    }
    resp = client.post(
        "/api/v1/observations",
        headers=auth_header(token),
        data={"payload": json.dumps(payload)},
        files={"image": fake_jpeg()},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["observation_id"]


def test_autodeclared_estado_municipio_is_saved(client, db_session):
    reg = register(client)
    obs_id = _submit(
        client, reg["token"], estado="Aguascalientes", municipio="Jesús María"
    )
    row = db_session.execute(
        text("SELECT estado, municipio FROM observation WHERE id=:i"), {"i": obs_id}
    ).one()
    assert row[0] == "Aguascalientes"
    assert row[1] == "Jesús María"
    # También se expone en el historial propio.
    mine = client.get(
        "/api/v1/observations/mine", headers=auth_header(reg["token"])
    ).json()
    assert mine[0]["estado"] == "Aguascalientes"
    assert mine[0]["municipio"] == "Jesús María"


def test_only_estado_declared_is_saved(client, db_session):
    """Declarar solo estado usa los valores del payload (municipio = None), sin derivar."""
    reg = register(client)
    obs_id = _submit(client, reg["token"], estado="Aguascalientes")
    row = db_session.execute(
        text("SELECT estado, municipio FROM observation WHERE id=:i"), {"i": obs_id}
    ).one()
    assert row[0] == "Aguascalientes"
    assert row[1] is None


def test_no_declared_falls_back_to_derivation(client, db_session):
    """Sin estado/municipio en el payload y sin admin_boundary cargado ⇒ derivación = (None, None)."""
    reg = register(client)
    obs_id = _submit(client, reg["token"])
    row = db_session.execute(
        text("SELECT estado, municipio FROM observation WHERE id=:i"), {"i": obs_id}
    ).one()
    assert row[0] is None
    assert row[1] is None
