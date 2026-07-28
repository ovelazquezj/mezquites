"""CR-029: veredicto idempotente + métricas comparables + edición de instituciones.

Origen: el Monitor mostraba 58 observaciones y 61 "Revisiones registradas". El contador era honesto
(cuenta EVENTOS del log append-only), pero 3 de esos eventos eran **el mismo veredicto grabado otra
vez** sobre dos observaciones — nada impedía volver a confirmar algo ya confirmado.
"""

from __future__ import annotations

from sqlalchemy import text

from .helpers import auth_header, register, submit_observation


def _observacion(client) -> tuple[str, dict]:
    """Sube una observación y devuelve (observation_id, credenciales del evaluador)."""
    vol = register(client)
    obs_id = submit_observation(client, vol["token"], lat=21.88, lon=-102.29).json()[
        "observation_id"
    ]
    return obs_id, register(client, role="evaluador")


def _verdict(client, evaluador, obs_id, veredicto, nota=None):
    return client.post(
        f"/api/v1/review/observations/{obs_id}/verdict",
        headers=auth_header(evaluador["token"]),
        json={"veredicto": veredicto, **({"nota": nota} if nota else {})},
    )


def _filas_log(db_session, obs_id) -> int:
    return db_session.execute(
        text("SELECT count(*) FROM human_review WHERE observation_id = :o"), {"o": obs_id}
    ).scalar_one()


# --- 1. Veredicto idempotente (el bug del contador) ---


def test_repetir_el_mismo_veredicto_no_escribe_en_el_log(client, db_session):
    """El caso exacto de producción: `confirmada → confirmada → confirmada` dejaba 3 filas."""
    obs_id, evaluador = _observacion(client)

    r1 = _verdict(client, evaluador, obs_id, "confirmada")
    assert r1.status_code == 200, r1.text
    assert r1.json()["sin_cambio"] is False

    for _ in range(2):
        r = _verdict(client, evaluador, obs_id, "confirmada")
        assert r.status_code == 200, r.text
        assert r.json()["sin_cambio"] is True
        assert r.json()["estado_revision"] == "confirmada"

    # Una sola fila en el log pese a los tres envíos.
    assert _filas_log(db_session, obs_id) == 1


def test_un_cambio_real_de_veredicto_si_se_registra(client, db_session):
    """La idempotencia no puede tragarse una revisión legítima."""
    obs_id, evaluador = _observacion(client)
    _verdict(client, evaluador, obs_id, "confirmada")
    r = _verdict(client, evaluador, obs_id, "rechazada")
    assert r.json()["sin_cambio"] is False
    r = _verdict(client, evaluador, obs_id, "confirmada")
    assert r.json()["sin_cambio"] is False
    assert _filas_log(db_session, obs_id) == 3


def test_el_no_op_no_altera_el_estado_ni_el_historial(client, db_session):
    obs_id, evaluador = _observacion(client)
    _verdict(client, evaluador, obs_id, "rechazada", nota="borrosa")
    _verdict(client, evaluador, obs_id, "rechazada", nota="otra nota")

    detail = client.get(
        f"/api/v1/review/observations/{obs_id}",
        headers=auth_header(evaluador["token"]),
    ).json()
    assert detail["estado_revision"] == "rechazada"
    assert len(detail["historial"]) == 1
    assert detail["historial"][0]["nota"] == "borrosa"


def test_repetir_aceptada_sobre_una_recien_subida_tampoco_escribe(client, db_session):
    """Una observación nace `aceptada`: emitir `aceptada` no cambia nada."""
    obs_id, evaluador = _observacion(client)
    r = _verdict(client, evaluador, obs_id, "aceptada")
    assert r.json()["sin_cambio"] is True
    assert _filas_log(db_session, obs_id) == 0


# --- 2. Métricas comparables en el Monitor ---


def test_stats_distingue_observaciones_revisadas_de_veredictos_emitidos(client, db_session):
    obs_id, evaluador = _observacion(client)
    otra_id, _ = _observacion(client)

    _verdict(client, evaluador, obs_id, "confirmada")
    _verdict(client, evaluador, obs_id, "rechazada")  # re-revisión legítima
    _verdict(client, evaluador, otra_id, "confirmada")

    stats = client.get(
        "/api/v1/review/stats", headers=auth_header(evaluador["token"])
    ).json()
    assert stats["observaciones_revisadas"] == 2  # observaciones distintas
    assert stats["revisiones_totales"] == 3  # eventos
    assert stats["total"] == 2


def test_sin_revisiones_ambos_contadores_son_cero(client, db_session):
    _, evaluador = _observacion(client)
    stats = client.get(
        "/api/v1/review/stats", headers=auth_header(evaluador["token"])
    ).json()
    assert stats["observaciones_revisadas"] == 0
    assert stats["revisiones_totales"] == 0


# --- 3. Edición de instituciones ---


def _crear_institucion(client, admin, name, estado=None):
    return client.post(
        "/api/v1/admin/institutions",
        headers=auth_header(admin["token"]),
        json={"name": name, **({"estado": estado} if estado else {})},
    ).json()


def test_editar_nombre_y_estado(client, db_session):
    admin = register(client, role="administrador")
    inst = _crear_institucion(client, admin, "Prepa Mal Escrita")

    r = client.patch(
        f"/api/v1/admin/institutions/{inst['id']}",
        headers=auth_header(admin["token"]),
        json={"name": "Preparatoria Bien Escrita", "estado": "Aguascalientes"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["name"] == "Preparatoria Bien Escrita"
    assert r.json()["estado"] == "Aguascalientes"


def test_editar_no_cambia_el_status(client, db_session):
    """Decisión del usuario: la edición NO degrada una aprobada."""
    admin = register(client, role="administrador")
    inst = _crear_institucion(client, admin, "Aprobada Intocable")
    assert inst["status"] == "aprobada"

    r = client.patch(
        f"/api/v1/admin/institutions/{inst['id']}",
        headers=auth_header(admin["token"]),
        json={"name": "Aprobada Intocable 2", "status": "solicitada"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "aprobada"


def test_renombrar_a_un_nombre_de_otra_es_409(client, db_session):
    admin = register(client, role="administrador")
    _crear_institucion(client, admin, "Universidad Alfa")
    beta = _crear_institucion(client, admin, "Universidad Beta")

    r = client.patch(
        f"/api/v1/admin/institutions/{beta['id']}",
        headers=auth_header(admin["token"]),
        json={"name": "universidad alfa"},  # misma canónica que Alfa
    )
    assert r.status_code == 409, r.text
    assert "Universidad Alfa" in r.json()["detail"]


def test_corregir_la_escritura_de_la_propia_institucion_si_se_permite(client, db_session):
    """El choque se evalúa EXCLUYENDO la propia fila: arreglar acentos/mayúsculas es legítimo."""
    admin = register(client, role="administrador")
    inst = _crear_institucion(client, admin, "universidad cuauhtemoc")

    r = client.patch(
        f"/api/v1/admin/institutions/{inst['id']}",
        headers=auth_header(admin["token"]),
        json={"name": "Universidad Cuauhtémoc"},  # mismo nombre canónico
    )
    assert r.status_code == 200, r.text
    assert r.json()["name"] == "Universidad Cuauhtémoc"


def test_editar_solo_el_estado_conserva_el_nombre(client, db_session):
    admin = register(client, role="administrador")
    inst = _crear_institucion(client, admin, "Solo Estado AC", estado="Jalisco")

    r = client.patch(
        f"/api/v1/admin/institutions/{inst['id']}",
        headers=auth_header(admin["token"]),
        json={"estado": "Aguascalientes"},
    )
    assert r.status_code == 200, r.text
    assert r.json()["name"] == "Solo Estado AC"
    assert r.json()["estado"] == "Aguascalientes"


def test_estado_vacio_lo_limpia(client, db_session):
    admin = register(client, role="administrador")
    inst = _crear_institucion(client, admin, "Limpiar Estado AC", estado="Jalisco")

    r = client.patch(
        f"/api/v1/admin/institutions/{inst['id']}",
        headers=auth_header(admin["token"]),
        json={"estado": "   "},
    )
    assert r.status_code == 200, r.text
    assert r.json()["estado"] is None


def test_editar_con_nombre_vacio_es_422(client, db_session):
    admin = register(client, role="administrador")
    inst = _crear_institucion(client, admin, "No Vaciar AC")
    r = client.patch(
        f"/api/v1/admin/institutions/{inst['id']}",
        headers=auth_header(admin["token"]),
        json={"name": "   "},
    )
    assert r.status_code == 422, r.text


def test_editar_una_inexistente_es_404(client, db_session):
    admin = register(client, role="administrador")
    r = client.patch(
        "/api/v1/admin/institutions/00000000-0000-0000-0000-000000000000",
        headers=auth_header(admin["token"]),
        json={"name": "Fantasma"},
    )
    assert r.status_code == 404


def test_editar_exige_rol_de_admin(client, db_session):
    admin = register(client, role="administrador")
    inst = _crear_institucion(client, admin, "Protegida AC")
    vol = register(client)
    r = client.patch(
        f"/api/v1/admin/institutions/{inst['id']}",
        headers=auth_header(vol["token"]),
        json={"name": "Secuestrada"},
    )
    assert r.status_code == 403
