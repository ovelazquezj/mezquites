"""Modelos §6.2 / §6.3: construcción, round-trip y autoridad del veredicto."""

import uuid
from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from mezquite_contract.models import Scores, ValidationJob, ValidationResult


def _job_kwargs():
    return dict(
        observation_id=uuid.uuid4(),
        image_ref="obs/2026/abc.jpg",
        captured_at=datetime(2026, 5, 30, 12, 0, tzinfo=timezone.utc),
        lat=21.88,
        lon=-102.29,
    )


def test_job_roundtrip():
    job = ValidationJob(**_job_kwargs())
    msg = job.to_message()
    assert isinstance(msg["observation_id"], str)  # uuid serializado
    assert msg["schema_version"] == "1.0"
    again = ValidationJob.from_message(msg)
    assert again.observation_id == job.observation_id


def test_job_rechaza_campo_extra():
    with pytest.raises(ValidationError):
        ValidationJob(**_job_kwargs(), especie="mezquite")  # no existe en el contrato


def test_job_rechaza_lat_fuera_de_rango():
    kw = _job_kwargs()
    kw["lat"] = 120.0
    with pytest.raises(ValidationError):
        ValidationJob(**kw)


def test_result_build_deriva_veredicto():
    r = ValidationResult.build(
        observation_id=uuid.uuid4(),
        es_arbol=True,
        parasitos_presentes=True,
        scores=Scores(arbol=0.97, parasitos=0.81),
        model_version="mock",
    )
    assert r.veredicto == "valida"
    assert r.authoritative_verdict == "valida"
    assert r.is_consistent


def test_result_ruido_si_falta_parasito():
    r = ValidationResult.build(
        observation_id=uuid.uuid4(),
        es_arbol=True,
        parasitos_presentes=False,
        scores=Scores(arbol=0.9, parasitos=0.1),
        model_version="mock",
    )
    assert r.veredicto == "ruido"
    assert r.authoritative_verdict == "ruido"


def test_backend_detecta_veredicto_incoherente():
    # Un productor con bug envia 'valida' aunque no haya parasitos. El backend lo detecta.
    r = ValidationResult(
        observation_id=uuid.uuid4(),
        es_arbol=True,
        parasitos_presentes=False,
        veredicto="valida",  # incoherente a proposito
        scores=Scores(arbol=0.9, parasitos=0.1),
        model_version="mock",
    )
    assert r.is_consistent is False
    assert r.authoritative_verdict == "ruido"  # el backend manda


def test_result_rechaza_veredicto_invalido():
    with pytest.raises(ValidationError):
        ValidationResult(
            observation_id=uuid.uuid4(),
            es_arbol=True,
            parasitos_presentes=True,
            veredicto="quiza",  # fuera del enum
            scores=Scores(arbol=1.0, parasitos=1.0),
            model_version="mock",
        )
