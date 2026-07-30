"""CR-030 — el voluntario ve números reales (se retira la ventana de 20 del resumen).

Contexto: varios voluntarios reportaron que la app "solo deja registrar 20 mezquites". El registro
nunca tuvo tope —producción tenía cuentas con 22, 27, 31 y 37 capturas—; lo que se congelaba en 20
era el texto de ``GET /me/feedback``, calculado sobre las últimas ``feedback_window`` observaciones.

Estas pruebas fijan que ninguna cifra que el voluntario lea sea un recorte silencioso, y que el
criterio de CR-026 (válida = confirmada) siga intacto al lado del dato crudo.
"""

from __future__ import annotations

from sqlalchemy import text

from .helpers import (
    auth_header,
    confirm_observation,
    register,
    submit_confirmed_observation,
    submit_observation,
)


def _submit_many(client, token: str, n: int) -> list[str]:
    """Sube ``n`` observaciones en puntos distintos y devuelve sus ids."""
    ids = []
    for i in range(n):
        resp = submit_observation(client, token, lat=21.88 + i * 0.001, lon=-102.29 + i * 0.001)
        assert resp.status_code == 201, resp.text
        ids.append(resp.json()["observation_id"])
    return ids


def test_feedback_sin_ventana_de_20(client, db_session):
    """AC-1: con 22 subidas el resumen considera 22, no 20 (la ventana ya no existe)."""
    reg = register(client)
    _submit_many(client, reg["token"], 22)

    fb = client.get("/api/v1/me/feedback", headers=auth_header(reg["token"])).json()
    assert fb["total_considered"] == 22
    assert fb["validas"] == 0  # nadie las ha revisado todavía
    assert fb["en_revision"] == 22


def test_feedback_mensaje_usa_total_real(client, db_session):
    """AC-2: el texto nombra el total subido y el 20 no reaparece como tope."""
    reg = register(client)
    ids = _submit_many(client, reg["token"], 22)
    for oid in ids[:5]:
        confirm_observation(oid)

    fb = client.get("/api/v1/me/feedback", headers=auth_header(reg["token"])).json()
    assert fb["total_considered"] == 22
    assert fb["validas"] == 5
    assert fb["en_revision"] == 17
    assert "22" in fb["message"]
    assert "20" not in fb["message"]
    # La frase que originó el reporte ("de tus últimas N") desaparece.
    assert "últimas" not in fb["message"]


def test_feedback_concordancia_en_singular(client, db_session):
    """El texto lo lee un voluntario: con una sola observación no dice "1 observaciones"."""
    reg = register(client)
    submit_confirmed_observation(client, reg["token"], lat=21.88, lon=-102.29)

    fb = client.get("/api/v1/me/feedback", headers=auth_header(reg["token"])).json()
    assert fb["message"] == (
        "Subiste 1 observación. 1 ya está confirmada y 0 siguen en revisión."
    )


def test_feedback_vacio_no_inventa_numeros(client, db_session):
    reg = register(client)
    fb = client.get("/api/v1/me/feedback", headers=auth_header(reg["token"])).json()
    assert fb["total_considered"] == 0
    assert fb["validas"] == 0
    assert fb["en_revision"] == 0
    assert "Aún no tienes observaciones" in fb["message"]


def test_profile_expone_subidas_sin_tocar_confirmadas(client, db_session):
    """AC-4: ``total_uploaded`` es el crudo; ``total_observations`` sigue siendo CR-026."""
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    submit_observation(client, reg["token"], lat=21.89, lon=-102.30)
    submit_confirmed_observation(client, reg["token"], lat=21.90, lon=-102.31)

    p = client.get("/api/v1/me/profile", headers=auth_header(reg["token"])).json()
    assert p["total_uploaded"] == 3  # lo que el voluntario cuenta en campo
    assert p["total_observations"] == 1  # CR-026 intacto: solo confirmadas
    assert p["en_revision"] == 2
    assert p["lifelist_trees"] == 1  # también confirmadas (CR-026)


def test_en_revision_excluye_rechazadas(client, db_session):
    """AC-5: una rechazada no se cuenta como "en revisión" ni en profile ni en evidence.

    Era el bug de *Mi participación*: la app deducía la cola restando
    ``capturas_totales - capturas``, así que una rechazada aparecía como pendiente para siempre.
    """
    reg = register(client)
    r1 = submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    submit_confirmed_observation(client, reg["token"], lat=21.89, lon=-102.30)
    db_session.execute(
        text("UPDATE observation SET estado_revision='rechazada' WHERE id=:i"),
        {"i": r1.json()["observation_id"]},
    )
    db_session.commit()

    p = client.get("/api/v1/me/profile", headers=auth_header(reg["token"])).json()
    assert p["total_uploaded"] == 2
    assert p["total_observations"] == 1
    assert p["en_revision"] == 0

    ev = client.get("/api/v1/me/evidence", headers=auth_header(reg["token"])).json()
    assert ev["capturas_totales"] == 2
    assert ev["capturas"] == 1
    assert ev["en_revision"] == 0

    # El resumen tampoco delata el rechazo (decisión del usuario: no se muestra).
    fb = client.get("/api/v1/me/feedback", headers=auth_header(reg["token"])).json()
    assert "rechaz" not in fb["message"].lower()


def test_config_ya_no_expone_feedback_window(client, db_session):
    """La ventana desapareció de la configuración: no puede volver por una env var olvidada."""
    from backend.app.config import Settings

    assert not hasattr(Settings(), "feedback_window")
