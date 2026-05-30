"""Modelos tipados de la frontera §6.2 / §6.3 (pydantic v2).

Estos modelos son la forma ergonómica de construir y validar los mensajes; los esquemas JSON
de ``schemas/`` son la forma canónica, independiente de lenguaje. Ambos describen lo mismo y
están cubiertos por ``tests/test_schema.py`` (un mensaje generado por estos modelos valida
contra el esquema JSON).
"""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from .verdict import compute_verdict
from .version import SCHEMA_VERSION

_Veredicto = Literal["valida", "ruido"]


class ValidationJob(BaseModel):
    """Job de validación (backend → validador). §6.2."""

    model_config = ConfigDict(extra="forbid")

    observation_id: uuid.UUID
    image_ref: str = Field(min_length=1)
    captured_at: datetime
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    schema_version: Literal["1.0"] = SCHEMA_VERSION

    def to_message(self) -> dict:
        """Serializa a dict listo para el broker (uuid→str, datetime→ISO-8601)."""
        return self.model_dump(mode="json")

    @classmethod
    def from_message(cls, data: dict) -> "ValidationJob":
        """Valida y construye desde un dict del broker. Lanza ``ValidationError`` si es inválido."""
        return cls.model_validate(data)


class Scores(BaseModel):
    """Puntajes binarios crudos del validador. NO incluye especie ni nivel G4."""

    model_config = ConfigDict(extra="forbid")

    arbol: float = Field(ge=0, le=1)
    parasitos: float = Field(ge=0, le=1)


class ValidationResult(BaseModel):
    """Resultado de validación (validador → backend). §6.3.

    El campo ``veredicto`` viaja en el mensaje por consistencia, pero **el backend es
    autoritativo**: usa :pyattr:`authoritative_verdict` (recomputado desde los dos booleanos)
    y nunca confía ciegamente en el ``veredicto`` recibido. :pyattr:`is_consistent` permite
    detectar (y registrar) un productor que haya enviado un veredicto incoherente.
    """

    model_config = ConfigDict(extra="forbid")

    observation_id: uuid.UUID
    es_arbol: bool
    parasitos_presentes: bool
    veredicto: _Veredicto
    scores: Scores
    model_version: str = Field(min_length=1)
    schema_version: Literal["1.0"] = SCHEMA_VERSION

    @property
    def authoritative_verdict(self) -> str:
        """Veredicto recomputado por la regla autoritativa §6.3 (lo que el backend debe usar)."""
        return compute_verdict(self.es_arbol, self.parasitos_presentes)

    @property
    def is_consistent(self) -> bool:
        """True si el ``veredicto`` del mensaje coincide con el autoritativo."""
        return self.veredicto == self.authoritative_verdict

    @classmethod
    def build(
        cls,
        *,
        observation_id: uuid.UUID | str,
        es_arbol: bool,
        parasitos_presentes: bool,
        scores: Scores,
        model_version: str,
        schema_version: str = SCHEMA_VERSION,
    ) -> "ValidationResult":
        """Construye un resultado con ``veredicto`` derivado por la regla autoritativa.

        Es el camino que usan el mock y el validador real: garantiza por construcción que
        ``veredicto == compute_verdict(es_arbol, parasitos_presentes)``.
        """
        return cls(
            observation_id=observation_id,  # type: ignore[arg-type]
            es_arbol=es_arbol,
            parasitos_presentes=parasitos_presentes,
            veredicto=compute_verdict(es_arbol, parasitos_presentes),  # type: ignore[arg-type]
            scores=scores,
            model_version=model_version,
            schema_version=schema_version,  # type: ignore[arg-type]
        )

    def to_message(self) -> dict:
        return self.model_dump(mode="json")

    @classmethod
    def from_message(cls, data: dict) -> "ValidationResult":
        return cls.model_validate(data)
