"""Los mensajes generados por los modelos validan contra los esquemas JSON canonicos.

Gate de alcance (#8): los esquemas RECHAZAN campos de especie o nivel G4 porque la validacion
automatica se limita a es-arbol + presencia-de-parasitos (Q5.A-D1).
"""

import uuid
from datetime import datetime, timezone

import pytest

from mezquite_contract.models import Scores, ValidationJob, ValidationResult
from mezquite_contract.validation import (
    SchemaValidationError,
    validate_job,
    validate_result,
)


def _job_msg():
    return ValidationJob(
        observation_id=uuid.uuid4(),
        image_ref="obs/x.jpg",
        captured_at=datetime(2026, 5, 30, tzinfo=timezone.utc),
        lat=21.88,
        lon=-102.29,
    ).to_message()


def _result_msg():
    return ValidationResult.build(
        observation_id=uuid.uuid4(),
        es_arbol=True,
        parasitos_presentes=True,
        scores=Scores(arbol=0.97, parasitos=0.8),
        model_version="mock",
    ).to_message()


def test_job_valido_pasa_el_esquema():
    validate_job(_job_msg())


def test_result_valido_pasa_el_esquema():
    validate_result(_result_msg())


def test_job_sin_campo_requerido_falla():
    msg = _job_msg()
    del msg["lat"]
    with pytest.raises(SchemaValidationError):
        validate_job(msg)


def test_result_con_campo_especie_es_rechazado():
    # additionalProperties:false ⇒ la validacion automatica NO admite especie. Gate #8.
    msg = _result_msg()
    msg["especie"] = "mezquite"
    with pytest.raises(SchemaValidationError):
        validate_result(msg)


def test_result_con_nivel_g4_es_rechazado():
    # El nivel ordinal G4 es autodeclarado, nunca validado automaticamente. Gate #8.
    msg = _result_msg()
    msg["nivel_g4"] = "severo"
    with pytest.raises(SchemaValidationError):
        validate_result(msg)


def test_schema_version_incorrecta_falla():
    msg = _job_msg()
    msg["schema_version"] = "2.0"
    with pytest.raises(SchemaValidationError):
        validate_job(msg)
