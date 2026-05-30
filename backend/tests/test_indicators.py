"""Indicadores Q6 calculados automáticamente, SIN umbrales/aprobación (U1, gate boundary)."""

from __future__ import annotations

import inspect

from sqlalchemy import text

from backend.app import indicators as indicators_module
from .helpers import register, submit_observation


def test_indicators_compute_automatically(client, db_session):
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29, nivel_g4="moderado")
    resp = client.get("/api/v1/public/indicators")
    assert resp.status_code == 200
    data = resp.json()
    assert set(["social", "educativo", "ecologico", "organizacional"]).issubset(data.keys())
    assert data["social"]["observaciones_totales"] == 1
    assert data["social"]["registrados"] >= 1
    assert data["ecologico"]["distribucion_niveles"].get("moderado") == 1
    # Caveat de origen ciudadano presente.
    assert "ciudadano" in data["caveat"].lower()


def test_indicators_have_no_threshold_logic():
    """Gate U1: ningún indicador dispara aprobación/reprobación. No hay umbrales en el CÓDIGO.

    Se analiza el cuerpo ejecutable (sin docstrings ni comentarios): los docstrings SÍ mencionan
    'sin umbrales' por negación, lo cual documenta el régimen U1, no lo viola.
    """
    import ast

    src = inspect.getsource(indicators_module)
    tree = ast.parse(src)
    # Elimina docstrings de módulo/funciones/clases.
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            body = getattr(node, "body", [])
            if (
                body
                and isinstance(body[0], ast.Expr)
                and isinstance(body[0].value, ast.Constant)
                and isinstance(body[0].value.value, str)
            ):
                body.pop(0)
    code_only = ast.unparse(tree).lower()
    for forbidden in ("umbral", "threshold", "target", "aprobad", "reprobad", "pass_fail"):
        assert forbidden not in code_only


def test_indicators_filter_by_estado(client, db_session):
    # Insertar dos observaciones con estado distinto directamente (sin admin_boundary cargado).
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    db_session.execute(text("UPDATE observation SET estado='Aguascalientes'"))
    db_session.commit()

    ags = client.get("/api/v1/public/indicators?estado=Aguascalientes").json()
    other = client.get("/api/v1/public/indicators?estado=Jalisco").json()
    assert ags["social"]["observaciones_totales"] == 1
    assert other["social"]["observaciones_totales"] == 0


def test_organizational_indicator_capture_and_surface(client, db_session):
    admin = register(client, role="admin_consorcio")
    from .helpers import auth_header

    resp = client.post(
        "/api/v1/admin/indicators/organizational",
        headers=auth_header(admin["token"]),
        json={"key": "mesas_formales", "value": 3},
    )
    assert resp.status_code == 201
    data = client.get("/api/v1/public/indicators").json()
    assert data["organizacional"].get("mesas_formales") == 3
