"""CR-042 (parte B) — Los indicadores organizacionales se leen, se corrigen y **se suman**.

La pantalla "Indicadores" de la consola solo sabía escribir. Al investigar aparecieron tres fallas,
y las tres se cubren aquí:

- **AC-B1 (la central): el panel público contaba de menos.** La agregación era ``{key: value}``
  sobre un SELECT sin ``GROUP BY``, así que dos filas de la misma ``key`` se pisaban y solo
  sobrevivía la última. En producción, dos menciones en medios de valor 1 cada una se publicaban
  como **1**. Ninguna prueba lo cubría porque todas registraban un indicador de cada tipo, y con una
  sola fila "pisar" y "sumar" dan lo mismo.
- **AC-B2: no había forma de leer lo capturado.** Solo existía el POST, así que los indicadores
  "desaparecían" al cambiar de sección.
- **AC-B3: ``estado`` se usaba como descripción.** Es el filtro geográfico del panel (va junto a
  ``municipio``/``cve_ent``), pero la consola lo pedía como texto libre; ahora es obligatorio y
  existe ``descripcion`` para el relato del evento.

Más: PATCH/DELETE (corregir una captura equivocada sin duplicarla), 404 con id inexistente, RBAC en
los cuatro verbos, y la regresión del filtro geográfico.

Gate #1 (U1): estos indicadores no llevan umbrales, metas ni semáforos — aquí solo se cuenta.
"""

from __future__ import annotations

import uuid

from .helpers import auth_header, register

URL = "/api/v1/admin/indicators/organizational"


def _admin(client) -> dict:
    return register(client, role="administrador")


def _captura(client, token: str, **campos):
    """POST de un indicador con los campos mínimos ya puestos."""
    body = {"key": "menciones_mediaticas", "value": 1, "estado": "Aguascalientes"}
    body.update(campos)
    return client.post(URL, headers=auth_header(token), json=body)


def _organizacional(client, query: str = "") -> dict:
    return client.get(f"/api/v1/public/indicators{query}").json()["organizacional"]


# --- AC-B1: dos registros de la misma clave SUMAN (el bug que nadie cubría) ---


def test_dos_registros_de_la_misma_clave_suman_en_el_panel_publico(client, db_session):
    """Dos menciones de valor 1 deben publicarse como **2**, no como 1.

    Es exactamente el caso de producción: el dict sin ``GROUP BY`` se quedaba con la última fila.
    """
    admin = _admin(client)
    assert _captura(client, admin["token"], value=1).status_code == 201
    assert _captura(client, admin["token"], value=1).status_code == 201

    assert _organizacional(client)["menciones_mediaticas"] == 2


def test_la_suma_respeta_valores_distintos_y_no_mezcla_claves(client, db_session):
    """Tres capturas: dos de una clave (2 + 5) y una de otra. Cada clave suma lo suyo."""
    admin = _admin(client)
    _captura(client, admin["token"], key="eventos_w3", value=2)
    _captura(client, admin["token"], key="eventos_w3", value=5)
    _captura(client, admin["token"], key="mesas_formales_autoridades", value=1)

    org = _organizacional(client)
    assert org["eventos_w3"] == 7
    assert org["mesas_formales_autoridades"] == 1


# --- AC-B3: descripción y estado obligatorio ---


def test_registra_con_descripcion_y_se_lee_de_vuelta(client, db_session):
    """La descripción es el campo que faltaba: lo que antes se tecleaba en "Estado (opcional)"."""
    admin = _admin(client)
    resp = _captura(
        client,
        admin["token"],
        key="mesas_formales_autoridades",
        descripcion="Visita Rotaract Ejecutivo",
    )
    assert resp.status_code == 201, resp.text
    creado = resp.json()
    assert creado["descripcion"] == "Visita Rotaract Ejecutivo"
    assert creado["estado"] == "Aguascalientes"
    assert creado["id"] and creado["created_at"]

    fila = client.get(URL, headers=auth_header(admin["token"])).json()[0]
    assert fila["descripcion"] == "Visita Rotaract Ejecutivo"
    assert fila["id"] == creado["id"]


def test_descripcion_se_recorta_y_en_blanco_queda_nula(client, db_session):
    admin = _admin(client)
    con_espacios = _captura(client, admin["token"], descripcion="  Nota con espacios  ").json()
    assert con_espacios["descripcion"] == "Nota con espacios"

    en_blanco = _captura(client, admin["token"], descripcion="   ").json()
    assert en_blanco["descripcion"] is None


def test_descripcion_demasiado_larga_es_422(client, db_session):
    admin = _admin(client)
    assert _captura(client, admin["token"], descripcion="x" * 500).status_code == 201
    assert _captura(client, admin["token"], descripcion="x" * 501).status_code == 422


def test_estado_vacio_o_ausente_es_422(client, db_session):
    """``estado`` es el filtro geográfico: sin él la captura no cuadra con ningún corte."""
    admin = _admin(client)
    sin_estado = client.post(
        URL,
        headers=auth_header(admin["token"]),
        json={"key": "eventos_w3", "value": 1},
    )
    assert sin_estado.status_code == 422

    assert _captura(client, admin["token"], estado="").status_code == 422
    assert _captura(client, admin["token"], estado="   ").status_code == 422


# --- AC-B2: la lista ---


def test_get_lista_lo_registrado_mas_reciente_primero(client, db_session):
    admin = _admin(client)
    _captura(client, admin["token"], key="eventos_w3", descripcion="primera")
    _captura(client, admin["token"], key="eventos_w3", descripcion="segunda")
    _captura(client, admin["token"], key="menciones_mediaticas", descripcion="tercera")

    filas = client.get(URL, headers=auth_header(admin["token"])).json()
    assert [f["descripcion"] for f in filas] == ["tercera", "segunda", "primera"]


def test_get_filtra_por_key(client, db_session):
    admin = _admin(client)
    _captura(client, admin["token"], key="eventos_w3")
    _captura(client, admin["token"], key="menciones_mediaticas")

    filas = client.get(f"{URL}?key=eventos_w3", headers=auth_header(admin["token"])).json()
    assert len(filas) == 1
    assert filas[0]["key"] == "eventos_w3"


def test_get_lista_vacia_cuando_no_hay_nada(client, db_session):
    admin = _admin(client)
    assert client.get(URL, headers=auth_header(admin["token"])).json() == []


# --- PATCH: corregir sin duplicar ---


def test_patch_cambia_valor_y_descripcion(client, db_session):
    """Corregir un dígito mal tecleado: capturar otra fila lo **sumaría**, no lo arreglaría."""
    admin = _admin(client)
    creado = _captura(client, admin["token"], value=9, descripcion="mal capturado").json()

    resp = client.patch(
        f"{URL}/{creado['id']}",
        headers=auth_header(admin["token"]),
        json={"value": 2, "descripcion": "Entrevista en radio local"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["value"] == 2
    assert resp.json()["descripcion"] == "Entrevista en radio local"
    # Y el panel público publica el valor corregido, no la suma de los dos.
    assert _organizacional(client)["menciones_mediaticas"] == 2


def test_patch_cambia_estado_y_respeta_lo_no_enviado(client, db_session):
    admin = _admin(client)
    creado = _captura(client, admin["token"], value=4, descripcion="se conserva").json()

    resp = client.patch(
        f"{URL}/{creado['id']}",
        headers=auth_header(admin["token"]),
        json={"estado": "Zacatecas"},
    )
    assert resp.status_code == 200
    assert resp.json()["estado"] == "Zacatecas"
    assert resp.json()["value"] == 4
    assert resp.json()["descripcion"] == "se conserva"


def test_patch_con_descripcion_nula_explicita_la_limpia(client, db_session):
    admin = _admin(client)
    creado = _captura(client, admin["token"], descripcion="a borrar").json()

    resp = client.patch(
        f"{URL}/{creado['id']}",
        headers=auth_header(admin["token"]),
        json={"descripcion": None},
    )
    assert resp.status_code == 200
    assert resp.json()["descripcion"] is None


def test_patch_con_estado_vacio_es_422(client, db_session):
    admin = _admin(client)
    creado = _captura(client, admin["token"]).json()
    resp = client.patch(
        f"{URL}/{creado['id']}", headers=auth_header(admin["token"]), json={"estado": "  "}
    )
    assert resp.status_code == 422


def test_patch_de_id_inexistente_es_404(client, db_session):
    admin = _admin(client)
    resp = client.patch(
        f"{URL}/{uuid.uuid4()}", headers=auth_header(admin["token"]), json={"value": 1}
    )
    assert resp.status_code == 404


# --- DELETE ---


def test_delete_quita_del_listado_y_del_total_publico(client, db_session):
    admin = _admin(client)
    uno = _captura(client, admin["token"], value=1).json()
    _captura(client, admin["token"], value=1)
    assert _organizacional(client)["menciones_mediaticas"] == 2

    resp = client.delete(f"{URL}/{uno['id']}", headers=auth_header(admin["token"]))
    assert resp.status_code == 204

    filas = client.get(URL, headers=auth_header(admin["token"])).json()
    assert len(filas) == 1
    assert uno["id"] not in [f["id"] for f in filas]
    assert _organizacional(client)["menciones_mediaticas"] == 1


def test_delete_de_id_inexistente_es_404(client, db_session):
    admin = _admin(client)
    resp = client.delete(f"{URL}/{uuid.uuid4()}", headers=auth_header(admin["token"]))
    assert resp.status_code == 404


# --- RBAC: los cuatro verbos, el mismo gate que ya tenía el POST ---


def test_sin_token_es_401_en_los_cuatro_verbos(client, db_session):
    un_id = uuid.uuid4()
    assert client.get(URL).status_code == 401
    cuerpo = {"key": "eventos_w3", "value": 1, "estado": "Aguascalientes"}
    assert client.post(URL, json=cuerpo).status_code == 401
    assert client.patch(f"{URL}/{un_id}", json={"value": 1}).status_code == 401
    assert client.delete(f"{URL}/{un_id}").status_code == 401


def test_roles_sin_privilegio_reciben_403(client, db_session):
    """Evaluador, analista y voluntario no capturan ni corrigen indicadores de gestión."""
    admin = _admin(client)
    creado = _captura(client, admin["token"]).json()

    for rol in ("evaluador", "analista", "voluntario"):
        cuenta = register(client, role=rol)
        h = auth_header(cuenta["token"])
        assert client.get(URL, headers=h).status_code == 403, rol
        assert (
            client.post(
                URL, headers=h, json={"key": "eventos_w3", "value": 1, "estado": "Aguascalientes"}
            ).status_code
            == 403
        ), rol
        patch = client.patch(f"{URL}/{creado['id']}", headers=h, json={"value": 1})
        assert patch.status_code == 403, rol
        assert client.delete(f"{URL}/{creado['id']}", headers=h).status_code == 403, rol

    # Y nada de eso alteró la captura del administrador.
    assert len(client.get(URL, headers=auth_header(admin["token"])).json()) == 1


# --- Regresión: el filtro geográfico del panel sigue vivo ---


def test_el_filtro_por_estado_del_panel_sigue_funcionando(client, db_session):
    """Dos entidades distintas: cada corte ve lo suyo, y sin filtro se ve la suma nacional."""
    admin = _admin(client)
    _captura(client, admin["token"], key="eventos_w3", value=3, estado="Aguascalientes")
    _captura(client, admin["token"], key="eventos_w3", value=4, estado="Zacatecas")

    assert _organizacional(client, "?estado=Aguascalientes")["eventos_w3"] == 3
    assert _organizacional(client, "?estado=Zacatecas")["eventos_w3"] == 4
    assert _organizacional(client)["eventos_w3"] == 7


def test_el_filtro_por_estado_suma_las_de_una_misma_entidad(client, db_session):
    """El GROUP BY se aplica DESPUÉS del filtro: dos capturas de una entidad suman en su corte."""
    admin = _admin(client)
    _captura(client, admin["token"], key="eventos_w3", value=1, estado="Aguascalientes")
    _captura(client, admin["token"], key="eventos_w3", value=1, estado="Aguascalientes")
    _captura(client, admin["token"], key="eventos_w3", value=9, estado="Jalisco")

    assert _organizacional(client, "?estado=Aguascalientes")["eventos_w3"] == 2
