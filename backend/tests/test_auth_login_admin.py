"""CR-002 — Login usuario/contraseña + gestión de usuarios por el administrador.

AC2: POST /auth/login valida usuario/contraseña (hash) y rechaza credenciales malas.
AC3: el administrador crea un evaluador (sin email) y un segundo administrador (con email);
     POST /auth/register YA NO acepta `role` (cierra el hueco del gate #5).
"""

from __future__ import annotations

from backend.app.bootstrap import ensure_admin
from backend.app.models import Account

from .helpers import auth_header


def _bootstrap_admin(db_session, username="admin", password="Adm1n-Pass", email=None):
    account, _ = ensure_admin(db_session, username=username, password=password, email=email)
    return account


def _login(client, username, password):
    return client.post(
        "/api/v1/auth/login", json={"username": username, "password": password}
    )


# --- AC2: login usuario/contraseña ---


def test_ac2_login_ok_with_valid_credentials(client, db_session):
    _bootstrap_admin(db_session, username="admin", password="Adm1n-Pass")
    resp = _login(client, "admin", "Adm1n-Pass")
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["role"] == "administrador"
    assert data["token"]


def test_ac2_login_rejects_bad_password(client, db_session):
    _bootstrap_admin(db_session, username="admin", password="Adm1n-Pass")
    resp = _login(client, "admin", "incorrecta")
    assert resp.status_code == 401


def test_ac2_login_rejects_unknown_user(client, db_session):
    resp = _login(client, "fantasma", "x")
    assert resp.status_code == 401


# --- AC3: gestión de usuarios por el administrador ---


def test_ac3_admin_creates_evaluador_without_email(client, db_session):
    _bootstrap_admin(db_session, username="admin", password="Adm1n-Pass")
    token = _login(client, "admin", "Adm1n-Pass").json()["token"]
    resp = client.post(
        "/api/v1/admin/users",
        headers=auth_header(token),
        json={"username": "eva", "role": "evaluador"},
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["role"] == "evaluador"
    assert data["has_email"] is False
    assert data["must_change_password"] is True
    assert data["temp_password"]
    # El evaluador puede iniciar sesión con su contraseña temporal.
    login = _login(client, "eva", data["temp_password"])
    assert login.status_code == 200
    assert login.json()["must_change_password"] is True


def test_ac3_admin_creates_second_admin_with_email(client, db_session):
    _bootstrap_admin(db_session, username="admin", password="Adm1n-Pass")
    token = _login(client, "admin", "Adm1n-Pass").json()["token"]
    resp = client.post(
        "/api/v1/admin/users",
        headers=auth_header(token),
        json={"username": "admin2", "role": "administrador", "email": "admin2@org.mx"},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["has_email"] is True
    # Verifica en DB que el email se guardó (solo administrador puede).
    account = db_session.query(Account).filter(Account.username == "admin2").one()
    assert account.email == "admin2@org.mx"


def test_ac3_evaluador_with_email_is_rejected(client, db_session):
    """Gate #2 acotado: evaluador/analista NO pueden tener email."""
    _bootstrap_admin(db_session, username="admin", password="Adm1n-Pass")
    token = _login(client, "admin", "Adm1n-Pass").json()["token"]
    resp = client.post(
        "/api/v1/admin/users",
        headers=auth_header(token),
        json={"username": "eva", "role": "evaluador", "email": "eva@org.mx"},
    )
    assert resp.status_code == 400


def test_ac3_non_admin_cannot_create_users(client, db_session):
    """Un voluntario (token social) no puede gestionar usuarios."""
    from .helpers import register

    vol = register(client)  # voluntario
    resp = client.post(
        "/api/v1/admin/users",
        headers=auth_header(vol["token"]),
        json={"username": "x", "role": "evaluador"},
    )
    assert resp.status_code == 403


def test_ac3_register_no_longer_accepts_role(client, db_session):
    """POST /auth/register IGNORA `role`: siempre crea voluntario (cierra el hueco del gate #5)."""
    resp = client.post("/api/v1/auth/register", json={"role": "administrador"})
    assert resp.status_code == 201, resp.text
    assert resp.json()["role"] == "voluntario"
    # Y en la DB la cuenta es voluntario.
    handle = resp.json()["handle"]
    account = db_session.query(Account).filter(Account.handle == handle).one()
    assert account.role == "voluntario"


def test_admin_reset_user_issues_new_temp_password(client, db_session):
    _bootstrap_admin(db_session, username="admin", password="Adm1n-Pass")
    token = _login(client, "admin", "Adm1n-Pass").json()["token"]
    created = client.post(
        "/api/v1/admin/users",
        headers=auth_header(token),
        json={"username": "ana", "role": "analista"},
    ).json()
    user_id = created["id"]
    reset = client.post(
        f"/api/v1/admin/users/{user_id}/reset", headers=auth_header(token)
    )
    assert reset.status_code == 200, reset.text
    new_temp = reset.json()["temp_password"]
    assert new_temp and new_temp != created["temp_password"]
    # La nueva contraseña sirve; la vieja ya no.
    assert _login(client, "ana", new_temp).status_code == 200
    assert _login(client, "ana", created["temp_password"]).status_code == 401


def test_admin_patch_user_role(client, db_session):
    _bootstrap_admin(db_session, username="admin", password="Adm1n-Pass")
    token = _login(client, "admin", "Adm1n-Pass").json()["token"]
    created = client.post(
        "/api/v1/admin/users",
        headers=auth_header(token),
        json={"username": "user1", "role": "analista"},
    ).json()
    resp = client.patch(
        f"/api/v1/admin/users/{created['id']}",
        headers=auth_header(token),
        json={"role": "evaluador"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["role"] == "evaluador"


def test_password_reset_degrades_without_smtp(client, db_session):
    """Sin SMTP configurado, el reset por correo degrada a delivered=False (no rompe)."""
    _bootstrap_admin(
        db_session, username="admin", password="Adm1n-Pass", email="admin@org.mx"
    )
    resp = client.post("/api/v1/auth/password-reset", json={"username": "admin"})
    assert resp.status_code == 200, resp.text
    assert resp.json()["delivered"] is False


def test_password_reset_unknown_user_is_generic(client, db_session):
    resp = client.post("/api/v1/auth/password-reset", json={"username": "nadie"})
    assert resp.status_code == 200
    assert resp.json()["delivered"] is False


def test_bootstrap_is_idempotent(client, db_session):
    a1, created1 = ensure_admin(db_session, username="boot", password="P1")
    a2, created2 = ensure_admin(db_session, username="boot", password="P2-distinta")
    assert created1 is True and created2 is False
    assert a1.id == a2.id
