"""Roles (gate de roles, gate #5): restricted exige aliado_firmante; público solo 1 km."""

from __future__ import annotations

from .helpers import auth_header, register, submit_observation


def test_restricted_requires_aliado_firmante(client, db_session):
    voluntario = register(client, role="voluntario")
    resp = client.get(
        "/api/v1/restricted/observations", headers=auth_header(voluntario["token"])
    )
    assert resp.status_code == 403  # un voluntario NO puede ver coords exactas


def test_restricted_allows_aliado_firmante_with_exact_coords(client, db_session):
    firmante = register(client, role="aliado_firmante")
    # Promover no es necesario: registramos con rol firmante para la prueba de acceso.
    exact_lat, exact_lon = 21.885311, -102.291622
    submit_observation(client, firmante["token"], lat=exact_lat, lon=exact_lon)
    resp = client.get(
        "/api/v1/restricted/observations", headers=auth_header(firmante["token"])
    )
    assert resp.status_code == 200
    rows = resp.json()
    assert len(rows) == 1
    # Coords EXACTAS (no obfuscadas).
    assert abs(rows[0]["lat"] - exact_lat) < 1e-4
    assert abs(rows[0]["lon"] - exact_lon) < 1e-4


def test_restricted_without_token_is_401(client, db_session):
    resp = client.get("/api/v1/restricted/observations")
    assert resp.status_code == 401


def test_admin_endpoints_require_admin_role(client, db_session):
    voluntario = register(client, role="voluntario")
    resp = client.post(
        "/api/v1/admin/snapshots", headers=auth_header(voluntario["token"])
    )
    assert resp.status_code == 403

    admin = register(client, role="admin_consorcio")
    resp = client.post("/api/v1/admin/snapshots", headers=auth_header(admin["token"]))
    assert resp.status_code == 201


def test_public_observations_are_obfuscated_to_1km(client, db_session):
    """La vista pública NUNCA expone coords más finas que 1 km (gate #5)."""
    from sqlalchemy import text

    firmante = register(client, role="aliado_firmante")
    exact_lat, exact_lon = 21.885311, -102.291622
    resp = submit_observation(client, firmante["token"], lat=exact_lat, lon=exact_lon)
    obs_id = resp.json()["observation_id"]
    # Marcar como válida para que entre al dataset público (gate #9).
    db_session.execute(
        text("UPDATE observation SET validation_state='valida' WHERE id=:i"), {"i": obs_id}
    )
    db_session.commit()

    pub = client.get("/api/v1/public/observations").json()
    assert len(pub) == 1
    # Las coords públicas difieren de las exactas (obfuscadas a celda de 1 km).
    assert pub[0]["lat"] != exact_lat
    assert pub[0]["lon"] != exact_lon
    assert "snapshot_quarter" in pub[0]
    assert "handle" in pub[0]  # atribución I2
