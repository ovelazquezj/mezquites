"""CR-036: la geografía la deriva el SERVIDOR del punto capturado, no el cliente.

Reemplaza a ``test_cr010_autodeclared_estado.py``, cuya premisa era la contraria: allí, si el payload
traía estado/municipio, se guardaban tal cual. Ese fue exactamente el mecanismo que puso 39
observaciones de Zacatecas en producción etiquetadas "Calvillo, Aguascalientes", y otras 196 del
municipio de Aguascalientes contadas como Jesús María.

Los límites de prueba son **sintéticos** (dos cuadrados), no el marco nacional del INEGI: una prueba
no debe depender de un artefacto de 62 MB. La fidelidad del dataset real se verifica aparte, en la
prueba de aceptación de ``scripts/geo/preparar_limites_inegi.py`` (que resuelve coordenadas reales de
producción contra los polígonos reales).
"""

from __future__ import annotations

import json
from datetime import datetime, timezone

import pytest
from sqlalchemy import text

from .helpers import (
    PUNTO_AGS,
    PUNTO_FUERA,
    PUNTO_JALPA,
    auth_header,
    fake_jpeg,
    register,
)

def _submit(client, token, *, lat, lon, **extra) -> str:
    payload = {
        "lat": lat,
        "lon": lon,
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "nivel_g4": "leve",
        "flag_cuscuta": False,
        "flag_danio": False,
        "tamanio": "mediano",
        "contexto": "campo_abierto",
        **extra,
    }
    resp = client.post(
        "/api/v1/observations",
        headers=auth_header(token),
        data={"payload": json.dumps(payload)},
        files={"image": fake_jpeg()},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()["observation_id"]


def _fila(db_session, obs_id):
    return db_session.execute(
        text(
            "SELECT estado, municipio, cve_ent, cve_mun, gps_accuracy_m "
            "FROM observation WHERE id=:i"
        ),
        {"i": obs_id},
    ).one()


# --- AC2: el cliente no decide -------------------------------------------------------------------


def test_ac2_lo_que_declara_el_cliente_se_ignora(client, db_session, limites):
    """El caso exacto de producción: coordenadas en Jalpa, etiqueta "Calvillo, Aguascalientes"."""
    reg = register(client)
    lat, lon = PUNTO_JALPA
    obs_id = _submit(
        client,
        reg["token"],
        lat=lat,
        lon=lon,
        estado="Aguascalientes",
        municipio="Calvillo",
    )
    estado, municipio, cve_ent, cve_mun, _ = _fila(db_session, obs_id)
    assert (estado, municipio) == ("Zacatecas", "Jalpa")
    assert (cve_ent, cve_mun) == ("32", "019")


def test_ac2_un_estado_inventado_tampoco_gana(client, db_session, limites):
    reg = register(client)
    lat, lon = PUNTO_AGS
    obs_id = _submit(
        client, reg["token"], lat=lat, lon=lon, estado="Yucatán", municipio="Mérida"
    )
    estado, municipio, cve_ent, _, _ = _fila(db_session, obs_id)
    assert (estado, municipio) == ("Aguascalientes", "Aguascalientes")
    assert cve_ent == "01"


def test_ac2_un_cliente_que_no_manda_nada_obtiene_lo_mismo(client, db_session, limites):
    """Un bundle al día ya no envía estado/municipio: el resultado debe ser idéntico."""
    reg = register(client)
    lat, lon = PUNTO_AGS
    obs_id = _submit(client, reg["token"], lat=lat, lon=lon)
    estado, municipio, cve_ent, cve_mun, _ = _fila(db_session, obs_id)
    assert (estado, municipio, cve_ent, cve_mun) == (
        "Aguascalientes",
        "Aguascalientes",
        "01",
        "001",
    )


# --- AC3: degradación amable ---------------------------------------------------------------------


def test_ac3_punto_fuera_de_todo_poligono_no_rompe_la_captura(client, db_session, limites):
    """Sin polígono que lo contenga: se guarda SIN geografía, nunca con una inventada (gate #3)."""
    reg = register(client)
    lat, lon = PUNTO_FUERA
    obs_id = _submit(
        client, reg["token"], lat=lat, lon=lon, estado="Aguascalientes", municipio="Calvillo"
    )
    estado, municipio, cve_ent, cve_mun, _ = _fila(db_session, obs_id)
    assert (estado, municipio, cve_ent, cve_mun) == (None, None, None, None)


def test_ac3_sin_limites_cargados_la_captura_sigue_funcionando(client, db_session):
    """`admin_boundary` vacía (el estado del sistema hasta este CR) no bloquea nada."""
    db_session.execute(text("DELETE FROM admin_boundary"))
    db_session.commit()
    reg = register(client)
    obs_id = _submit(client, reg["token"], lat=21.90, lon=-102.30)
    estado, municipio, _, _, _ = _fila(db_session, obs_id)
    assert (estado, municipio) == (None, None)


# --- AC16: precisión del GPS ---------------------------------------------------------------------


def test_ac16_la_precision_del_gps_se_guarda(client, db_session, limites):
    reg = register(client)
    lat, lon = PUNTO_AGS
    obs_id = _submit(client, reg["token"], lat=lat, lon=lon, gps_accuracy_m=12.5)
    assert _fila(db_session, obs_id)[4] == pytest.approx(12.5)


def test_ac16_sin_precision_es_nula_no_cero(client, db_session, limites):
    """Un cliente viejo no la manda: debe quedar NULL, no 0 — 0 significaría "fix perfecto"."""
    reg = register(client)
    lat, lon = PUNTO_AGS
    obs_id = _submit(client, reg["token"], lat=lat, lon=lon)
    assert _fila(db_session, obs_id)[4] is None


def test_ac16_una_precision_negativa_se_rechaza(client):
    reg = register(client)
    lat, lon = PUNTO_AGS
    payload = {
        "lat": lat,
        "lon": lon,
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "nivel_g4": "leve",
        "flag_cuscuta": False,
        "flag_danio": False,
        "tamanio": "mediano",
        "contexto": "campo_abierto",
        "gps_accuracy_m": -1,
    }
    resp = client.post(
        "/api/v1/observations",
        headers=auth_header(reg["token"]),
        data={"payload": json.dumps(payload)},
        files={"image": fake_jpeg()},
    )
    assert resp.status_code == 422


# --- AC6/AC7: el API de geografía ----------------------------------------------------------------


def test_ac6_resolve_devuelve_municipio_y_claves(client, limites):
    lat, lon = PUNTO_JALPA
    r = client.get(f"/api/v1/geo/resolve?lat={lat}&lon={lon}")
    assert r.status_code == 200
    assert r.json() == {
        "estado": "Zacatecas",
        "municipio": "Jalpa",
        "cve_ent": "32",
        "cve_mun": "019",
        "resuelto": True,
    }


def test_ac6_resolve_fuera_de_cobertura_es_200_no_error(client, limites):
    """El cliente necesita distinguir "no sé" de "falló"; un 404 lo trataría como error de red."""
    lat, lon = PUNTO_FUERA
    r = client.get(f"/api/v1/geo/resolve?lat={lat}&lon={lon}")
    assert r.status_code == 200
    body = r.json()
    assert body["resuelto"] is False
    assert body["estado"] is None and body["municipio"] is None


def test_ac6_resolve_valida_el_rango_de_coordenadas(client):
    assert client.get("/api/v1/geo/resolve?lat=91&lon=0").status_code == 422
    assert client.get("/api/v1/geo/resolve?lat=0&lon=-181").status_code == 422


def test_ac7_catalogo_de_estados_y_municipios(client, limites):
    estados = client.get("/api/v1/geo/estados").json()
    assert estados == [
        {"cve_ent": "01", "estado": "Aguascalientes"},
        {"cve_ent": "32", "estado": "Zacatecas"},
    ]
    todos = client.get("/api/v1/geo/municipios").json()
    assert len(todos) == 3
    solo_zac = client.get("/api/v1/geo/municipios?cve_ent=32").json()
    assert [m["municipio"] for m in solo_zac] == ["Jalpa"]


def test_ac7_el_catalogo_es_publico(client, limites):
    """Sin token: son polígonos administrativos públicos, no datos del piloto (CR-027)."""
    for ruta in ("/api/v1/geo/estados", "/api/v1/geo/municipios", "/api/v1/geo/resolve?lat=21.9&lon=-102.3"):
        assert client.get(ruta).status_code == 200, ruta
