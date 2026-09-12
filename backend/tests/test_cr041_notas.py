"""CR-041 — Notas escritas sobre una observación, independientes del veredicto.

El analista es solo lectura en cuanto al veredicto (decisión sellada) y hasta ahora la única forma
de dejar una nota era ``POST /review/observations/{id}/verdict``, que además de estar restringido a
evaluador/administrador **cambia el estado de revisión**. Desde CR-026 ese estado decide qué sale en
el mapa público, cuánto suma el voluntario y qué insignias gana: anotar no puede tener ese efecto.

Criterios de aceptación cubiertos aquí (los de consola viven en `web-admin`):

- **AC4**: el analista escribe una nota y queda con su autoría y su fecha.
- **AC5** (gate #9, el criterio central): escribir una nota **NO** cambia ``estado_revision`` ni
  añade filas a ``human_review``.
- **AC6**, **acotado por CR-042**: escriben el ``analista`` y el ``administrador``. El
  ``evaluador`` **ya no escribe** (403) — el área de comentarios es del analista y del
  administrador— pero **sí las lee** en el detalle.
- **AC7**: un rol sin revisión recibe 403; sin token, 401.
- **AC8**: el detalle devuelve las notas de la más antigua a la más reciente, con ``autor_handle``,
  para los tres roles de revisión (el ``evaluador`` incluido: lee aunque no escriba).
- **AC9**: texto vacío, de solo espacios o de más de 2 000 caracteres ⇒ 422; 2 000 exactos ⇒ 201.
- **AC10** (gate #7): append-only — no existe ruta de edición ni de borrado de notas.
- **AC11** (gate #2): las notas no salen de la consola (ni público, ni restringido, ni los 2 CSV).
- **AC12** (ARCO): al eliminar la cuenta autora, sus notas se conservan a nombre del centinela.

**CR-042 (parte A) — cambio de conducta deliberado.** ``POST .../notas`` pasó de ``REVIEW_ROLES``
(los tres) a ``_COMMENT_WRITE_ROLES`` = ``analista`` + ``administrador``. Las pruebas de escritura
del ``evaluador`` que venían de CR-041 **afirman ahora 403**: es la regla nueva, no una regresión.
La **lectura no cambia** (``GET /review/observations/{id}`` sigue con los tres roles), y el campo
``nota`` que viaja con el **veredicto** tampoco: sigue siendo de evaluador/administrador.
"""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from backend.app import db as db_module
from backend.app.models import SENTINEL_ACCOUNT_ID, Account

from .helpers import (
    auth_header,
    register,
    submit_confirmed_observation,
    submit_observation,
)

NOTA = "Se aprecia paxtle en la copa alta; conviene revisar la escala declarada."


def _nota_url(observation_id: str) -> str:
    return f"/api/v1/review/observations/{observation_id}/notas"


def _nueva_observacion(client) -> tuple[dict, str]:
    """Voluntario + una observación recién subida (queda 'aceptada')."""
    voluntario = register(client)
    obs_id = submit_observation(
        client, voluntario["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    return voluntario, obs_id


def _account_id(handle: str) -> uuid.UUID:
    s = db_module.get_sessionmaker()()
    try:
        return s.query(Account).filter(Account.handle == handle).one().id
    finally:
        s.close()


# --- AC4: el analista anota, con su autoría y su fecha ---


def test_ac4_analista_escribe_nota(client, db_session):
    """El analista —sin voto— crea una nota: 201, con su handle y su fecha."""
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")

    resp = client.post(
        _nota_url(obs_id), headers=auth_header(analista["token"]), json={"texto": NOTA}
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["texto"] == NOTA
    assert body["autor_handle"] == analista["handle"]
    assert body["created_at"]
    uuid.UUID(body["id"])  # id real, no cadena vacía

    fila = db_session.execute(
        text("SELECT texto, author_account_id FROM observation_note WHERE observation_id = :o"),
        {"o": obs_id},
    ).mappings().one()
    assert fila["texto"] == NOTA
    assert fila["author_account_id"] == _account_id(analista["handle"])


def test_nota_sobre_observacion_inexistente_es_404(client, db_session):
    analista = register(client, role="analista")
    resp = client.post(
        _nota_url(str(uuid.uuid4())),
        headers=auth_header(analista["token"]),
        json={"texto": NOTA},
    )
    assert resp.status_code == 404, resp.text


# --- AC5 (gate #9): anotar NO es decidir ---


def test_ac5_nota_no_cambia_estado_revision_ni_escribe_human_review(client, db_session):
    """El criterio central del CR: la nota no mueve el estado ni entra en el log de veredictos."""
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")

    def _estado() -> str:
        return db_session.execute(
            text("SELECT estado_revision FROM observation WHERE id = :o"), {"o": obs_id}
        ).scalar_one()

    def _veredictos() -> int:
        return int(
            db_session.execute(
                text("SELECT count(*) FROM human_review WHERE observation_id = :o"), {"o": obs_id}
            ).scalar_one()
        )

    estado_antes, veredictos_antes = _estado(), _veredictos()
    assert estado_antes == "aceptada"
    assert veredictos_antes == 0

    for i in range(3):
        resp = client.post(
            _nota_url(obs_id),
            headers=auth_header(analista["token"]),
            json={"texto": f"nota {i}"},
        )
        assert resp.status_code == 201, resp.text

    assert _estado() == estado_antes
    assert _veredictos() == veredictos_antes


def test_ac5_nota_sobre_confirmada_no_la_saca_del_publico(client, db_session):
    """Gate #9 visto desde fuera: anotar no toca el dataset público ni el contador del Monitor."""
    voluntario = register(client)
    obs_id = submit_confirmed_observation(
        client, voluntario["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    assert len(client.get("/api/v1/public/observations").json()) == 1

    analista = register(client, role="analista")
    stats_antes = client.get(
        "/api/v1/review/stats", headers=auth_header(analista["token"])
    ).json()

    resp = client.post(
        _nota_url(obs_id), headers=auth_header(analista["token"]), json={"texto": NOTA}
    )
    assert resp.status_code == 201, resp.text

    publico = client.get("/api/v1/public/observations").json()
    assert len(publico) == 1
    assert publico[0]["handle"] == voluntario["handle"]

    stats_despues = client.get(
        "/api/v1/review/stats", headers=auth_header(analista["token"])
    ).json()
    assert stats_despues == stats_antes


# --- AC6 (acotado por CR-042): escriben el analista y el administrador; el evaluador NO ---


def test_ac6_cr042_el_administrador_anota_y_el_evaluador_recibe_403(client, db_session):
    """**Esta prueba cambió de conducta con CR-042 y el cambio es intencional.**

    En CR-041 se llamaba ``test_ac6_evaluador_y_administrador_tambien_anotan`` y afirmaba que el
    ``evaluador`` escribía notas (201). Por decisión del usuario el área de comentarios es del
    ``analista`` y del ``administrador``, así que el evaluador **recibe 403 al escribir**. Su
    lectura no se tocó: eso lo cubre
    ``test_cr042_el_evaluador_lee_las_notas_que_escribe_el_analista``.
    """
    _, obs_id = _nueva_observacion(client)

    administrador = register(client, role="administrador")
    resp = client.post(
        _nota_url(obs_id),
        headers=auth_header(administrador["token"]),
        json={"texto": "nota de administrador"},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["autor_handle"] == administrador["handle"]

    evaluador = register(client, role="evaluador")
    resp = client.post(
        _nota_url(obs_id),
        headers=auth_header(evaluador["token"]),
        json={"texto": "nota de evaluador"},
    )
    assert resp.status_code == 403, resp.text

    # Solo quedó la del administrador: el 403 no escribió nada.
    filas = db_session.execute(
        text("SELECT texto FROM observation_note WHERE observation_id = :o"), {"o": obs_id}
    ).scalars().all()
    assert filas == ["nota de administrador"]


def test_cr042_el_evaluador_lee_las_notas_que_escribe_el_analista(client, db_session):
    """La prueba clave del cambio: el evaluador **no escribe pero sí lee**.

    Es la mitad de CR-042 que se puede perder de vista al cerrar la escritura: el comentario suele
    ser el contexto que ayuda al evaluador a decidir el veredicto, así que el detalle sigue
    devolviéndole ``notas``.
    """
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")
    evaluador = register(client, role="evaluador")

    assert (
        client.post(
            _nota_url(obs_id), headers=auth_header(analista["token"]), json={"texto": NOTA}
        ).status_code
        == 201
    )

    detalle = client.get(
        f"/api/v1/review/observations/{obs_id}", headers=auth_header(evaluador["token"])
    )
    assert detalle.status_code == 200, detalle.text
    notas = detalle.json()["notas"]
    assert [n["texto"] for n in notas] == [NOTA]
    assert notas[0]["autor_handle"] == analista["handle"]

    # Y la cola de revisión le sigue abierta: lee para poder emitir su veredicto.
    cola = client.get("/api/v1/review/queue", headers=auth_header(evaluador["token"]))
    assert cola.status_code == 200, cola.text


# --- AC7: authz ---


def test_ac7_rol_sin_revision_recibe_403(client, db_session):
    """Ni el voluntario ni el aliado firmante escriben notas (nunca pudieron)."""
    voluntario, obs_id = _nueva_observacion(client)
    aliado = register(client, role="aliado_firmante")

    for token in (voluntario["token"], aliado["token"]):
        resp = client.post(_nota_url(obs_id), headers=auth_header(token), json={"texto": NOTA})
        assert resp.status_code == 403, resp.text

    assert db_session.execute(text("SELECT count(*) FROM observation_note")).scalar_one() == 0


def test_ac7_sin_token_es_401(client, db_session):
    _, obs_id = _nueva_observacion(client)
    resp = client.post(_nota_url(obs_id), json={"texto": NOTA})
    assert resp.status_code == 401, resp.text


# --- AC8: el detalle devuelve las notas en orden, para los tres roles ---


def test_ac8_detalle_devuelve_notas_en_orden_para_los_tres_roles(client, db_session):
    """CR-042: las escriben analista y administrador; las **leen los tres**, evaluador incluido."""
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")
    otro_analista = register(client, role="analista")
    administrador = register(client, role="administrador")
    evaluador = register(client, role="evaluador")

    # Se escriben en un orden conocido; el detalle debe devolverlas de la más antigua a la más
    # reciente, no en el orden en que la base decida devolver las filas.
    for cuenta, texto in (
        (analista, "primera: la copa se ve despejada"),
        (otro_analista, "segunda: la foto entra de perfil"),
        (administrador, "tercera: queda para seguimiento"),
    ):
        assert (
            client.post(
                _nota_url(obs_id), headers=auth_header(cuenta["token"]), json={"texto": texto}
            ).status_code
            == 201
        )

    for cuenta in (analista, otro_analista, administrador, evaluador):
        detalle = client.get(
            f"/api/v1/review/observations/{obs_id}", headers=auth_header(cuenta["token"])
        )
        assert detalle.status_code == 200, detalle.text
        notas = detalle.json()["notas"]
        assert [n["texto"] for n in notas] == [
            "primera: la copa se ve despejada",
            "segunda: la foto entra de perfil",
            "tercera: queda para seguimiento",
        ]
        assert [n["autor_handle"] for n in notas] == [
            analista["handle"],
            otro_analista["handle"],
            administrador["handle"],
        ]
        fechas = [n["created_at"] for n in notas]
        assert fechas == sorted(fechas)


def test_detalle_sin_notas_devuelve_lista_vacia(client, db_session):
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")
    detalle = client.get(
        f"/api/v1/review/observations/{obs_id}", headers=auth_header(analista["token"])
    ).json()
    assert detalle["notas"] == []


def test_notas_no_se_cruzan_entre_observaciones(client, db_session):
    voluntario = register(client)
    obs_a = submit_observation(
        client, voluntario["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    obs_b = submit_observation(
        client, voluntario["token"], lat=21.90, lon=-102.31
    ).json()["observation_id"]
    analista = register(client, role="analista")

    client.post(_nota_url(obs_a), headers=auth_header(analista["token"]), json={"texto": "de A"})

    detalle_b = client.get(
        f"/api/v1/review/observations/{obs_b}", headers=auth_header(analista["token"])
    ).json()
    assert detalle_b["notas"] == []


# --- AC9: validación del texto ---


def test_ac9_texto_vacio_o_de_solo_espacios_es_422(client, db_session):
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")

    for texto in ("", "   ", "\n\t  \n"):
        resp = client.post(
            _nota_url(obs_id), headers=auth_header(analista["token"]), json={"texto": texto}
        )
        assert resp.status_code == 422, f"{texto!r} → {resp.status_code}"

    assert db_session.execute(text("SELECT count(*) FROM observation_note")).scalar_one() == 0


def test_ac9_texto_de_mas_de_2000_caracteres_es_422(client, db_session):
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")

    resp = client.post(
        _nota_url(obs_id), headers=auth_header(analista["token"]), json={"texto": "x" * 2001}
    )
    assert resp.status_code == 422, resp.text
    assert db_session.execute(text("SELECT count(*) FROM observation_note")).scalar_one() == 0


def test_ac9_texto_de_exactamente_2000_caracteres_es_201(client, db_session):
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")

    texto = "y" * 2000
    resp = client.post(
        _nota_url(obs_id), headers=auth_header(analista["token"]), json={"texto": texto}
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["texto"] == texto


def test_texto_se_guarda_recortado(client, db_session):
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")

    resp = client.post(
        _nota_url(obs_id),
        headers=auth_header(analista["token"]),
        json={"texto": "  con espacios alrededor  "},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["texto"] == "con espacios alrededor"


def test_check_de_la_base_tambien_rechaza_texto_en_blanco(client, db_session):
    """La garantía no depende solo de pydantic: el CHECK de `observation_note` la impone igual."""
    voluntario, obs_id = _nueva_observacion(client)
    autor_id = _account_id(voluntario["handle"])

    with pytest.raises(IntegrityError):
        db_session.execute(
            text(
                "INSERT INTO observation_note (observation_id, author_account_id, texto) "
                "VALUES (:o, :a, '   ')"
            ),
            {"o": obs_id, "a": autor_id},
        )
    db_session.rollback()


# --- AC10 (gate #7): append-only ---


def _rutas_de_la_app(client) -> dict[str, set[str]]:
    """{ruta: {métodos}} del OpenAPI publicado por la app."""
    esquema = client.app.openapi()
    return {ruta: set(ops.keys()) for ruta, ops in esquema["paths"].items()}


def test_ac10_no_hay_edicion_ni_borrado_de_notas(client, db_session):
    """No existe ruta para editar ni borrar una nota: ni en la app ni respondiendo a un método."""
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")
    creada = client.post(
        _nota_url(obs_id), headers=auth_header(analista["token"]), json={"texto": NOTA}
    )
    assert creada.status_code == 201
    nota_id = creada.json()["id"]

    rutas = {
        ruta
        for ruta, metodos in _rutas_de_la_app(client).items()
        if "notas" in ruta
    }
    # Solo la ruta de creación existe, y solo con POST.
    assert rutas == {"/api/v1/review/observations/{observation_id}/notas"}
    assert _rutas_de_la_app(client)["/api/v1/review/observations/{observation_id}/notas"] == {
        "post"
    }

    headers = auth_header(analista["token"])
    for metodo in ("put", "patch", "delete"):
        resp = client.request(
            metodo.upper(), _nota_url(obs_id), headers=headers, json={"texto": "cambiada"}
        )
        assert resp.status_code == 405, f"{metodo} → {resp.status_code}"
        resp_individual = client.request(
            metodo.upper(), f"{_nota_url(obs_id)}/{nota_id}", headers=headers
        )
        assert resp_individual.status_code in (404, 405), f"{metodo} → {resp_individual.status_code}"

    # La nota sigue ahí, intacta.
    assert (
        db_session.execute(
            text("SELECT texto FROM observation_note WHERE id = :i"), {"i": nota_id}
        ).scalar_one()
        == NOTA
    )



# --- AC11 (gate #2): las notas no salen de la consola ---


def test_ac11_las_notas_no_salen_del_detalle_de_revision(client, db_session):
    """Ni al público, ni al panel restringido, ni a las dos descargas CSV."""
    secreto = "TEXTO-DE-NOTA-QUE-NO-DEBE-SALIR-DE-LA-CONSOLA"
    voluntario = register(client)
    obs_id = submit_confirmed_observation(
        client, voluntario["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    administrador = register(client, role="administrador")
    assert (
        client.post(
            _nota_url(obs_id),
            headers=auth_header(administrador["token"]),
            json={"texto": secreto},
        ).status_code
        == 201
    )

    cabeceras = auth_header(administrador["token"])
    respuestas = {
        "público": client.get("/api/v1/public/observations"),
        "grid público": client.get("/api/v1/public/grid"),
        "indicadores públicos": client.get("/api/v1/public/indicators"),
        "restringido": client.get("/api/v1/restricted/observations", headers=cabeceras),
        "analítica": client.get("/api/v1/admin/analytics/observations", headers=cabeceras),
        "csv observaciones": client.get(
            "/api/v1/admin/analytics/observations.csv", headers=cabeceras
        ),
        "csv participación": client.get(
            "/api/v1/admin/analytics/participation.csv", headers=cabeceras
        ),
    }
    for nombre, resp in respuestas.items():
        assert resp.status_code == 200, f"{nombre}: {resp.status_code} {resp.text}"
        assert secreto not in resp.text, f"la nota se filtró en {nombre}"

    # Y sí sale, en cambio, por el detalle de revisión (que es la consola).
    detalle = client.get(
        f"/api/v1/review/observations/{obs_id}", headers=cabeceras
    ).json()
    assert [n["texto"] for n in detalle["notas"]] == [secreto]


def test_ac11_el_voluntario_no_ve_las_notas_en_su_perfil(client, db_session):
    """Gate #3/#2: la retroalimentación del voluntario no incluye lo que escribe la consola."""
    secreto = "NOTA-INTERNA-DE-LA-CONSOLA"
    voluntario = register(client)
    obs_id = submit_confirmed_observation(
        client, voluntario["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    analista = register(client, role="analista")
    assert (
        client.post(
            _nota_url(obs_id), headers=auth_header(analista["token"]), json={"texto": secreto}
        ).status_code
        == 201
    )

    for ruta in ("/api/v1/me/profile", "/api/v1/me/feedback", "/api/v1/me/evidence"):
        resp = client.get(ruta, headers=auth_header(voluntario["token"]))
        assert resp.status_code == 200, f"{ruta}: {resp.text}"
        assert secreto not in resp.text


# --- AC12 (ARCO): las notas sobreviven a la cancelación de su autor ---


def test_ac12_arco_conserva_las_notas_y_las_repunta_al_centinela(client, db_session):
    """Séptima FK a `account`: sin el repunte, eliminar a un analista con notas daría 500."""
    _, obs_id = _nueva_observacion(client)
    analista = register(client, role="analista")
    analista_id = _account_id(analista["handle"])
    assert (
        client.post(
            _nota_url(obs_id), headers=auth_header(analista["token"]), json={"texto": NOTA}
        ).status_code
        == 201
    )

    administrador = register(client, role="administrador")
    resp = client.request(
        "DELETE",
        f"/api/v1/admin/accounts/{analista_id}",
        headers=auth_header(administrador["token"]),
        json={"reason": "solicitud del titular (ARCO)"},
    )
    assert resp.status_code == 200, resp.text

    fila = db_session.execute(
        text("SELECT texto, author_account_id FROM observation_note WHERE observation_id = :o"),
        {"o": obs_id},
    ).mappings().one()
    assert fila["texto"] == NOTA  # la nota se conserva (append-only, gate #7)
    assert fila["author_account_id"] == SENTINEL_ACCOUNT_ID  # sin vínculo con la persona (gate #2)

    # El detalle sigue funcionando: la autoría pasa a la cuenta centinela, no revienta el JOIN.
    detalle = client.get(
        f"/api/v1/review/observations/{obs_id}", headers=auth_header(administrador["token"])
    )
    assert detalle.status_code == 200, detalle.text
    assert len(detalle.json()["notas"]) == 1
