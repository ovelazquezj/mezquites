"""Auth sin PII (gate #2) y autoridad del veredicto (gate #9). Lógica pura, sin DB."""

from __future__ import annotations

import inspect
import uuid

from mezquite_contract.models import Scores, ValidationResult

from backend.app import schemas, security
from backend.app.models import Account
from backend.app.validation_apply import ApplyOutcome  # noqa: F401  (símbolo existe)


def test_backup_code_hash_roundtrip():
    code = security.generate_backup_code()
    hashed = security.hash_backup_code(code)
    assert hashed != code  # nunca se guarda en claro
    assert security.verify_backup_code(code, hashed)
    assert not security.verify_backup_code("MZQ-0000-0000", hashed)


def test_handle_and_backup_code_have_no_pii_shape():
    handle = security.generate_handle()
    code = security.generate_backup_code()
    assert handle.startswith("obs-")
    assert "@" not in handle and "@" not in code  # no parece email/PII


def test_token_payload_contains_no_pii():
    aid = uuid.uuid4()
    token = security.create_token(account_id=aid, handle="obs-ABC123", role="voluntario")
    payload = security.decode_token(token)
    assert payload["sub"] == str(aid)
    assert payload["role"] == "voluntario"
    # El payload NO contiene campos de PII.
    for forbidden in ("email", "phone", "telefono", "name", "nombre"):
        assert forbidden not in payload


def test_account_model_has_no_pii_columns():
    cols = set(Account.__table__.columns.keys())
    for forbidden in ("email", "phone", "telefono", "name", "nombre", "correo"):
        assert forbidden not in cols


def test_register_schema_has_no_pii_fields():
    fields = set(schemas.RegisterRequest.model_fields.keys())
    for forbidden in ("email", "phone", "telefono", "name", "nombre", "correo"):
        assert forbidden not in fields


def test_recover_uses_backup_code_not_pii():
    fields = set(schemas.RecoverRequest.model_fields.keys())
    assert fields == {"handle", "backup_code"}


def test_authoritative_verdict_ignores_message_field():
    """El backend recomputa el veredicto; un mensaje con veredicto mentiroso no manda (gate #9)."""
    # Productor con bug: dice 'valida' pero parasitos=False.
    r = ValidationResult(
        observation_id=uuid.uuid4(),
        es_arbol=True,
        parasitos_presentes=False,
        veredicto="valida",  # incoherente a propósito
        scores=Scores(arbol=0.9, parasitos=0.1),
        model_version="mock",
    )
    assert r.authoritative_verdict == "ruido"
    assert r.is_consistent is False


def test_apply_uses_authoritative_verdict_source():
    """Garantiza que apply_validation_result usa authoritative_verdict (no el campo del mensaje)."""
    from backend.app import validation_apply

    src = inspect.getsource(validation_apply.apply_validation_result)
    assert "authoritative_verdict" in src
    # Nunca debe asignar verdict = result.veredicto directamente.
    assert "result.veredicto" not in src.replace("result.veredicto,\n", "")
