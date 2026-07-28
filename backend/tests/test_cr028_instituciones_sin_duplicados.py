"""CR-028: una institución por nombre — no se pueden registrar gemelas.

Origen real: en producción convivían dos "Global University" (una con estado y otra sin él) porque
ninguna capa comprobaba si el nombre ya existía. Estas pruebas fijan la regla en las tres capas que
tienen que coincidir:

- **base**: índice único sobre el nombre canónico ⇒ ni un INSERT directo puede duplicar;
- **voluntario** (``POST /institutions/request``): reusa la existente y afilia la cuenta (200);
- **consola** (``POST /admin/institutions``): 409 que nombra la institución que ya está.

"Mismo nombre" = igual tras quitar acentos, bajar a minúsculas y colapsar espacios.
"""

from __future__ import annotations

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from .helpers import auth_header, register

# Variantes del MISMO nombre: acentos, mayúsculas y espacios de más.
VARIANTES = [
    "Universidad Cuauhtémoc",
    "universidad cuauhtemoc",
    "  UNIVERSIDAD   Cuauhtémoc  ",
    "Universidad  CUAUHTEMOC",
]


def _cuenta_filas(db_session, nombre_canonico: str) -> int:
    from backend.app.institution_names import NORMALIZED_NAME_SQL

    return db_session.execute(
        text(f"SELECT count(*) FROM institution WHERE {NORMALIZED_NAME_SQL} = :n"),
        {"n": nombre_canonico},
    ).scalar_one()


def test_solicitar_dos_veces_el_mismo_nombre_no_duplica(client, db_session):
    """El caso exacto de producción: dos altas del mismo nombre ⇒ una sola institución."""
    a = register(client)
    b = register(client)

    r1 = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(a["token"]),
        json={"name": "Global University"},  # como lo manda el LOGIN: sin estado
    )
    assert r1.status_code == 201, r1.text
    assert r1.json()["ya_existia"] is False

    r2 = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(b["token"]),
        json={"name": "Global University", "estado": "Aguascalientes"},  # como lo manda CUENTA
    )
    # 200 (no 201): no se creó nada, se reusó la existente.
    assert r2.status_code == 200, r2.text
    assert r2.json()["ya_existia"] is True
    assert r2.json()["id"] == r1.json()["id"]

    assert _cuenta_filas(db_session, "global university") == 1


@pytest.mark.parametrize("variante", VARIANTES[1:])
def test_variantes_de_acentos_mayusculas_y_espacios_son_la_misma(client, db_session, variante):
    primero = register(client)
    otro = register(client)

    r1 = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(primero["token"]),
        json={"name": VARIANTES[0]},
    )
    assert r1.status_code == 201, r1.text

    r2 = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(otro["token"]),
        json={"name": variante},
    )
    assert r2.status_code == 200, r2.text
    assert r2.json()["id"] == r1.json()["id"]
    assert _cuenta_filas(db_session, "universidad cuauhtemoc") == 1


def test_la_segunda_cuenta_queda_afiliada_a_la_institucion_existente(client, db_session):
    """Reusar no es solo "no crear": la cuenta tiene que quedar apuntando a la que sobrevive."""
    a = register(client)
    b = register(client)
    r1 = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(a["token"]),
        json={"name": "Prepa del Valle"},
    )
    client.post(
        "/api/v1/institutions/request",
        headers=auth_header(b["token"]),
        json={"name": "PREPA DEL VALLE"},
    )

    inst_id = r1.json()["id"]
    afiliadas = db_session.execute(
        text("SELECT count(*) FROM account WHERE institution_id = :i"), {"i": inst_id}
    ).scalar_one()
    assert afiliadas == 2


def test_reusar_no_cambia_el_estado_de_la_existente(client, db_session):
    """Una ``solicitada`` reusada sigue ``solicitada``: reusar no puede aprobar por la puerta de atrás."""
    a = register(client)
    b = register(client)
    client.post(
        "/api/v1/institutions/request",
        headers=auth_header(a["token"]),
        json={"name": "Pendiente de Revisión"},
    )
    r2 = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(b["token"]),
        json={"name": "pendiente de revision"},
    )
    assert r2.json()["status"] == "solicitada"
    publico = {i["name"] for i in client.get("/api/v1/institutions").json()}
    assert "Pendiente de Revisión" not in publico


def test_alta_desde_la_consola_duplicada_es_409(client, db_session):
    admin = register(client, role="administrador")
    r1 = client.post(
        "/api/v1/admin/institutions",
        headers=auth_header(admin["token"]),
        json={"name": "Instituto Tecnológico de Aguascalientes"},
    )
    assert r1.status_code == 201, r1.text

    r2 = client.post(
        "/api/v1/admin/institutions",
        headers=auth_header(admin["token"]),
        json={"name": "instituto tecnologico de aguascalientes"},
    )
    assert r2.status_code == 409, r2.text
    # El mensaje nombra la que YA está, para que el admin actúe sobre esa.
    assert "Instituto Tecnológico de Aguascalientes" in r2.json()["detail"]
    assert _cuenta_filas(db_session, "instituto tecnologico de aguascalientes") == 1


def test_la_consola_no_puede_duplicar_una_solicitada_por_el_voluntario(client, db_session):
    """El duplicado real nació así: nadie veía la ``solicitada`` y se capturó otra igual."""
    vol = register(client)
    client.post(
        "/api/v1/institutions/request",
        headers=auth_header(vol["token"]),
        json={"name": "Universidad Politécnica"},
    )
    admin = register(client, role="administrador")
    r = client.post(
        "/api/v1/admin/institutions",
        headers=auth_header(admin["token"]),
        json={"name": "universidad politecnica", "estado": "Aguascalientes"},
    )
    assert r.status_code == 409, r.text
    assert "pendiente de aprobación" in r.json()["detail"]


def test_el_indice_unico_impide_el_duplicado_incluso_por_sql_directo(client, db_session):
    """Última línea de defensa: aunque alguien escriba en la tabla saltándose la API."""
    db_session.execute(
        text("INSERT INTO institution (name, estado, status) VALUES ('Colegio Fénix', NULL, 'aprobada')")
    )
    db_session.commit()

    with pytest.raises(IntegrityError):
        db_session.execute(
            text(
                "INSERT INTO institution (name, estado, status) "
                "VALUES ('  colegio   fenix ', 'Aguascalientes', 'aprobada')"
            )
        )
        db_session.commit()
    db_session.rollback()

    assert _cuenta_filas(db_session, "colegio fenix") == 1


@pytest.mark.parametrize("nombre", ["", "   ", "\t\n"])
def test_nombre_vacio_o_solo_espacios_se_rechaza(client, db_session, nombre):
    vol = register(client)
    r = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(vol["token"]),
        json={"name": nombre},
    )
    assert r.status_code == 422, r.text


def test_el_nombre_se_guarda_con_espacios_normalizados(client, db_session):
    """Se conserva la escritura del usuario (acentos y mayúsculas), pero sin espacios de sobra."""
    vol = register(client)
    r = client.post(
        "/api/v1/institutions/request",
        headers=auth_header(vol["token"]),
        json={"name": "  Escuela   Normal  Superior  "},
    )
    assert r.json()["name"] == "Escuela Normal Superior"


def test_estado_en_blanco_se_guarda_como_nulo(client, db_session):
    """'' y NULL no pueden ser dos "estados" distintos (la consola manda '' cuando lo dejas vacío)."""
    admin = register(client, role="administrador")
    r = client.post(
        "/api/v1/admin/institutions",
        headers=auth_header(admin["token"]),
        json={"name": "Sin Estado AC", "estado": "   "},
    )
    assert r.status_code == 201, r.text
    assert r.json()["estado"] is None


def test_la_siembra_reconoce_variantes_previas_y_no_duplica(client, db_session):
    """Antes reventaba (``one_or_none``) o sembraba gemelas; ahora compara por nombre canónico."""
    from backend.app.seed_institutions import INSTITUCIONES, seed_institutions

    # Alguien capturó a mano una de las de la lista, sin acentos y en minúsculas.
    db_session.execute(
        text(
            "INSERT INTO institution (name, estado, status) "
            "VALUES ('universidad autonoma de aguascalientes (uaa)', NULL, 'aprobada')"
        )
    )
    db_session.commit()

    insertadas, ya_existian = seed_institutions(db_session)
    assert ya_existian == 1
    assert insertadas == len(INSTITUCIONES) - 1

    total = db_session.execute(text("SELECT count(*) FROM institution")).scalar_one()
    assert total == len(INSTITUCIONES)
