"""CR-002 — Login social con MockAuthProvider (gate #2 acotado + gate #6).

AC1: POST /auth/google con el mock crea la cuenta `voluntario` (solo provider_subject, sin
email/nombre) y devuelve un JWT válido.
AC4 (parcial): persistencia sin PII de más en la cuenta del voluntario.
AC5: AUTH_PROVIDER=mock permite correr sin red.
"""

from __future__ import annotations

from backend.app import security
from backend.app.models import Account


def _google_login(client, token: str = "mock:alice", institution_id: str | None = None):
    body: dict = {"id_token": token}
    if institution_id:
        body["institution_id"] = institution_id
    return client.post("/api/v1/auth/google", json=body)


def test_ac1_google_login_creates_voluntario_and_returns_jwt(client, db_session):
    resp = _google_login(client, token="mock:alice")
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["role"] == "voluntario"
    assert data["handle"].startswith("obs-")
    # JWT válido y sin PII en el payload.
    payload = security.decode_token(data["token"])
    assert payload["role"] == "voluntario"
    for forbidden in ("email", "phone", "telefono", "name", "nombre"):
        assert forbidden not in payload


def test_ac1_google_login_persists_only_opaque_subject(client, db_session):
    _google_login(client, token="mock:bob")
    account = (
        db_session.query(Account).filter(Account.provider_subject == "bob").one_or_none()
    )
    assert account is not None
    assert account.auth_provider == "social_google"
    assert account.provider_subject == "bob"
    # Gate #2 acotado: el voluntario NO guarda PII.
    assert account.email is None
    assert account.username is None
    assert account.password_hash is None
    assert account.role == "voluntario"


def test_ac1_second_login_same_subject_reuses_account(client, db_session):
    first = _google_login(client, token="mock:carol").json()
    second = _google_login(client, token="mock:carol").json()
    assert first["handle"] == second["handle"]
    # Una sola cuenta para el mismo sub.
    count = db_session.query(Account).filter(Account.provider_subject == "carol").count()
    assert count == 1


def test_ac5_mock_provider_runs_offline_with_fixed_token(client, db_session):
    # El token fijo por defecto del mock funciona sin red ni Google.
    resp = _google_login(client, token="mock-google-id-token")
    assert resp.status_code == 200, resp.text
    assert resp.json()["role"] == "voluntario"


def test_google_login_rejects_invalid_token(client, db_session):
    resp = _google_login(client, token="no-soy-un-token-valido")
    assert resp.status_code == 401


def test_google_login_accepts_institution(client, db_session):
    from backend.app.models import Institution

    inst = Institution(name="Prepa Piloto", estado="Aguascalientes")
    db_session.add(inst)
    db_session.commit()
    db_session.refresh(inst)
    resp = _google_login(client, token="mock:dave", institution_id=str(inst.id))
    assert resp.status_code == 200, resp.text
    account = db_session.query(Account).filter(Account.provider_subject == "dave").one()
    assert str(account.institution_id) == str(inst.id)
