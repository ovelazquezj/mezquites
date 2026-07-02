"""CR-023: ubicación EXACTA en la consola para roles administrativos/de análisis (reportes).

Enmienda ACOTADA al gate #5: la consola autenticada de ``EXACT_LOCATION_ROLES`` (aliado_firmante/
administrador/admin_consorcio/analista) ve coords exactas; el público sigue a 300 m (obfuscado).

- ``GET /restricted/observations``: administrador/analista/aliado_firmante → 200; evaluador/
  voluntario → 403.
- ``GET /admin/analytics/observations.csv``: administrador/analista → CSV exacto (columnas lat/lon
  con las coords sembradas); evaluador → CSV obfuscado (columnas lat_celda_300m/lon_celda_300m).
"""

from __future__ import annotations

import csv
import io

import pytest

from .helpers import auth_header, register, submit_observation

EXACT_LAT = 21.881234
EXACT_LON = -102.291987


@pytest.mark.parametrize(
    ("role", "expected"),
    [
        ("administrador", 200),
        ("analista", 200),
        ("aliado_firmante", 200),
        ("evaluador", 403),
        ("voluntario", 403),
    ],
)
def test_restricted_access_by_role(client, db_session, role, expected):
    """Los roles de EXACT_LOCATION_ROLES acceden a la tabla restringida; evaluador/voluntario no."""
    user = register(client, role=role)
    resp = client.get(
        "/api/v1/restricted/observations", headers=auth_header(user["token"])
    )
    assert resp.status_code == expected, resp.text


def test_restricted_admin_sees_exact_coords(client, db_session):
    """El administrador (CR-023) ve las coords EXACTAS, no la celda obfuscada."""
    firmante = register(client, role="aliado_firmante")
    submit_observation(client, firmante["token"], lat=EXACT_LAT, lon=EXACT_LON)

    admin = register(client, role="administrador")
    resp = client.get(
        "/api/v1/restricted/observations", headers=auth_header(admin["token"])
    )
    assert resp.status_code == 200
    rows = resp.json()
    assert len(rows) == 1
    assert abs(rows[0]["lat"] - EXACT_LAT) < 1e-4
    assert abs(rows[0]["lon"] - EXACT_LON) < 1e-4


def _read_csv(client, token):
    resp = client.get(
        "/api/v1/admin/analytics/observations.csv", headers=auth_header(token)
    )
    assert resp.status_code == 200, resp.text
    assert resp.headers["content-type"].startswith("text/csv")
    reader = csv.DictReader(io.StringIO(resp.text))
    return reader, list(reader)


@pytest.mark.parametrize("role", ["administrador", "analista"])
def test_csv_exact_for_admin_and_analyst(client, db_session, role):
    """CR-023: para administrador/analista el CSV trae columnas exactas ``lat``/``lon`` con las
    coords sembradas (uso interno para reportes), NO la celda obfuscada."""
    from backend.app.geo import obfuscate_to_grid

    volunteer = register(client)
    submit_observation(client, volunteer["token"], lat=EXACT_LAT, lon=EXACT_LON)

    user = register(client, role=role)
    reader, rows = _read_csv(client, user["token"])
    assert reader.fieldnames[-2:] == ["lat", "lon"]
    assert len(rows) == 1
    lat = float(rows[0]["lat"])
    lon = float(rows[0]["lon"])
    # Coincide con lo sembrado (exacto).
    assert abs(lat - EXACT_LAT) < 1e-4
    assert abs(lon - EXACT_LON) < 1e-4
    # NO es el centro de la celda de 300 m (no fue obfuscado).
    cel_lat, cel_lon = obfuscate_to_grid(EXACT_LAT, EXACT_LON)
    assert (round(lat, 6), round(lon, 6)) != (cel_lat, cel_lon)


def test_csv_obfuscated_for_evaluador(client, db_session):
    """GATE #5 conservado: para evaluador el CSV mantiene la celda de 300 m (obfuscada)."""
    from backend.app.geo import obfuscate_to_grid

    volunteer = register(client)
    submit_observation(client, volunteer["token"], lat=EXACT_LAT, lon=EXACT_LON)

    evaluador = register(client, role="evaluador")
    reader, rows = _read_csv(client, evaluador["token"])
    assert reader.fieldnames[-2:] == ["lat_celda_300m", "lon_celda_300m"]
    assert len(rows) == 1
    cel_lat = float(rows[0]["lat_celda_300m"])
    cel_lon = float(rows[0]["lon_celda_300m"])
    exp_lat, exp_lon = obfuscate_to_grid(EXACT_LAT, EXACT_LON)
    assert (round(cel_lat, 6), round(cel_lon, 6)) == (exp_lat, exp_lon)
    # Se movió respecto a lo sembrado (obfuscado, gate #5).
    assert abs(cel_lat - EXACT_LAT) > 1e-7
    assert abs(cel_lon - EXACT_LON) > 1e-7
