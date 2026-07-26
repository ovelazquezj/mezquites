"""CR-027: endurecimiento de la superficie expuesta del backend.

Dos huecos encontrados al auditar qué peticiones exigen token (2026-07-25):

- **AUTH_SECRET por defecto:** el valor de dev está en el repo. Nada impedía arrancar producción
  con él, y con un secreto conocido cualquiera puede firmarse un token con ``role: administrador``.
  Ahora ``create_app()`` se niega a arrancar fuera de dev.
- **``/files/{key}`` sin autenticación:** servía las fotos de las observaciones a quien tuviera la
  clave, sin caducidad ni revocación, mientras el mismo contenido por ``/review/.../image`` está
  restringido por rol. Se restringe a dev (y se retiró del Caddyfile, que es lo que la exponía).

Pruebas sin DB: solo construcción de la app y configuración.
"""

from __future__ import annotations

import pytest

from backend.app.config import INSECURE_DEFAULT_SECRET, get_settings
from backend.app.main import create_app


@pytest.fixture(autouse=True)
def _clean_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _files_routes(app) -> list[str]:
    return [getattr(r, "path", "") for r in app.routes if "/files" in getattr(r, "path", "")]


# --- AUTH_SECRET ---


def test_prod_refuses_to_start_with_default_secret(monkeypatch):
    """Un despliegue que olvide AUTH_SECRET falla ruidosamente en vez de arrancar inseguro."""
    monkeypatch.setenv("CORS_ENV", "prod")
    monkeypatch.setenv("AUTH_SECRET", INSECURE_DEFAULT_SECRET)
    with pytest.raises(RuntimeError, match="AUTH_SECRET"):
        create_app()


def test_prod_starts_with_a_real_secret(monkeypatch):
    monkeypatch.setenv("CORS_ENV", "prod")
    monkeypatch.setenv("AUTH_SECRET", "a" * 64)
    assert create_app() is not None


def test_dev_still_allows_the_default_secret(monkeypatch):
    """En dev el default sigue siendo válido: la paridad de entornos (gate #6) no se rompe."""
    monkeypatch.setenv("CORS_ENV", "dev")
    monkeypatch.setenv("AUTH_SECRET", INSECURE_DEFAULT_SECRET)
    assert create_app() is not None


def test_token_ttl_is_at_most_seven_days(monkeypatch):
    """No hay lista de revocación: acortar la vida del token es la mitigación disponible."""
    monkeypatch.setenv("CORS_ENV", "dev")
    assert get_settings().auth_token_ttl_seconds <= 60 * 60 * 24 * 7


# --- /files ---


def test_files_route_is_not_mounted_outside_dev(monkeypatch):
    """Fuera de dev, las imágenes NO se sirven sin token por más que el storage sea local."""
    monkeypatch.setenv("CORS_ENV", "prod")
    monkeypatch.setenv("AUTH_SECRET", "a" * 64)
    monkeypatch.setenv("STORAGE_BACKEND", "local")
    assert _files_routes(create_app()) == []


def test_files_route_stays_available_in_dev(monkeypatch):
    """En dev se conserva: es como el runbook local sirve las fotos sin montar S3."""
    monkeypatch.setenv("CORS_ENV", "dev")
    monkeypatch.setenv("STORAGE_BACKEND", "local")
    assert _files_routes(create_app()) != []


def test_caddyfile_does_not_proxy_files(monkeypatch):
    """El Caddyfile es lo que publicaba /files/* en ambos dominios; ya no debe hacerlo."""
    from pathlib import Path

    caddyfile = (
        Path(__file__).resolve().parents[2] / "infra" / "compose" / "Caddyfile"
    ).read_text(encoding="utf-8")
    assert "handle /files/*" not in caddyfile
    # El resto del proxy sigue en pie (no se rompió el despliegue al quitarlo).
    assert "handle /api/*" in caddyfile
