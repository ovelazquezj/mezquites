"""ARCO — Cancelación de cuenta (CR-006): eliminación + anonimización + auditoría + authz.

Gates verificados:
- #2: tras eliminar NO queda PII de la persona (la fila de account, con provider_subject/username/
  email, desaparece) y el handle de sus observaciones pasa a anónimo.
- #7: la eliminación queda auditada en account_deletion, sin PII (id opaco + quién + rol + motivo).
- authz: SOLO administrador puede eliminar (403 para el resto, 401 sin token).
- invariante: el dataset público sigue funcionando (la observación anonimizada sigue visible).
"""

from __future__ import annotations

import uuid

from sqlalchemy import text

from backend.app import db as db_module
from backend.app.models import (
    ANON_HANDLE,
    SENTINEL_ACCOUNT_ID,
    Account,
    AccountDeletion,
    Observation,
)

from .helpers import auth_header, register, submit_observation


def _admin_account_id(handle: str) -> uuid.UUID:
    s = db_module.get_sessionmaker()()
    try:
        return s.query(Account).filter(Account.handle == handle).one().id
    finally:
        s.close()


def test_delete_account_anonymizes_and_removes_identity(client, db_session):
    """AC1: el administrador elimina → identidad desaparece, observaciones anonimizadas y públicas."""
    admin = register(client, role="administrador")
    voluntario = register(client, role="voluntario")
    vol_handle = voluntario["handle"]
    vol_id = _admin_account_id(vol_handle)

    # El voluntario sube dos observaciones (nacen 'aceptada' ⇒ visibles, CR-001).
    submit_observation(client, voluntario["token"], lat=21.88, lon=-102.29)
    submit_observation(client, voluntario["token"], lat=21.90, lon=-102.30)

    pub_before = client.get("/api/v1/public/observations").json()
    assert len(pub_before) == 2

    resp = client.request(
        "DELETE",
        f"/api/v1/admin/accounts/{vol_id}",
        headers=auth_header(admin["token"]),
        json={"reason": "solicitud del titular (ARCO)"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["observations_anonymized"] == 2
    assert str(body["deleted_account_id"]) == str(vol_id)

    # Identidad eliminada: la fila de account ya no existe (gate #2).
    s = db_module.get_sessionmaker()()
    try:
        assert s.get(Account, vol_id) is None
        # Las observaciones se conservan, repuntadas al centinela y con handle anónimo.
        obs = s.query(Observation).all()
        assert len(obs) == 2
        for o in obs:
            assert o.account_id == SENTINEL_ACCOUNT_ID
            assert o.handle == ANON_HANDLE
            assert o.geom is not None  # dato ecológico intacto
    finally:
        s.close()

    # El dataset público SIGUE funcionando (invariante CR-006).
    pub_after = client.get("/api/v1/public/observations").json()
    assert len(pub_after) == 2
    assert {r["handle"] for r in pub_after} == {ANON_HANDLE}


def test_delete_account_audited_without_pii(client, db_session):
    """AC3 + gate #7: la cancelación queda auditada, sin PII (email/sub/username)."""
    admin = register(client, role="administrador")
    voluntario = register(client, role="voluntario")
    vol_id = _admin_account_id(voluntario["handle"])
    admin_id = _admin_account_id(admin["handle"])

    submit_observation(client, voluntario["token"], lat=21.88, lon=-102.29)
    client.request(
        "DELETE",
        f"/api/v1/admin/accounts/{vol_id}",
        headers=auth_header(admin["token"]),
        json={"reason": "limpieza"},
    )

    s = db_module.get_sessionmaker()()
    try:
        rows = s.query(AccountDeletion).all()
        assert len(rows) == 1
        rec = rows[0]
        assert rec.deleted_account_id == vol_id
        assert rec.executed_by_account_id == admin_id
        assert rec.deleted_role == "voluntario"
        assert rec.observations_anonymized == 1
        # Sin PII: el modelo de auditoría no tiene columnas de email/sub/username/nombre.
        cols = set(AccountDeletion.__table__.columns.keys())
        for forbidden in ("email", "provider_subject", "username", "name", "nombre"):
            assert forbidden not in cols
    finally:
        s.close()


def test_delete_account_requires_administrador(client, db_session):
    """AC2: un rol no-administrador recibe 403; sin token, 401."""
    voluntario = register(client, role="voluntario")
    evaluador = register(client, role="evaluador")
    admin_consorcio = register(client, role="admin_consorcio")
    target_id = _admin_account_id(voluntario["handle"])

    # Sin token → 401.
    assert client.delete(f"/api/v1/admin/accounts/{target_id}").status_code == 401

    # voluntario, evaluador y admin_consorcio → 403 (solo administrador puede).
    for actor in (voluntario, evaluador, admin_consorcio):
        resp = client.delete(
            f"/api/v1/admin/accounts/{target_id}", headers=auth_header(actor["token"])
        )
        assert resp.status_code == 403, actor["role"]

    # La cuenta sigue existiendo (no se borró nada).
    s = db_module.get_sessionmaker()()
    try:
        assert s.get(Account, target_id) is not None
    finally:
        s.close()


def test_delete_unknown_account_is_404(client, db_session):
    admin = register(client, role="administrador")
    resp = client.delete(
        f"/api/v1/admin/accounts/{uuid.uuid4()}", headers=auth_header(admin["token"])
    )
    assert resp.status_code == 404


def test_cannot_delete_sentinel_or_self(client, db_session):
    admin = register(client, role="administrador")
    admin_id = _admin_account_id(admin["handle"])

    # Centinela: 400.
    resp = client.delete(
        f"/api/v1/admin/accounts/{SENTINEL_ACCOUNT_ID}", headers=auth_header(admin["token"])
    )
    assert resp.status_code == 400

    # Propia cuenta: 400.
    resp = client.delete(
        f"/api/v1/admin/accounts/{admin_id}", headers=auth_header(admin["token"])
    )
    assert resp.status_code == 400


def test_search_accounts_admin_only_and_hides_pii(client, db_session):
    """GET /admin/accounts: solo administrador; nunca expone email (solo has_email)."""
    admin = register(client, role="administrador")
    register(client, role="voluntario")

    # Solo administrador.
    voluntario = register(client, role="voluntario")
    assert (
        client.get(
            "/api/v1/admin/accounts", headers=auth_header(voluntario["token"])
        ).status_code
        == 403
    )

    resp = client.get("/api/v1/admin/accounts", headers=auth_header(admin["token"]))
    assert resp.status_code == 200
    rows = resp.json()
    # El centinela no aparece; ninguna fila expone el email crudo.
    for r in rows:
        assert "email" not in r
        assert "has_email" in r
        assert str(SENTINEL_ACCOUNT_ID) != str(r["id"])


def test_delete_account_repoints_reviewer_and_points(client, db_session):
    """No se rompen FKs: si la cuenta era revisor o tenía puntos, se repuntan al centinela."""
    admin = register(client, role="administrador")
    evaluador = register(client, role="evaluador")
    voluntario = register(client, role="voluntario")
    vol_id = _admin_account_id(voluntario["handle"])
    eval_id = _admin_account_id(evaluador["handle"])

    obs_id = submit_observation(
        client, voluntario["token"], lat=21.88, lon=-102.29
    ).json()["observation_id"]

    # El evaluador emite un veredicto (crea fila en human_review con reviewer = evaluador).
    verdict = client.post(
        f"/api/v1/review/observations/{obs_id}/verdict",
        headers=auth_header(evaluador["token"]),
        json={"veredicto": "confirmada"},
    )
    assert verdict.status_code == 200, verdict.text

    # Eliminamos al evaluador (que es reviewer). No debe romper la FK de human_review.
    resp = client.delete(
        f"/api/v1/admin/accounts/{eval_id}", headers=auth_header(admin["token"])
    )
    assert resp.status_code == 200, resp.text

    s = db_module.get_sessionmaker()()
    try:
        assert s.get(Account, eval_id) is None
        # La revisión sobrevive, repuntada al centinela.
        reviewers = s.execute(
            text("SELECT reviewer_account_id FROM human_review")
        ).scalars().all()
        assert all(r == SENTINEL_ACCOUNT_ID for r in reviewers)
        # Los puntos del voluntario siguen existiendo (aún no se borró al voluntario).
        pts = s.execute(
            text("SELECT account_id FROM points_ledger WHERE account_id = :a"),
            {"a": vol_id},
        ).scalars().all()
        assert len(pts) >= 1
    finally:
        s.close()
