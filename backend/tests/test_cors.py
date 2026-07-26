"""CORS (CR-004 W3): el navegador habla con la API sin el workaround de Chrome.

Verifica, sin DB, que:
- En **dev**, un origen `http://localhost:*` recibe `Access-Control-Allow-Origin` (preflight
  OPTIONS y respuesta simple); un origen ajeno NO lo recibe.
- En **prod** con lista explícita, solo los dominios configurados pasan; el resto se niega.
- Nunca se devuelve `*` con credenciales (riesgo §9 del CR-004).

Construye apps frescas con `create_app()` tras fijar el entorno y limpiar el cache de settings,
para no depender del `app` singleton (que toma la config del proceso al importarse).
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from backend.app.config import get_settings
from backend.app.main import create_app


@pytest.fixture()
def dev_client(monkeypatch):
    """App en modo dev (localhost permitido por regex, sin enumerar puertos)."""
    monkeypatch.setenv("CORS_ENV", "dev")
    monkeypatch.delenv("CORS_ALLOW_ORIGINS", raising=False)
    monkeypatch.delenv("CORS_ALLOW_ORIGIN_REGEX", raising=False)
    get_settings.cache_clear()
    client = TestClient(create_app())
    yield client
    get_settings.cache_clear()


@pytest.fixture()
def prod_client(monkeypatch):
    """App en modo prod con una lista explícita de orígenes (sin relajación a localhost)."""
    monkeypatch.setenv("CORS_ENV", "prod")
    monkeypatch.setenv("CORS_ALLOW_ORIGINS", "https://app.mezquite.org,https://admin.mezquite.org")
    monkeypatch.delenv("CORS_ALLOW_ORIGIN_REGEX", raising=False)
    # CR-027: fuera de dev, arrancar con el AUTH_SECRET por defecto es un error de configuración y
    # `create_app()` se niega. Esta prueba es de CORS, así que se le da un secreto propio.
    monkeypatch.setenv("AUTH_SECRET", "secreto-de-prueba-no-usado-para-firmar-nada")
    get_settings.cache_clear()
    client = TestClient(create_app())
    yield client
    get_settings.cache_clear()


# --- dev ---

def test_dev_preflight_allows_localhost(dev_client):
    """Preflight OPTIONS desde un localhost (puerto efímero de Flutter web) ⇒ permitido."""
    resp = dev_client.options(
        "/api/v1/public/observations",
        headers={
            "Origin": "http://localhost:53217",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert resp.status_code in (200, 204)
    assert resp.headers["access-control-allow-origin"] == "http://localhost:53217"
    # Métodos permitidos anunciados en el preflight.
    assert "GET" in resp.headers.get("access-control-allow-methods", "")


def test_dev_simple_request_echoes_localhost_origin(dev_client):
    resp = dev_client.get(
        "/healthz",
        headers={"Origin": "http://127.0.0.1:8080"},
    )
    assert resp.status_code == 200
    assert resp.headers["access-control-allow-origin"] == "http://127.0.0.1:8080"


def test_dev_denies_foreign_origin(dev_client):
    """Un origen ajeno (no localhost) NO recibe el header de permiso, ni siquiera en dev."""
    resp = dev_client.get(
        "/healthz",
        headers={"Origin": "https://evil.example.com"},
    )
    assert resp.status_code == 200
    assert "access-control-allow-origin" not in resp.headers


def test_dev_never_wildcard_with_credentials(dev_client):
    """Gate de seguridad: nunca `*` (Starlette refleja el origen permitido, no comodín)."""
    resp = dev_client.get("/healthz", headers={"Origin": "http://localhost:5000"})
    assert resp.headers.get("access-control-allow-origin") != "*"
    # Con credenciales habilitadas, el origen reflejado debe ser exacto.
    assert resp.headers.get("access-control-allow-credentials") == "true"


# --- prod ---

def test_prod_allows_listed_origin(prod_client):
    resp = prod_client.get(
        "/healthz",
        headers={"Origin": "https://app.mezquite.org"},
    )
    assert resp.status_code == 200
    assert resp.headers["access-control-allow-origin"] == "https://app.mezquite.org"


def test_prod_denies_localhost(prod_client):
    """En prod NO se relaja a localhost (la regex de dev no aplica)."""
    resp = prod_client.get(
        "/healthz",
        headers={"Origin": "http://localhost:53217"},
    )
    assert resp.status_code == 200
    assert "access-control-allow-origin" not in resp.headers


def test_prod_denies_unlisted_origin(prod_client):
    resp = prod_client.options(
        "/api/v1/public/observations",
        headers={
            "Origin": "https://phishing.mezquite.org.evil.com",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert "access-control-allow-origin" not in resp.headers
