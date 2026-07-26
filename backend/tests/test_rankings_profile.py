"""Rankings por periodo (Q4 E3/C2), perfil (L3, lifelist, insignias), feedback agregado."""

from __future__ import annotations

from .helpers import (
    auth_header,
    register,
    submit_confirmed_observation,
    submit_observation,
)


def test_rankings_individual_and_by_institution(client, db_session):
    admin = register(client, role="admin_consorcio")
    inst = client.post(
        "/api/v1/admin/institutions",
        headers=auth_header(admin["token"]),
        json={"name": "Prepa Centro", "estado": "Aguascalientes"},
    ).json()

    reg = register(client, institution_id=inst["id"])
    submit_confirmed_observation(client, reg["token"], lat=21.88, lon=-102.29)

    resp = client.get(
        "/api/v1/gamification/rankings?period=all", headers=auth_header(reg["token"])
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "individual" in data and "by_institution" in data
    assert any(e["handle"] == reg["handle"] for e in data["individual"])
    assert any(e["institution"] == "Prepa Centro" for e in data["by_institution"])


def test_rankings_geo_filter(client, db_session):
    from sqlalchemy import text

    reg = register(client)
    submit_confirmed_observation(client, reg["token"], lat=21.88, lon=-102.29)
    db_session.execute(text("UPDATE observation SET estado='Aguascalientes'"))
    db_session.commit()

    ags = client.get(
        "/api/v1/gamification/rankings?estado=Aguascalientes", headers=auth_header(reg["token"])
    ).json()
    jal = client.get(
        "/api/v1/gamification/rankings?estado=Jalisco", headers=auth_header(reg["token"])
    ).json()
    assert len(ags["individual"]) >= 1
    assert len(jal["individual"]) == 0


def test_profile_shows_identity_label_lifelist_badges(client, db_session):
    reg = register(client)
    submit_confirmed_observation(client, reg["token"], lat=21.88, lon=-102.29)
    resp = client.get("/api/v1/me/profile", headers=auth_header(reg["token"]))
    assert resp.status_code == 200
    p = resp.json()
    assert p["identity_label"]  # etiqueta L3 presente
    assert p["lifelist_trees"] == 1
    assert "primera_observacion" in p["badges"]
    assert p["total_points"] > 0  # recompensa base


def test_profile_counts_only_confirmed(client, db_session):
    """CR-026: subir no suma. Conteo, lifelist, insignias y puntos esperan la confirmación humana."""
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)

    p = client.get("/api/v1/me/profile", headers=auth_header(reg["token"])).json()
    assert p["total_observations"] == 0
    assert p["lifelist_trees"] == 0
    assert p["badges"] == []
    assert p["total_points"] == 0  # el ledger ya tiene las filas; no se cuentan aún

    # Un segundo aporte, este sí confirmado.
    submit_confirmed_observation(client, reg["token"], lat=21.89, lon=-102.30)
    p2 = client.get("/api/v1/me/profile", headers=auth_header(reg["token"])).json()
    assert p2["total_observations"] == 1
    assert p2["lifelist_trees"] == 1
    assert "primera_observacion" in p2["badges"]
    assert p2["total_points"] > 0


def test_points_follow_the_verdict_both_ways(client, db_session):
    """CR-026: los puntos se filtran al leer, así que un rechazo posterior los descuenta solo."""
    volunteer = register(client)
    obs_id = submit_confirmed_observation(
        client, volunteer["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    con_puntos = client.get(
        "/api/v1/me/profile", headers=auth_header(volunteer["token"])
    ).json()["total_points"]
    assert con_puntos > 0

    evaluador = register(client, role="evaluador")
    client.post(
        f"/api/v1/review/observations/{obs_id}/verdict",
        headers=auth_header(evaluador["token"]),
        json={"veredicto": "rechazada", "nota": "no es un mezquite"},
    )
    p = client.get("/api/v1/me/profile", headers=auth_header(volunteer["token"])).json()
    assert p["total_points"] == 0
    assert p["total_observations"] == 0


def test_feedback_is_aggregate_not_individual(client, db_session):
    """Resumen agregado (CR-001): cuenta confirmadas (CR-026), sin señalar observaciones concretas."""
    from sqlalchemy import text

    reg = register(client)
    # Tres observaciones: una rechazada, una confirmada y una que sigue pendiente de revisión.
    r1 = submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    submit_confirmed_observation(client, reg["token"], lat=22.10, lon=-102.50)
    submit_observation(client, reg["token"], lat=22.20, lon=-102.60)
    db_session.execute(
        text("UPDATE observation SET estado_revision='rechazada' WHERE id=:i"),
        {"i": r1.json()["observation_id"]},
    )
    db_session.commit()

    resp = client.get("/api/v1/me/feedback", headers=auth_header(reg["token"]))
    assert resp.status_code == 200
    fb = resp.json()
    assert fb["total_considered"] == 3
    assert fb["validas"] == 1  # solo la confirmada
    # Mensaje agregado: nombra confirmadas y pendientes, nunca cuál se rechazó.
    assert "confirmadas" in fb["message"]
    assert "en revisión" in fb["message"]
    assert "rechaz" not in fb["message"].lower()


def test_recover_with_backup_code(client, db_session):
    reg = register(client)
    resp = client.post(
        "/api/v1/auth/recover",
        json={"handle": reg["handle"], "backup_code": reg["backup_code"]},
    )
    assert resp.status_code == 200
    assert resp.json()["token"]
    # Código incorrecto → 401.
    bad = client.post(
        "/api/v1/auth/recover",
        json={"handle": reg["handle"], "backup_code": "MZQ-0000-0000"},
    )
    assert bad.status_code == 401
