"""CR-011 — arreglos post-CR-010 (backend).

- `GET /admin/analytics/observations` devuelve la tabla JSON del analista (causa del #4: faltaba el
  endpoint → 404), sin coords (solo estado/municipio).
- `POST /admin/institutions/{id}/approve` aprueba una solicitada → entra al catálogo público.
- `POST /institutions/request` **asocia** la institución a la cuenta que la registra (decisión A).
- El `administrador` (no solo `admin_consorcio`) puede usar la consola `/admin`.
"""

from __future__ import annotations

from sqlalchemy import text

from .helpers import auth_header, register, submit_observation


def test_analytics_observations_returns_rows_without_exact_coords(client, db_session):
    vol = register(client)
    r = submit_observation(client, vol["token"], lat=21.8801, lon=-102.2901, nivel_g4="severo")
    assert r.status_code == 201, r.text

    analista = register(client, role="analista")
    resp = client.get(
        "/api/v1/admin/analytics/observations",
        headers=auth_header(analista["token"]),
    )
    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert len(rows) >= 1
    row = rows[0]
    # Forma exacta que consume el web-admin (AnalyticsObservation.fromJson).
    for k in (
        "observation_id", "handle", "captured_at", "estado_revision", "nivel_g4",
        "flag_cuscuta", "flag_danio", "estado", "municipio",
    ):
        assert k in row, f"falta la clave {k}"
    # La tabla NO incluye coords (solo estado/municipio).
    assert "lat" not in row and "lon" not in row and "geom" not in row


def test_analytics_observations_filters_by_nivel(client, db_session):
    vol = register(client)
    submit_observation(client, vol["token"], lat=21.88, lon=-102.29, nivel_g4="leve")
    submit_observation(client, vol["token"], lat=21.89, lon=-102.30, nivel_g4="severo")
    analista = register(client, role="analista")
    resp = client.get(
        "/api/v1/admin/analytics/observations?nivel_g4=severo",
        headers=auth_header(analista["token"]),
    )
    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert rows and all(r["nivel_g4"] == "severo" for r in rows)


def test_approve_institution_moves_to_public_catalog(client, db_session):
    vol = register(client)
    req = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(vol["token"]),
        json={"name": "Prepa Aprobable CR-011", "estado": "Aguascalientes"},
    )
    assert req.status_code == 201, req.text
    inst_id = req.json()["id"]

    # Todavía NO está en el catálogo público (sigue solicitada).
    public = client.get("/api/v1/institutions").json()
    assert "Prepa Aprobable CR-011" not in {i["name"] for i in public}

    admin = register(client, role="administrador")
    appr = client.post(
        f"/api/v1/admin/institutions/{inst_id}/approve",
        headers=auth_header(admin["token"]),
    )
    assert appr.status_code == 200, appr.text
    assert appr.json()["status"] == "aprobada"

    # Ahora sí aparece en el catálogo público.
    public2 = client.get("/api/v1/institutions").json()
    assert "Prepa Aprobable CR-011" in {i["name"] for i in public2}


def test_request_associates_institution_to_requester(client, db_session):
    vol = register(client)
    req = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(vol["token"]),
        json={"name": "Mi Prepa CR-011"},
    )
    assert req.status_code == 201, req.text
    inst_id = req.json()["id"]
    # La cuenta del solicitante quedó asociada a su institución (pendiente de aprobación).
    cnt = db_session.execute(
        text("SELECT count(*) FROM account WHERE institution_id = :iid"),
        {"iid": inst_id},
    ).scalar_one()
    assert cnt == 1


def test_administrador_can_use_console(client, db_session):
    """CR-011 #5a: el `administrador` accede a la consola `/admin` (antes solo `admin_consorcio`)."""
    admin = register(client, role="administrador")
    resp = client.get("/api/v1/admin/institutions", headers=auth_header(admin["token"]))
    assert resp.status_code == 200, resp.text
