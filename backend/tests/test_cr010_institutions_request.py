"""CR-010: el voluntario solicita una institución nueva (queda 'solicitada').

- POST /institutions/request crea status='solicitada' (auth voluntario) → 201 {id,name,status}.
- La solicitada NO aparece en el catálogo público (GET /institutions = solo aprobadas).
- Sí aparece en la lista completa del admin_consorcio (GET /admin/institutions).
- Sin token ⇒ 401.
- Siembra (seed_institutions) crea las aprobadas y es idempotente.
"""

from __future__ import annotations

from sqlalchemy import text

from .helpers import auth_header, register


def test_request_creates_solicitada_and_hidden_from_public(client, db_session):
    reg = register(client)
    resp = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(reg["token"]),
        json={"name": "Prepa Nueva CR-010", "estado": "Aguascalientes"},
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["name"] == "Prepa Nueva CR-010"
    assert body["status"] == "solicitada"
    assert "id" in body

    # NO aparece en el catálogo público (solo aprobadas).
    public = client.get("/api/v1/institutions").json()
    assert "Prepa Nueva CR-010" not in {i["name"] for i in public}

    # En DB queda solicitada.
    status = db_session.execute(
        text("SELECT status FROM institution WHERE name=:n"), {"n": "Prepa Nueva CR-010"}
    ).scalar_one()
    assert status == "solicitada"


def test_request_appears_in_admin_full_list(client, db_session):
    reg = register(client)
    client.post(
        "/api/v1/institutions/request",
        headers=auth_header(reg["token"]),
        json={"name": "Solicitada Admin CR-010"},
    )
    admin = register(client, role="admin_consorcio")
    full = client.get(
        "/api/v1/admin/institutions", headers=auth_header(admin["token"])
    ).json()
    match = [i for i in full if i["name"] == "Solicitada Admin CR-010"]
    assert match and match[0]["status"] == "solicitada"


def test_request_without_token_is_401(client, db_session):
    resp = client.post(
        "/api/v1/institutions/request", json={"name": "Sin Token"}
    )
    assert resp.status_code == 401


def test_seed_institutions_idempotent(client, db_session):
    """La siembra crea las aprobadas y NO duplica al re-ejecutar (idempotente)."""
    from backend.app.seed_institutions import INSTITUCIONES, seed_institutions

    insertadas1, ya1 = seed_institutions(db_session)
    assert insertadas1 == len(INSTITUCIONES)
    assert ya1 == 0

    # Todas quedan aprobadas y en el catálogo público.
    public = client.get("/api/v1/institutions").json()
    names = {i["name"] for i in public}
    assert set(INSTITUCIONES) <= names
    assert all(i["status"] == "aprobada" for i in public)
    assert "Institución Independiente" in names

    # Re-ejecutar no inserta nada nuevo (idempotente).
    insertadas2, ya2 = seed_institutions(db_session)
    assert insertadas2 == 0
    assert ya2 == len(INSTITUCIONES)

    total = db_session.execute(text("SELECT count(*) FROM institution")).scalar_one()
    assert total == len(INSTITUCIONES)
