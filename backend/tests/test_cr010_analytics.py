"""CR-010: analítica del analista (resúmenes + CSV).

- GET /admin/analytics/summary cuenta por estado_revision/municipio/nivel_g4 + total; filtros.
- GET /admin/analytics/observations.csv exporta la ubicación EXACTA del árbol a la consola (CR-025).
- RBAC: roles de revisión (incluye analista) acceden; voluntario 403; sin token 401.
"""

from __future__ import annotations

import csv
import io
import json
from datetime import datetime, timezone

from .helpers import auth_header, fake_jpeg, register

EXACT_LAT = 21.881234
EXACT_LON = -102.291987


def _submit(client, token, *, lat, lon, nivel_g4="leve", municipio=None, **extra) -> str:
    payload = {
        "lat": lat,
        "lon": lon,
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "nivel_g4": nivel_g4,
        "flag_cuscuta": extra.get("flag_cuscuta", False),
        "flag_danio": extra.get("flag_danio", False),
        "tamanio": "mediano",
        "contexto": "campo_abierto",
        "estado": "Aguascalientes",
        "municipio": municipio,
    }
    resp = client.post(
        "/api/v1/observations",
        headers=auth_header(token),
        data={"payload": json.dumps(payload)},
        files={"image": fake_jpeg()},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["observation_id"]


def test_summary_counts(client, db_session):
    volunteer = register(client)
    _submit(client, volunteer["token"], lat=21.88, lon=-102.29, nivel_g4="leve", municipio="Aguascalientes")
    _submit(client, volunteer["token"], lat=21.89, lon=-102.30, nivel_g4="severo", municipio="Jesús María")
    _submit(client, volunteer["token"], lat=21.90, lon=-102.31, nivel_g4="leve", municipio="Jesús María")

    analista = register(client, role="analista")
    resp = client.get(
        "/api/v1/admin/analytics/summary", headers=auth_header(analista["token"])
    )
    assert resp.status_code == 200, resp.text
    s = resp.json()
    assert s["total"] == 3
    assert s["por_estado_revision"]["aceptada"] == 3
    assert s["por_nivel_g4"]["leve"] == 2
    assert s["por_nivel_g4"]["severo"] == 1
    assert s["por_municipio"]["Jesús María"] == 2
    assert s["por_municipio"]["Aguascalientes"] == 1


def test_summary_filter_by_municipio(client, db_session):
    volunteer = register(client)
    _submit(client, volunteer["token"], lat=21.88, lon=-102.29, municipio="Aguascalientes")
    _submit(client, volunteer["token"], lat=21.89, lon=-102.30, municipio="Jesús María")

    analista = register(client, role="analista")
    resp = client.get(
        "/api/v1/admin/analytics/summary",
        headers=auth_header(analista["token"]),
        params={"municipio": "Jesús María"},
    )
    assert resp.status_code == 200
    assert resp.json()["total"] == 1


def test_csv_uses_exact_coords_for_console(client, db_session):
    """CR-025: el CSV presenta la ubicación EXACTA del árbol a la consola (aquí, un evaluador)."""
    from backend.app.geo import obfuscate_to_grid

    volunteer = register(client)
    _submit(client, volunteer["token"], lat=EXACT_LAT, lon=EXACT_LON, municipio="Aguascalientes")

    evaluador = register(client, role="evaluador")
    resp = client.get(
        "/api/v1/admin/analytics/observations.csv", headers=auth_header(evaluador["token"])
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/csv")

    reader = csv.DictReader(io.StringIO(resp.text))
    rows = list(reader)
    assert len(rows) == 1
    row = rows[0]
    # Columnas esperadas (exactas).
    assert reader.fieldnames == [
        "observation_id", "captured_at", "handle", "estado", "municipio", "nivel_g4",
        "flag_cuscuta", "flag_danio", "tamanio", "contexto", "estado_revision",
        "lat", "lon",
    ]
    assert row["estado"] == "Aguascalientes"
    assert row["handle"] == volunteer["handle"]

    lat = float(row["lat"])
    lon = float(row["lon"])
    # Coincide con lo sembrado (exacto).
    assert abs(lat - EXACT_LAT) < 1e-4
    assert abs(lon - EXACT_LON) < 1e-4
    # NO es el centro de la celda de binning de 300 m.
    cel_lat, cel_lon = obfuscate_to_grid(EXACT_LAT, EXACT_LON)
    assert (round(lat, 6), round(lon, 6)) != (cel_lat, cel_lon)


def test_csv_filter_by_nivel(client, db_session):
    volunteer = register(client)
    _submit(client, volunteer["token"], lat=21.88, lon=-102.29, nivel_g4="leve", municipio="Aguascalientes")
    _submit(client, volunteer["token"], lat=21.89, lon=-102.30, nivel_g4="severo", municipio="Aguascalientes")

    analista = register(client, role="analista")
    resp = client.get(
        "/api/v1/admin/analytics/observations.csv",
        headers=auth_header(analista["token"]),
        params={"nivel_g4": "severo"},
    )
    rows = list(csv.DictReader(io.StringIO(resp.text)))
    assert len(rows) == 1
    assert rows[0]["nivel_g4"] == "severo"


def test_analytics_rbac(client, db_session):
    volunteer = register(client)
    # Voluntario: 403.
    assert client.get(
        "/api/v1/admin/analytics/summary", headers=auth_header(volunteer["token"])
    ).status_code == 403
    # Sin token: 401.
    assert client.get("/api/v1/admin/analytics/summary").status_code == 401
    # administrador: 200.
    admin = register(client, role="administrador")
    assert client.get(
        "/api/v1/admin/analytics/summary", headers=auth_header(admin["token"])
    ).status_code == 200
