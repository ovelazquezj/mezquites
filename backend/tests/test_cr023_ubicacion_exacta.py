"""CR-025: ubicación EXACTA en la consola para todos los roles de consola.

Por decisión de gobernanza del Club, la consola autenticada de ``EXACT_LOCATION_ROLES``
(aliado_firmante/administrador/admin_consorcio/analista/evaluador) ve coords exactas; el único rol
sin acceso a la consola es ``voluntario``.

- ``GET /restricted/observations``: administrador/analista/aliado_firmante/evaluador → 200;
  voluntario → 403.
- ``GET /admin/analytics/observations.csv``: administrador/analista/evaluador → CSV exacto (columnas
  lat/lon con las coords sembradas).
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
        ("evaluador", 200),
        ("voluntario", 403),
    ],
)
def test_restricted_access_by_role(client, db_session, role, expected):
    """Los roles de EXACT_LOCATION_ROLES acceden a la tabla restringida; voluntario no."""
    user = register(client, role=role)
    resp = client.get(
        "/api/v1/restricted/observations", headers=auth_header(user["token"])
    )
    assert resp.status_code == expected, resp.text


def test_restricted_admin_sees_exact_coords(client, db_session):
    """El administrador (CR-025) ve las coords EXACTAS del árbol."""
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


@pytest.mark.parametrize("role", ["administrador", "analista", "evaluador"])
def test_csv_exact_for_console_roles(client, db_session, role):
    """CR-025: para los roles de consola el CSV trae columnas exactas ``lat``/``lon`` con las coords
    sembradas, NO la celda de binning."""
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
    # NO es el centro de la celda de binning de 300 m.
    cel_lat, cel_lon = obfuscate_to_grid(EXACT_LAT, EXACT_LON)
    assert (round(lat, 6), round(lon, 6)) != (cel_lat, cel_lon)
