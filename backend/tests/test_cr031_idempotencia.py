"""CR-031 W1 — submit idempotente (`client_capture_id`) y 410 para cuenta eliminada.

Contexto: la app va a guardar capturas sin conexión y reintentar. Si el POST llega al servidor, se
guarda, y la respuesta se pierde de vuelta, el reintento crearía una **segunda observación del mismo
árbol** — y como ``assign_tree`` crea siempre un árbol nuevo (CR-022), dos mezquites en el mapa
público sin nada que delate la copia. Estas pruebas fijan que eso no pueda pasar.

El 410 va aquí y no en otro archivo porque nace del mismo diseño: la app hace lo **contrario** ante
un token vencido (conservar la cola) que ante una cuenta eliminada (borrarla), y necesita poder
distinguirlos sin leer el texto en español del `detail`.
"""

from __future__ import annotations

import uuid

from sqlalchemy import text

from .helpers import auth_header, register, submit_observation


def test_misma_captura_dos_veces_crea_una_sola_observacion(client, db_session):
    """AC1: el reintento responde 200 + `ya_existia` con el id ORIGINAL, y no inserta nada."""
    reg = register(client)
    capture_id = str(uuid.uuid4())

    primera = submit_observation(
        client, reg["token"], lat=21.88, lon=-102.29, client_capture_id=capture_id
    )
    assert primera.status_code == 201, primera.text
    assert primera.json()["ya_existia"] is False
    obs_id = primera.json()["observation_id"]

    # Mismo id de captura: es el reintento de la MISMA foto, no una observación nueva.
    reintento = submit_observation(
        client, reg["token"], lat=21.88, lon=-102.29, client_capture_id=capture_id
    )
    assert reintento.status_code == 200, reintento.text
    assert reintento.json()["ya_existia"] is True
    assert reintento.json()["observation_id"] == obs_id

    total = db_session.execute(text("SELECT count(*) FROM observation")).scalar_one()
    assert total == 1
    # Y un solo árbol: el duplicado habría creado otro (CR-022 crea árbol por captura).
    arboles = db_session.execute(text("SELECT count(*) FROM tree")).scalar_one()
    assert arboles == 1


def test_el_reintento_no_sube_otra_imagen(client, db_session):
    """El reintento no debe tocar el storage: ni otra copia, ni un objeto huérfano."""
    from backend.app.storage import get_storage

    reg = register(client)
    capture_id = str(uuid.uuid4())
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29, client_capture_id=capture_id)
    claves_tras_primera = set(getattr(get_storage(), "_mem", {}) or {})

    submit_observation(client, reg["token"], lat=21.88, lon=-102.29, client_capture_id=capture_id)
    claves_tras_reintento = set(getattr(get_storage(), "_mem", {}) or {})

    # Si el storage de pruebas expone sus claves, no debe haber crecido; si no, al menos la DB
    # sigue con una sola fila (comprobado en la prueba anterior) y una sola `image_ref`.
    if claves_tras_primera or claves_tras_reintento:
        assert claves_tras_reintento == claves_tras_primera
    refs = db_session.execute(text("SELECT count(DISTINCT image_ref) FROM observation")).scalar_one()
    assert refs == 1


def test_el_mismo_id_en_otra_cuenta_si_crea_observacion(client, db_session):
    """AC2: la unicidad es por cuenta — un id ajeno no puede reclamar la observación de otra."""
    a = register(client)
    b = register(client)
    capture_id = str(uuid.uuid4())

    r1 = submit_observation(client, a["token"], lat=21.88, lon=-102.29, client_capture_id=capture_id)
    r2 = submit_observation(client, b["token"], lat=21.90, lon=-102.31, client_capture_id=capture_id)

    assert r1.status_code == 201
    assert r2.status_code == 201, r2.text  # cuenta distinta ⇒ observación distinta
    assert r2.json()["ya_existia"] is False
    assert r1.json()["observation_id"] != r2.json()["observation_id"]
    assert db_session.execute(text("SELECT count(*) FROM observation")).scalar_one() == 2


def test_sin_client_capture_id_sigue_funcionando(client, db_session):
    """AC3: un cliente anterior a CR-031 no manda el campo — y dos envíos son dos observaciones."""
    reg = register(client)
    r1 = submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    r2 = submit_observation(client, reg["token"], lat=21.89, lon=-102.30)

    assert r1.status_code == 201 and r2.status_code == 201
    assert r1.json()["ya_existia"] is False and r2.json()["ya_existia"] is False
    # Varios NULL no chocan en el índice parcial.
    assert db_session.execute(text("SELECT count(*) FROM observation")).scalar_one() == 2
    nulos = db_session.execute(
        text("SELECT count(*) FROM observation WHERE client_capture_id IS NULL")
    ).scalar_one()
    assert nulos == 2


def test_el_indice_unico_existe_y_es_parcial(client, db_session):
    """AC4: la garantía vive en la base, no solo en el código de la aplicación."""
    definicion = db_session.execute(
        text("SELECT indexdef FROM pg_indexes WHERE indexname = 'ux_observation_client_capture'")
    ).scalar_one_or_none()
    assert definicion is not None, "falta el índice único de CR-031"
    assert "UNIQUE" in definicion
    assert "account_id" in definicion and "client_capture_id" in definicion
    assert "WHERE" in definicion  # parcial: no indexa las filas sin id de captura


def test_cuenta_eliminada_responde_410_y_sin_token_sigue_401(client, db_session):
    """AC16 (D9): 410 cuando la cuenta ya no existe; 401 se reserva a token ausente/inválido."""
    reg = register(client)
    # La cuenta desaparece (equivalente a la cancelación ARCO de CR-006).
    db_session.execute(text("DELETE FROM account WHERE handle = :h"), {"h": reg["handle"]})
    db_session.commit()

    con_token_de_cuenta_borrada = client.get(
        "/api/v1/me/profile", headers=auth_header(reg["token"])
    )
    assert con_token_de_cuenta_borrada.status_code == 410, con_token_de_cuenta_borrada.text

    # Sin token y con token basura NO cambian: siguen siendo 401.
    assert client.get("/api/v1/me/profile").status_code == 401
    assert client.get(
        "/api/v1/me/profile", headers=auth_header("no-es-un-token")
    ).status_code == 401


def test_auth_opcional_no_devuelve_410(client, db_session):
    """`get_current_user_optional` no cambia: sin cuenta, el usuario es anónimo (CR-019, gate #3).

    Reportar un problema debe funcionar incluso con un token de una cuenta que ya no existe; ahí un
    410 rompería una función que a propósito no exige sesión.
    """
    reg = register(client)
    db_session.execute(text("DELETE FROM account WHERE handle = :h"), {"h": reg["handle"]})
    db_session.commit()

    resp = client.post(
        "/api/v1/problem-reports",
        headers=auth_header(reg["token"]),
        json={"context": "general", "message": "la app no sube mis capturas", "platform": "web"},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["handle"] is None  # anónimo: la cuenta ya no existe
