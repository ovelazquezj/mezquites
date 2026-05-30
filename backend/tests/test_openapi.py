"""OpenAPI servido en /api/v1/openapi.json (T2) y boundary Q1 en el copy (gate #1).

Estos tests NO requieren DB (la generación del esquema OpenAPI es estática).
"""

from __future__ import annotations

import json

from fastapi.testclient import TestClient

from backend.app.main import app

_client = TestClient(app)


def test_openapi_served_at_versioned_path():
    resp = _client.get("/api/v1/openapi.json")
    assert resp.status_code == 200
    spec = resp.json()
    assert spec["openapi"].startswith("3.")
    paths = spec["paths"]
    # Endpoints imprescindibles presentes.
    for p in (
        "/api/v1/auth/register",
        "/api/v1/auth/recover",
        "/api/v1/observations",
        "/api/v1/observations/mine",
        "/api/v1/me/feedback",
        "/api/v1/me/profile",
        "/api/v1/gamification/rankings",
        "/api/v1/public/observations",
        "/api/v1/public/indicators",
        "/api/v1/restricted/observations",
        "/api/v1/admin/indicators/organizational",
        "/api/v1/admin/allies",
        "/api/v1/admin/snapshots",
        "/api/v1/admin/institutions",
    ):
        assert p in paths, f"falta endpoint {p}"


def test_boundary_q1_no_phytosanitary_promises_in_spec():
    """Gate #1: el OpenAPI no PROMETE control fitosanitario ni recomendaciones químicas/mecánicas.

    Se escanean los `paths` (endpoints) — donde vivirían las promesas funcionales. La descripción
    de nivel `info` SÍ menciona el boundary, pero en forma NEGADA ('sin control fitosanitario');
    por eso se excluye del escaneo (declara explícitamente lo que el sistema NO hace).
    """
    spec = _client.get("/api/v1/openapi.json").json()
    paths_text = json.dumps(spec["paths"], ensure_ascii=False).lower()
    forbidden = [
        "control fitosanitario",
        "reducción de infestación",
        "reduccion de infestacion",
        "recomendación química",
        "recomendacion quimica",
        "fumigación",
        "fumigacion",
        "erradicación",
        "erradicacion",
    ]
    for term in forbidden:
        assert term not in paths_text, f"boundary Q1 violado en un endpoint: aparece '{term}'"


def test_app_starts_via_testclient():
    resp = _client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"
