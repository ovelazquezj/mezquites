"""CR-036 (AC24): el backfill re-deriva el histórico y su guarda impide escribir a ciegas.

Se siembra el escenario real de producción en miniatura: una observación bien etiquetada, una mal
etiquetada dentro del estado (el caso mayoritario e invisible), una mal etiquetada cruzando la línea
estatal (las que destaparon el CR) y una fuera de todo polígono.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

import pytest
from sqlalchemy import text

from backend.app.backfill_geografia import _analizar, _SQL_APLICAR, _SQL_APLICAR_TREE

from .helpers import PUNTO_AGS, PUNTO_FUERA, PUNTO_JALPA


def _insertar(db, *, lat, lon, estado, municipio) -> uuid.UUID:
    """Inserta una observación mínima con la etiqueta que habría puesto la app vieja."""
    oid = uuid.uuid4()
    cuenta = db.execute(
        text("SELECT id, handle FROM account LIMIT 1")
    ).first()
    db.execute(
        text(
            """
            INSERT INTO observation
                (id, account_id, handle, image_ref, geom, captured_at, nivel_g4,
                 flag_cuscuta, flag_danio, estado, municipio, estado_revision)
            VALUES
                (:id, :cuenta, :handle, 'k.jpg',
                 ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                 :cuando, 'leve', false, false, :estado, :municipio, 'confirmada')
            """
        ),
        {
            "id": oid,
            "cuenta": cuenta[0],
            "handle": cuenta[1],
            "lon": lon,
            "lat": lat,
            "cuando": datetime.now(timezone.utc),
            "estado": estado,
            "municipio": municipio,
        },
    )
    return oid


@pytest.fixture()
def escenario(client, db_session, limites):
    """Cuatro observaciones que reproducen los cuatro desenlaces posibles."""
    from .helpers import register

    register(client)  # garantiza que exista una cuenta a la que colgarlas
    db_session.execute(text("DELETE FROM observation"))

    ids = {
        # Ya estaba bien: no debe contarse como cambio.
        "correcta": _insertar(
            db_session, lat=PUNTO_AGS[0], lon=PUNTO_AGS[1],
            estado="Aguascalientes", municipio="Aguascalientes",
        ),
        # Mal DENTRO del estado: el caso de las 196 de producción.
        "mal_dentro": _insertar(
            db_session, lat=PUNTO_AGS[0], lon=PUNTO_AGS[1],
            estado="Aguascalientes", municipio="Jesús María",
        ),
        # Mal CRUZANDO la línea estatal: el caso de las 39.
        "mal_fuera_del_estado": _insertar(
            db_session, lat=PUNTO_JALPA[0], lon=PUNTO_JALPA[1],
            estado="Aguascalientes", municipio="Calvillo",
        ),
        # Fuera de todo polígono: no se puede verificar.
        "sin_cobertura": _insertar(
            db_session, lat=PUNTO_FUERA[0], lon=PUNTO_FUERA[1],
            estado="Aguascalientes", municipio="Calvillo",
        ),
    }
    db_session.commit()
    return ids


def _etiqueta(db_session, oid):
    return db_session.execute(
        text("SELECT estado, municipio, cve_ent, cve_mun FROM observation WHERE id=:i"),
        {"i": oid},
    ).one()


def test_ac24_el_simulacro_cuenta_exactamente_lo_que_cambia(db_session, escenario):
    total, sin_resolver, cambian, desglose = _analizar(db_session)
    assert total == 4
    assert sin_resolver == 1  # la de fuera de cobertura
    assert cambian == 2  # la mal etiquetada dentro y la de otro estado
    assert {(a, d, n) for a, d, n in desglose} == {
        ("Aguascalientes / Jesús María", "Aguascalientes / Aguascalientes", 1),
        ("Aguascalientes / Calvillo", "Zacatecas / Jalpa", 1),
    }
    db_session.rollback()


def test_ac24_el_simulacro_no_escribe(db_session, escenario):
    _analizar(db_session)
    db_session.rollback()
    # La etiqueta equivocada sigue intacta: el simulacro solo mira.
    assert _etiqueta(db_session, escenario["mal_fuera_del_estado"])[:2] == (
        "Aguascalientes",
        "Calvillo",
    )


def test_ac24_aplicar_corrige_y_llena_las_claves(db_session, escenario):
    _analizar(db_session)
    db_session.execute(text(_SQL_APLICAR))
    db_session.execute(text(_SQL_APLICAR_TREE))
    db_session.commit()

    assert _etiqueta(db_session, escenario["mal_fuera_del_estado"]) == (
        "Zacatecas", "Jalpa", "32", "019",
    )
    assert _etiqueta(db_session, escenario["mal_dentro"]) == (
        "Aguascalientes", "Aguascalientes", "01", "001",
    )
    # La que ya estaba bien también gana sus claves, sin cambiar de nombre.
    assert _etiqueta(db_session, escenario["correcta"]) == (
        "Aguascalientes", "Aguascalientes", "01", "001",
    )


def test_ac24_lo_que_no_resuelve_conserva_su_etiqueta(db_session, escenario):
    """Fuera de todo polígono no se borra nada: el backfill corrige, no destruye."""
    _analizar(db_session)
    db_session.execute(text(_SQL_APLICAR))
    db_session.commit()
    assert _etiqueta(db_session, escenario["sin_cobertura"]) == (
        "Aguascalientes", "Calvillo", None, None,
    )


def test_ac24_el_total_de_observaciones_no_cambia(db_session, escenario):
    """Re-etiquetar no puede crear ni borrar filas (gate #9: el universo publicado es el mismo)."""
    antes = db_session.execute(text("SELECT count(*) FROM observation")).scalar_one()
    _analizar(db_session)
    db_session.execute(text(_SQL_APLICAR))
    db_session.commit()
    despues = db_session.execute(text("SELECT count(*) FROM observation")).scalar_one()
    assert antes == despues == 4


def test_ac24_ningun_veredicto_se_toca(db_session, escenario):
    """Gate #7: `estado_revision` y el log de revisión quedan como estaban."""
    _analizar(db_session)
    db_session.execute(text(_SQL_APLICAR))
    db_session.commit()
    estados = db_session.execute(
        text("SELECT DISTINCT estado_revision FROM observation")
    ).scalars().all()
    assert estados == ["confirmada"]
    assert db_session.execute(text("SELECT count(*) FROM human_review")).scalar_one() == 0
