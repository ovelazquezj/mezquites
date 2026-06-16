"""Rankings por periodo (Q4 E3/C2), perfil (L3, lifelist, insignias), feedback agregado."""

from __future__ import annotations

from .helpers import auth_header, register, submit_observation


def test_rankings_individual_and_by_institution(client, db_session):
    admin = register(client, role="admin_consorcio")
    inst = client.post(
        "/api/v1/admin/institutions",
        headers=auth_header(admin["token"]),
        json={"name": "Prepa Centro", "estado": "Aguascalientes"},
    ).json()

    reg = register(client, institution_id=inst["id"])
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)

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
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
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
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    resp = client.get("/api/v1/me/profile", headers=auth_header(reg["token"]))
    assert resp.status_code == 200
    p = resp.json()
    assert p["identity_label"]  # etiqueta L3 presente
    assert p["lifelist_trees"] == 1
    assert "primera_observacion" in p["badges"]
    assert p["total_points"] > 0  # recompensa base


def test_feedback_is_aggregate_not_individual(client, db_session):
    """Resumen agregado (CR-001): cuenta no-rechazadas, sin señalar observaciones individuales."""
    from sqlalchemy import text

    reg = register(client)
    # Dos observaciones (ambas nacen 'aceptada'); un veredicto humano rechaza una.
    r1 = submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    submit_observation(client, reg["token"], lat=22.10, lon=-102.50)
    db_session.execute(
        text("UPDATE observation SET estado_revision='rechazada' WHERE id=:i"),
        {"i": r1.json()["observation_id"]},
    )
    db_session.commit()

    resp = client.get("/api/v1/me/feedback", headers=auth_header(reg["token"]))
    assert resp.status_code == 200
    fb = resp.json()
    assert fb["total_considered"] == 2
    assert fb["validas"] == 1  # una no-rechazada
    # Mensaje agregado, sin señalar cuál observación se rechazó.
    assert "aceptadas" in fb["message"]


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
