"""Utilidades compartidas por las pruebas con DB."""

from __future__ import annotations

import io
import json
from datetime import datetime, timezone


def fake_jpeg(payload: bytes = b"fake-image-bytes") -> tuple[str, io.BytesIO, str]:
    return ("obs.jpg", io.BytesIO(payload), "image/jpeg")


def register(client, role: str = "voluntario", institution_id: str | None = None) -> dict:
    body: dict = {"role": role}
    if institution_id:
        body["institution_id"] = institution_id
    resp = client.post("/api/v1/auth/register", json=body)
    assert resp.status_code == 201, resp.text
    return resp.json()


def auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def submit_observation(
    client,
    token: str,
    *,
    lat: float,
    lon: float,
    nivel_g4: str = "leve",
    flag_cuscuta: bool = False,
    flag_danio: bool = False,
    tamanio: str = "mediano",
    contexto: str = "campo_abierto",
    captured_at: datetime | None = None,
):
    captured_at = captured_at or datetime.now(timezone.utc)
    payload = {
        "lat": lat,
        "lon": lon,
        "captured_at": captured_at.isoformat(),
        "nivel_g4": nivel_g4,
        "flag_cuscuta": flag_cuscuta,
        "flag_danio": flag_danio,
        "tamanio": tamanio,
        "contexto": contexto,
    }
    return client.post(
        "/api/v1/observations",
        headers=auth_header(token),
        data={"payload": json.dumps(payload)},
        files={"image": fake_jpeg()},
    )
