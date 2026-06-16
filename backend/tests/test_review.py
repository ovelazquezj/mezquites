"""Revisión humana en el backend (CR-001): cola, detalle, veredicto, stats e imagen sin GPS.

Criterios de aceptación:
- AC1: una observación recién subida queda 'aceptada' y aparece en /public/observations.
- AC2: POST verdict {rechazada} la saca del público y escribe en human_review.
- AC3: analista recibe 403 al emitir veredicto; evaluador/administrador 200.
- AC4 (gate #5, BLOQUEANTE): /review/.../image quita el GPS del EXIF para evaluador/analista;
  con GPS solo para aliado_firmante.
"""

from __future__ import annotations

from .helpers import (
    auth_header,
    register,
    submit_jpeg_with_gps,
    submit_observation,
)


def _public_ids(client) -> set[str]:
    return {o["handle"] for o in client.get("/api/v1/public/observations").json()}


# --- AC1: aceptación por defecto + visible ---


def test_ac1_new_observation_is_aceptada_and_public(client, db_session):
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.88, lon=-102.29)
    pub = client.get("/api/v1/public/observations").json()
    assert len(pub) == 1
    assert pub[0]["handle"] == reg["handle"]


# --- AC2: veredicto rechazada saca del público + escribe human_review ---


def test_ac2_reject_removes_from_public_and_logs(client, db_session):
    from sqlalchemy import text

    volunteer = register(client)
    obs_id = submit_observation(
        client, volunteer["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    assert len(client.get("/api/v1/public/observations").json()) == 1

    evaluador = register(client, role="evaluador")
    resp = client.post(
        f"/api/v1/review/observations/{obs_id}/verdict",
        headers=auth_header(evaluador["token"]),
        json={"veredicto": "rechazada", "nota": "fuera de foco"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["estado_revision"] == "rechazada"

    # Sale del dataset público.
    assert client.get("/api/v1/public/observations").json() == []
    # Queda una fila en human_review.
    n = db_session.execute(
        text("SELECT count(*) FROM human_review WHERE observation_id=:i"), {"i": obs_id}
    ).scalar_one()
    assert n == 1


def test_confirm_keeps_public_and_sets_confirmada(client, db_session):
    volunteer = register(client)
    obs_id = submit_observation(
        client, volunteer["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]

    admin = register(client, role="administrador")
    resp = client.post(
        f"/api/v1/review/observations/{obs_id}/verdict",
        headers=auth_header(admin["token"]),
        json={"veredicto": "confirmada"},
    )
    assert resp.status_code == 200
    assert resp.json()["estado_revision"] == "confirmada"
    # Confirmada sigue siendo pública (no-rechazada).
    assert len(client.get("/api/v1/public/observations").json()) == 1


def test_reject_does_not_revert_points(client, db_session):
    """CR-001: un rechazo NO revierte los puntos otorgados al subir."""
    from sqlalchemy import text

    volunteer = register(client)
    obs_id = submit_observation(
        client, volunteer["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    points_before = db_session.execute(
        text("SELECT COALESCE(sum(points),0) FROM points_ledger WHERE observation_id=:i"),
        {"i": obs_id},
    ).scalar_one()

    evaluador = register(client, role="evaluador")
    client.post(
        f"/api/v1/review/observations/{obs_id}/verdict",
        headers=auth_header(evaluador["token"]),
        json={"veredicto": "rechazada"},
    )
    db_session.expire_all()
    points_after = db_session.execute(
        text("SELECT COALESCE(sum(points),0) FROM points_ledger WHERE observation_id=:i"),
        {"i": obs_id},
    ).scalar_one()
    assert points_after == points_before
    assert points_after > 0


# --- AC3: RBAC del veredicto (analista solo lectura) ---


def test_ac3_analista_cannot_emit_verdict(client, db_session):
    volunteer = register(client)
    obs_id = submit_observation(
        client, volunteer["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]

    analista = register(client, role="analista")
    resp = client.post(
        f"/api/v1/review/observations/{obs_id}/verdict",
        headers=auth_header(analista["token"]),
        json={"veredicto": "confirmada"},
    )
    assert resp.status_code == 403


def test_ac3_evaluador_and_admin_can_emit_verdict(client, db_session):
    volunteer = register(client)
    ids = [
        submit_observation(client, volunteer["token"], lat=21.88, lon=-102.29).json()[
            "observation_id"
        ]
        for _ in range(2)
    ]
    for role, obs_id in zip(("evaluador", "administrador"), ids):
        reviewer = register(client, role=role)
        resp = client.post(
            f"/api/v1/review/observations/{obs_id}/verdict",
            headers=auth_header(reviewer["token"]),
            json={"veredicto": "confirmada"},
        )
        assert resp.status_code == 200, (role, resp.text)


def test_voluntario_cannot_access_review_queue(client, db_session):
    volunteer = register(client)
    resp = client.get("/api/v1/review/queue", headers=auth_header(volunteer["token"]))
    assert resp.status_code == 403


def test_review_queue_without_token_is_401(client, db_session):
    assert client.get("/api/v1/review/queue").status_code == 401


# --- Cola + detalle + stats ---


def test_queue_lists_and_filters(client, db_session):
    volunteer = register(client)
    submit_observation(client, volunteer["token"], lat=21.88, lon=-102.29)
    evaluador = register(client, role="evaluador")

    rows = client.get(
        "/api/v1/review/queue", headers=auth_header(evaluador["token"])
    ).json()
    assert len(rows) == 1
    assert rows[0]["estado_revision"] == "aceptada"
    # La cola NO expone lat/lon exactas (gate #5).
    assert "lat" not in rows[0] and "lon" not in rows[0]

    # Filtro por estado_revision.
    rechazadas = client.get(
        "/api/v1/review/queue?estado_revision=rechazada",
        headers=auth_header(evaluador["token"]),
    ).json()
    assert rechazadas == []


def test_detail_includes_history(client, db_session):
    volunteer = register(client)
    obs_id = submit_observation(
        client, volunteer["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]
    evaluador = register(client, role="evaluador")
    client.post(
        f"/api/v1/review/observations/{obs_id}/verdict",
        headers=auth_header(evaluador["token"]),
        json={"veredicto": "rechazada", "nota": "borrosa"},
    )
    detail = client.get(
        f"/api/v1/review/observations/{obs_id}",
        headers=auth_header(evaluador["token"]),
    ).json()
    assert detail["estado_revision"] == "rechazada"
    assert len(detail["historial"]) == 1
    assert detail["historial"][0]["veredicto"] == "rechazada"
    assert detail["historial"][0]["nota"] == "borrosa"
    assert detail["historial"][0]["reviewer_handle"] == evaluador["handle"]
    # El detalle no expone coord exacta.
    assert "lat" not in detail and "lon" not in detail


def test_stats_counts_by_estado(client, db_session):
    volunteer = register(client)
    ids = [
        submit_observation(client, volunteer["token"], lat=21.88, lon=-102.29).json()[
            "observation_id"
        ]
        for _ in range(3)
    ]
    evaluador = register(client, role="evaluador")
    client.post(
        f"/api/v1/review/observations/{ids[0]}/verdict",
        headers=auth_header(evaluador["token"]),
        json={"veredicto": "rechazada"},
    )
    client.post(
        f"/api/v1/review/observations/{ids[1]}/verdict",
        headers=auth_header(evaluador["token"]),
        json={"veredicto": "confirmada"},
    )
    stats = client.get(
        "/api/v1/review/stats", headers=auth_header(evaluador["token"])
    ).json()
    assert stats["aceptadas"] == 1
    assert stats["confirmadas"] == 1
    assert stats["rechazadas"] == 1
    assert stats["total"] == 3
    assert stats["pendientes_de_revision"] == 1
    assert stats["revisiones_totales"] == 2


# --- AC4 (gate #5 BLOQUEANTE): saneo de EXIF GPS ---


def test_ac4_image_gps_stripped_for_evaluador(client, db_session):
    """La imagen servida a un evaluador NO debe llevar GPS en EXIF (gate #5)."""
    from backend.app.exif import has_gps

    volunteer = register(client)
    obs_id = submit_jpeg_with_gps(client, volunteer["token"])

    evaluador = register(client, role="evaluador")
    resp = client.get(
        f"/api/v1/review/observations/{obs_id}/image",
        headers=auth_header(evaluador["token"]),
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("image/")
    assert has_gps(resp.content) is False  # GPS eliminado


def test_ac4_image_gps_stripped_for_analista(client, db_session):
    from backend.app.exif import has_gps

    volunteer = register(client)
    obs_id = submit_jpeg_with_gps(client, volunteer["token"])

    analista = register(client, role="analista")
    resp = client.get(
        f"/api/v1/review/observations/{obs_id}/image",
        headers=auth_header(analista["token"]),
    )
    assert resp.status_code == 200
    assert has_gps(resp.content) is False


def test_ac4_image_keeps_gps_only_for_aliado_firmante(client, db_session):
    """Solo aliado_firmante recibe la imagen con GPS (gate #5)."""
    from backend.app.exif import has_gps

    # La imagen original lleva GPS.
    firmante = register(client, role="aliado_firmante")
    obs_id = submit_jpeg_with_gps(client, firmante["token"])
    resp = client.get(
        f"/api/v1/review/observations/{obs_id}/image",
        headers=auth_header(firmante["token"]),
    )
    assert resp.status_code == 200
    assert has_gps(resp.content) is True  # aliado_firmante SÍ ve el GPS


def test_original_image_actually_has_gps(client, db_session):
    """Sanidad: la imagen subida (en storage) sí lleva GPS — el saneo no es un falso positivo."""
    from backend.app.exif import has_gps
    from backend.app.storage import get_storage
    from sqlalchemy import text

    volunteer = register(client)
    obs_id = submit_jpeg_with_gps(client, volunteer["token"])
    key = db_session.execute(
        text("SELECT image_ref FROM observation WHERE id=:i"), {"i": obs_id}
    ).scalar_one()
    raw = get_storage().get(key)
    assert has_gps(raw) is True
