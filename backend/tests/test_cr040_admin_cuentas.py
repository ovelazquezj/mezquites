"""CR-040 — Administración de cuentas desde la consola (buscar por username, ARCO completo, roles).

Qué cubre y por qué:

- **Buscar por ``username``**: el administrador no podía eliminar a un usuario de consola porque
  ``GET /admin/accounts`` solo miraba el ``handle``, que en esas cuentas es autogenerado
  (``obs-XXXXXX``) y nadie conoce. Sin fila no hay ``id``, y sin ``id`` no hay DELETE.
- **ARCO completo**: el borrado repuntaba observaciones/puntos/revisiones pero **olvidaba**
  ``participation_session`` (FK NOT NULL, sin ON DELETE) y ``problem_report``: cualquier cuenta con
  sesiones registradas —es decir, cualquier voluntario activo— reventaba con IntegrityError.
- **Cuenta de administrador principal protegida**: sin ella, un administrador podía eliminar o
  degradar al último administrador y dejar el sistema sin forma de crear otro desde la API.

Gates: #2 (las respuestas nunca traen ``email``, solo ``has_email``) y #7 (la auditoría de
``account_deletion`` se conserva; lo único que se anonimiza es *quién ejecutó*, cuya identidad
desaparece en esa misma operación).
"""

from __future__ import annotations

import uuid

import pytest
from sqlalchemy import text

from backend.app import db as db_module
from backend.app.bootstrap import ensure_admin
from backend.app.config import get_settings
from backend.app.models import ANON_HANDLE, SENTINEL_ACCOUNT_ID, Account

from .helpers import auth_header, register, submit_observation


@pytest.fixture()
def con_admin_protegido(monkeypatch):
    """Configura ``BOOTSTRAP_ADMIN_USERNAME`` en caliente.

    ``get_settings`` está memorizado con ``lru_cache``: cambiar la variable de entorno no basta, hay
    que invalidar la caché — antes de la prueba para que la app vea el valor nuevo, y después para
    que ninguna prueba posterior herede una cuenta protegida fantasma.
    """

    def _configurar(username: str) -> str:
        monkeypatch.setenv("BOOTSTRAP_ADMIN_USERNAME", username)
        get_settings.cache_clear()
        return username

    yield _configurar
    get_settings.cache_clear()


def _account_id(handle: str) -> uuid.UUID:
    s = db_module.get_sessionmaker()()
    try:
        return s.query(Account).filter(Account.handle == handle).one().id
    finally:
        s.close()


def _login(client, username: str, password: str) -> str:
    resp = client.post(
        "/api/v1/auth/login", json={"username": username, "password": password}
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["token"]


def _crear_usuario_consola(client, token: str, username: str, role: str, email=None) -> dict:
    body = {"username": username, "role": role}
    if email:
        body["email"] = email
    resp = client.post("/api/v1/admin/users", headers=auth_header(token), json=body)
    assert resp.status_code == 201, resp.text
    return resp.json()


# --- AC1: la búsqueda encuentra al usuario de consola por su nombre de usuario ------------------


def test_busqueda_por_username_encuentra_usuario_de_consola(client, db_session):
    """El caso que reportó el usuario: buscar 'eva' debe devolver a la evaluadora."""
    admin = register(client, role="administrador")
    creado = _crear_usuario_consola(client, admin["token"], "eva.rios", "evaluador")

    resp = client.get(
        "/api/v1/admin/accounts", params={"handle": "eva"}, headers=auth_header(admin["token"])
    )
    assert resp.status_code == 200, resp.text
    filas = resp.json()
    assert [f["id"] for f in filas] == [creado["id"]]
    fila = filas[0]
    assert fila["username"] == "eva.rios"          # la consola muestra por quién se le conoce
    assert fila["auth_provider"] == "password"
    assert fila["protected"] is False              # sin BOOTSTRAP_ADMIN_USERNAME no hay protegida
    assert "email" not in fila                     # gate #2: solo has_email
    assert fila["has_email"] is False


def test_busqueda_por_handle_sigue_funcionando(client, db_session):
    """No es un reemplazo: el handle (lo que el voluntario ve en la app) sigue buscando."""
    admin = register(client, role="administrador")
    voluntario = register(client, role="voluntario")
    fragmento = voluntario["handle"][-4:]  # trozo del sufijo: coincidencia parcial real

    resp = client.get(
        "/api/v1/admin/accounts",
        params={"handle": fragmento},
        headers=auth_header(admin["token"]),
    )
    assert resp.status_code == 200
    ids = [f["id"] for f in resp.json()]
    assert str(_account_id(voluntario["handle"])) in ids


def test_busqueda_acepta_el_alias_q(client, db_session):
    """`q` es alias de `handle`; con ambos gana el primero no vacío."""
    admin = register(client, role="administrador")
    creado = _crear_usuario_consola(client, admin["token"], "ana.lista", "analista")

    por_q = client.get(
        "/api/v1/admin/accounts", params={"q": "lista"}, headers=auth_header(admin["token"])
    )
    assert por_q.status_code == 200
    assert [f["id"] for f in por_q.json()] == [creado["id"]]

    # `handle` no vacío gana sobre `q`: el filtro es 'ana.lista', no 'nadie'.
    ambos = client.get(
        "/api/v1/admin/accounts",
        params={"handle": "ana.lista", "q": "nadie"},
        headers=auth_header(admin["token"]),
    )
    assert [f["id"] for f in ambos.json()] == [creado["id"]]

    # `handle` vacío ⇒ manda `q` (la consola manda cadenas vacías cuando el campo está en blanco).
    vacio = client.get(
        "/api/v1/admin/accounts",
        params={"handle": "", "q": "ana"},
        headers=auth_header(admin["token"]),
    )
    assert [f["id"] for f in vacio.json()] == [creado["id"]]


def test_busqueda_sin_coincidencia_devuelve_vacio(client, db_session):
    admin = register(client, role="administrador")
    _crear_usuario_consola(client, admin["token"], "eva.rios", "evaluador")
    resp = client.get(
        "/api/v1/admin/accounts", params={"q": "zzz-no-existe"}, headers=auth_header(admin["token"])
    )
    assert resp.status_code == 200
    assert resp.json() == []


# --- AC2: el borrado ARCO repunta TODAS las FKs -------------------------------------------------


def test_arco_repunta_las_seis_tablas(client, db_session):
    """Una cuenta con filas en las 6 tablas que apuntan a `account` se elimina sin romper FKs."""
    admin = register(client, role="administrador")
    objetivo = register(client, role="voluntario")
    otro = register(client, role="voluntario")
    objetivo_id = _account_id(objetivo["handle"])

    # observation + points_ledger (el submit acredita puntos al subir).
    submit_observation(client, objetivo["token"], lat=21.88, lon=-102.29)
    obs_ajena = submit_observation(client, otro["token"], lat=21.89, lon=-102.28).json()[
        "observation_id"
    ]

    # participation_session.
    sesion = client.post(
        "/api/v1/me/sessions",
        headers=auth_header(objetivo["token"]),
        json={
            "started_at": "2026-09-01T10:00:00+00:00",
            "ended_at": "2026-09-01T10:30:00+00:00",
        },
    )
    assert sesion.status_code == 201, sesion.text

    # problem_report (con sesión ⇒ queda atado a la cuenta y guarda su handle).
    reporte = client.post(
        "/api/v1/problem-reports",
        headers=auth_header(objetivo["token"]),
        json={"context": "camera", "message": "la cámara no abre"},
    )
    assert reporte.status_code == 201, reporte.text
    assert reporte.json()["handle"] == objetivo["handle"]

    # human_review como revisor: la cuenta pasa a evaluadora (el rol autoritativo es el de la DB)
    # y emite un veredicto sobre la observación de otro voluntario.
    db_session.execute(
        text("UPDATE account SET role = 'evaluador' WHERE id = :id"), {"id": objetivo_id}
    )
    db_session.commit()
    veredicto = client.post(
        f"/api/v1/review/observations/{obs_ajena}/verdict",
        headers=auth_header(objetivo["token"]),
        json={"veredicto": "confirmada"},
    )
    assert veredicto.status_code == 200, veredicto.text

    resp = client.request(
        "DELETE",
        f"/api/v1/admin/accounts/{objetivo_id}",
        headers=auth_header(admin["token"]),
        json={"reason": "solicitud del titular (ARCO)"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["observations_anonymized"] == 1

    s = db_module.get_sessionmaker()()
    try:
        # La identidad desapareció (gate #2).
        assert s.get(Account, objetivo_id) is None

        def _uno(sql: str):
            return s.execute(text(sql), {"id": objetivo_id}).scalars().all()

        # Nada quedó apuntando a la cuenta borrada...
        assert _uno("SELECT id FROM observation WHERE account_id = :id") == []
        assert _uno("SELECT id FROM points_ledger WHERE account_id = :id") == []
        assert _uno("SELECT id FROM human_review WHERE reviewer_account_id = :id") == []
        assert _uno("SELECT id FROM participation_session WHERE account_id = :id") == []
        assert _uno("SELECT id FROM problem_report WHERE account_id = :id") == []

        # ...y el dato sobrevive, repuntado al centinela.
        obs = s.execute(
            text("SELECT account_id, handle FROM observation WHERE handle = :h"),
            {"h": ANON_HANDLE},
        ).all()
        assert len(obs) == 1 and obs[0][0] == SENTINEL_ACCOUNT_ID

        puntos = s.execute(
            text("SELECT count(*) FROM points_ledger WHERE account_id = :s"),
            {"s": SENTINEL_ACCOUNT_ID},
        ).scalar()
        assert puntos >= 1

        revisiones = s.execute(
            text("SELECT reviewer_account_id FROM human_review")
        ).scalars().all()
        assert revisiones and all(r == SENTINEL_ACCOUNT_ID for r in revisiones)

        sesiones = s.execute(
            text("SELECT account_id, duration_seconds FROM participation_session")
        ).all()
        assert len(sesiones) == 1
        assert sesiones[0][0] == SENTINEL_ACCOUNT_ID
        assert sesiones[0][1] == 1800  # la evidencia de participación no se pierde

        reportes = s.execute(
            text("SELECT account_id, handle, message FROM problem_report")
        ).all()
        assert len(reportes) == 1
        assert reportes[0][0] == SENTINEL_ACCOUNT_ID
        assert reportes[0][1] == ANON_HANDLE          # el seudónimo también se anonimiza
        assert reportes[0][2] == "la cámara no abre"  # el diagnóstico se conserva

        # Auditoría (gate #7).
        auditoria = s.execute(
            text(
                "SELECT deleted_account_id, deleted_role, reason, observations_anonymized "
                "FROM account_deletion"
            )
        ).all()
        assert len(auditoria) == 1
        assert auditoria[0][0] == objetivo_id
        assert auditoria[0][1] == "evaluador"
        assert auditoria[0][2] == "solicitud del titular (ARCO)"
        assert auditoria[0][3] == 1
    finally:
        s.close()


def test_arco_de_un_administrador_sobre_otro_administrador(client, db_session):
    """Borrar usuarios de consola pasa por ARCO: un admin puede eliminar a otro (no protegido)."""
    admin1 = register(client, role="administrador")
    creado = _crear_usuario_consola(
        client, admin1["token"], "admin2", "administrador", email="admin2@org.mx"
    )
    admin2_id = uuid.UUID(creado["id"])
    token2 = _login(client, "admin2", creado["temp_password"])

    # admin2 ejecuta primero una cancelación: deja una fila de auditoría con executed_by = admin2.
    victima = register(client, role="voluntario")
    victima_id = _account_id(victima["handle"])
    previa = client.request(
        "DELETE",
        f"/api/v1/admin/accounts/{victima_id}",
        headers=auth_header(token2),
        json={"reason": "baja del piloto"},
    )
    assert previa.status_code == 200, previa.text

    # Ahora admin1 elimina a admin2. La FK account_deletion.executed_by_account_id NO debe romper.
    resp = client.request(
        "DELETE",
        f"/api/v1/admin/accounts/{admin2_id}",
        headers=auth_header(admin1["token"]),
        json={"reason": "salió del proyecto"},
    )
    assert resp.status_code == 200, resp.text

    s = db_module.get_sessionmaker()()
    try:
        assert s.get(Account, admin2_id) is None
        filas = s.execute(
            text(
                "SELECT deleted_account_id, executed_by_account_id, deleted_role "
                "FROM account_deletion ORDER BY created_at"
            )
        ).all()
        # Las DOS auditorías siguen ahí (gate #7): lo eliminado nunca se borra del log.
        assert {f[0] for f in filas} == {victima_id, admin2_id}
        por_eliminado = {f[0]: f for f in filas}
        # La que ejecutó admin2 quedó anonimizada (su identidad ya no existe)...
        assert por_eliminado[victima_id][1] == SENTINEL_ACCOUNT_ID
        # ...y la nueva conserva a admin1, que sigue existiendo.
        assert por_eliminado[admin2_id][1] == _account_id(admin1["handle"])
        assert por_eliminado[admin2_id][2] == "administrador"
    finally:
        s.close()


# --- AC3: la cuenta de administrador principal está protegida -----------------------------------


def test_arco_rechaza_la_cuenta_protegida(client, db_session, con_admin_protegido):
    con_admin_protegido("admin")
    principal, _ = ensure_admin(db_session, username="admin", password="Adm1n-Pass")
    principal_id = principal.id
    otro_admin = register(client, role="administrador")

    resp = client.request(
        "DELETE",
        f"/api/v1/admin/accounts/{principal_id}",
        headers=auth_header(otro_admin["token"]),
        json={"reason": "prueba"},
    )
    assert resp.status_code == 400, resp.text
    assert resp.json()["detail"] == "la cuenta de administrador principal no se puede eliminar"

    s = db_module.get_sessionmaker()()
    try:
        assert s.get(Account, principal_id) is not None  # sigue viva
        assert s.execute(text("SELECT count(*) FROM account_deletion")).scalar() == 0
    finally:
        s.close()


def test_la_busqueda_marca_solo_a_la_cuenta_protegida(client, db_session, con_admin_protegido):
    con_admin_protegido("admin")
    principal, _ = ensure_admin(db_session, username="admin", password="Adm1n-Pass")
    admin_actor = register(client, role="administrador")
    _crear_usuario_consola(client, admin_actor["token"], "eva.rios", "evaluador")

    resp = client.get("/api/v1/admin/accounts", headers=auth_header(admin_actor["token"]))
    assert resp.status_code == 200
    protegidas = {f["id"]: f["protected"] for f in resp.json()}
    assert protegidas[str(principal.id)] is True
    assert sum(1 for v in protegidas.values() if v) == 1


def test_sin_bootstrap_admin_username_ninguna_cuenta_es_protegida(client, db_session):
    """No se inventa una cuenta protegida: si la config no la nombra, ARCO no bloquea a nadie."""
    ensure_admin(db_session, username="admin", password="Adm1n-Pass")
    actor = register(client, role="administrador")
    principal_id = db_session.query(Account).filter(Account.username == "admin").one().id

    resp = client.request(
        "DELETE",
        f"/api/v1/admin/accounts/{principal_id}",
        headers=auth_header(actor["token"]),
        json={"reason": "sin protección configurada"},
    )
    assert resp.status_code == 200, resp.text


# --- AC4: cambio de rol con frenos --------------------------------------------------------------


def test_patch_no_permite_cambiar_el_propio_rol(client, db_session):
    ensure_admin(db_session, username="admin", password="Adm1n-Pass")
    token = _login(client, "admin", "Adm1n-Pass")
    yo = db_session.query(Account).filter(Account.username == "admin").one().id

    resp = client.patch(
        f"/api/v1/admin/users/{yo}", headers=auth_header(token), json={"role": "analista"}
    )
    assert resp.status_code == 400, resp.text
    assert resp.json()["detail"] == "no puedes cambiar tu propio rol"

    db_session.expire_all()
    assert db_session.get(Account, yo).role == "administrador"


def test_patch_no_permite_cambiar_el_rol_de_la_protegida(client, db_session, con_admin_protegido):
    con_admin_protegido("admin")
    principal, _ = ensure_admin(db_session, username="admin", password="Adm1n-Pass")
    principal_id = principal.id
    token = _login(client, "admin", "Adm1n-Pass")
    # Un segundo administrador (de consola) intenta degradar al principal.
    creado = _crear_usuario_consola(client, token, "admin2", "administrador")
    token2 = _login(client, "admin2", creado["temp_password"])

    resp = client.patch(
        f"/api/v1/admin/users/{principal_id}",
        headers=auth_header(token2),
        json={"role": "analista"},
    )
    assert resp.status_code == 400, resp.text
    assert resp.json()["detail"] == "la cuenta de administrador principal no cambia de rol"

    db_session.expire_all()
    assert db_session.get(Account, principal_id).role == "administrador"


def test_patch_de_otro_usuario_cambia_el_rol_y_limpia_el_email(client, db_session):
    """Bajar de administrador a analista limpia el email (gate #2 acotado) y responde 200."""
    ensure_admin(db_session, username="admin", password="Adm1n-Pass")
    token = _login(client, "admin", "Adm1n-Pass")
    creado = _crear_usuario_consola(
        client, token, "admin3", "administrador", email="admin3@org.mx"
    )
    assert creado["has_email"] is True

    resp = client.patch(
        f"/api/v1/admin/users/{creado['id']}",
        headers=auth_header(token),
        json={"role": "analista"},
    )
    assert resp.status_code == 200, resp.text
    cuerpo = resp.json()
    assert cuerpo["role"] == "analista"
    assert cuerpo["has_email"] is False
    assert cuerpo["protected"] is False
    assert "email" not in cuerpo  # gate #2

    db_session.expire_all()
    cuenta = db_session.query(Account).filter(Account.username == "admin3").one()
    assert cuenta.role == "analista"
    assert cuenta.email is None


def test_lista_de_usuarios_marca_protected_solo_en_la_principal(
    client, db_session, con_admin_protegido
):
    con_admin_protegido("admin")
    principal, _ = ensure_admin(db_session, username="admin", password="Adm1n-Pass")
    token = _login(client, "admin", "Adm1n-Pass")
    _crear_usuario_consola(client, token, "eva.rios", "evaluador")
    _crear_usuario_consola(client, token, "ana.lista", "analista")

    resp = client.get("/api/v1/admin/users", headers=auth_header(token))
    assert resp.status_code == 200, resp.text
    filas = resp.json()
    assert len(filas) == 3
    por_id = {f["id"]: f for f in filas}
    assert por_id[str(principal.id)]["protected"] is True
    assert [f["username"] for f in filas if f["protected"]] == ["admin"]
    for f in filas:
        assert "email" not in f  # gate #2
