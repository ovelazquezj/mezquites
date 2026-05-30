"""Validación contra los esquemas JSON canónicos de ``schemas/``.

Los esquemas JSON son la fuente de verdad independiente de lenguaje. Usa la librería
``jsonschema`` si está disponible (camino preferido); si no, cae a un validador mínimo de
stdlib que cubre el subconjunto de restricciones que el contrato realmente usa
(``required``, ``type``, ``const``, ``enum``, ``minimum``/``maximum``, ``minLength``,
``additionalProperties: false``). Esto permite validar incluso en entornos sin la dependencia
opcional, manteniendo los esquemas como única fuente.
"""

from __future__ import annotations

import json
from functools import lru_cache
from importlib import resources
from typing import Any

_JOB_SCHEMA_FILE = "validation_job.schema.json"
_RESULT_SCHEMA_FILE = "validation_result.schema.json"


@lru_cache(maxsize=None)
def _load_schema(filename: str) -> dict:
    text = resources.files("mezquite_contract").joinpath("schemas", filename).read_text("utf-8")
    return json.loads(text)


def job_schema() -> dict:
    return _load_schema(_JOB_SCHEMA_FILE)


def result_schema() -> dict:
    return _load_schema(_RESULT_SCHEMA_FILE)


class SchemaValidationError(ValueError):
    """Un mensaje no cumple su esquema JSON."""


def validate_job(data: dict) -> None:
    """Valida un dict de job §6.2. Lanza :class:`SchemaValidationError` si es inválido."""
    _validate(data, job_schema())


def validate_result(data: dict) -> None:
    """Valida un dict de resultado §6.3. Lanza :class:`SchemaValidationError` si es inválido."""
    _validate(data, result_schema())


def _validate(data: Any, schema: dict) -> None:
    try:
        import jsonschema  # type: ignore
    except ModuleNotFoundError:
        _minimal_validate(data, schema, path="$")
        return
    try:
        jsonschema.validate(data, schema)
    except jsonschema.ValidationError as exc:  # pragma: no cover - mensaje de jsonschema
        raise SchemaValidationError(str(exc)) from exc


def _minimal_validate(data: Any, schema: dict, path: str) -> None:
    """Validador de respaldo (stdlib) para el subconjunto usado por el contrato."""
    expected = schema.get("type")
    if expected and not _type_ok(data, expected):
        raise SchemaValidationError(f"{path}: se esperaba tipo {expected!r}")

    if expected == "object":
        props: dict = schema.get("properties", {})
        for req in schema.get("required", []):
            if req not in data:
                raise SchemaValidationError(f"{path}: falta campo requerido {req!r}")
        if schema.get("additionalProperties") is False:
            extra = set(data) - set(props)
            if extra:
                raise SchemaValidationError(f"{path}: campos no permitidos {sorted(extra)!r}")
        for key, subschema in props.items():
            if key in data:
                _minimal_validate(data[key], subschema, f"{path}.{key}")
        return

    if "const" in schema and data != schema["const"]:
        raise SchemaValidationError(f"{path}: debe ser {schema['const']!r}")
    if "enum" in schema and data not in schema["enum"]:
        raise SchemaValidationError(f"{path}: debe estar en {schema['enum']!r}")
    if isinstance(data, (int, float)) and not isinstance(data, bool):
        if "minimum" in schema and data < schema["minimum"]:
            raise SchemaValidationError(f"{path}: < minimo {schema['minimum']}")
        if "maximum" in schema and data > schema["maximum"]:
            raise SchemaValidationError(f"{path}: > maximo {schema['maximum']}")
    if isinstance(data, str) and "minLength" in schema and len(data) < schema["minLength"]:
        raise SchemaValidationError(f"{path}: longitud < {schema['minLength']}")


def _type_ok(data: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(data, dict)
    if expected == "string":
        return isinstance(data, str)
    if expected == "boolean":
        return isinstance(data, bool)
    if expected == "number":
        return isinstance(data, (int, float)) and not isinstance(data, bool)
    if expected == "integer":
        return isinstance(data, int) and not isinstance(data, bool)
    return True
