"""CR-019 — Reportar un problema: POST público + vista admin.

- POST sin auth → 201 (gate #3, sin gating; reporte anónimo).
- POST con auth de voluntario adjunta el handle (gate #2: sin PII, solo seudónimo).
- POST con token inválido → sigue anónimo (auth opcional, nunca 401).
- GET /admin/problem-reports como admin lista; como voluntario → 403; sin token → 401.
- Cambio de status funciona.
"""

from __future__ import annotations

from .helpers import auth_header, register


def test_post_without_auth_is_201_and_anonymous(client, db_session):
    resp = client.post(
        "/api/v1/problem-reports",
        json={"context": "camera", "message": "no abre la cámara", "platform": "web"},
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["status"] == "nuevo"
    assert data["handle"] is None  # anónimo (sin sesión)
    assert data["context"] == "camera"
    assert data["platform"] == "web"


def test_post_with_volunteer_auth_attaches_handle(client, db_session):
    reg = register(client)
    resp = client.post(
        "/api/v1/problem-reports",
        headers=auth_header(reg["token"]),
        json={"context": "general", "message": "algo falló", "app_version": "beta-2606"},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["handle"] == reg["handle"]


def test_post_with_invalid_token_is_still_anonymous_201(client, db_session):
    """Token inválido NO debe romper el POST público (auth opcional, gate #3)."""
    resp = client.post(
        "/api/v1/problem-reports",
        headers={"Authorization": "Bearer no-es-un-token"},
        json={"message": "x"},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["handle"] is None


def test_admin_lists_reports(client, db_session):
    client.post("/api/v1/problem-reports", json={"message": "uno"})
    admin = register(client, role="administrador")
    resp = client.get("/api/v1/admin/problem-reports", headers=auth_header(admin["token"]))
    assert resp.status_code == 200, resp.text
    rows = resp.json()
    assert len(rows) == 1
    assert rows[0]["message"] == "uno"


def test_volunteer_cannot_list_reports(client, db_session):
    volunteer = register(client)
    resp = client.get(
        "/api/v1/admin/problem-reports", headers=auth_header(volunteer["token"])
    )
    assert resp.status_code == 403


def test_list_reports_without_token_is_401(client, db_session):
    assert client.get("/api/v1/admin/problem-reports").status_code == 401


def test_admin_can_change_status(client, db_session):
    create = client.post("/api/v1/problem-reports", json={"message": "arréglame"})
    report_id = create.json()["id"]
    admin = register(client, role="administrador")
    resp = client.post(
        f"/api/v1/admin/problem-reports/{report_id}/status",
        headers=auth_header(admin["token"]),
        json={"status": "resuelto"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["status"] == "resuelto"


def test_change_status_unknown_report_is_404(client, db_session):
    import uuid

    admin = register(client, role="administrador")
    resp = client.post(
        f"/api/v1/admin/problem-reports/{uuid.uuid4()}/status",
        headers=auth_header(admin["token"]),
        json={"status": "visto"},
    )
    assert resp.status_code == 404
