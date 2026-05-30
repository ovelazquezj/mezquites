"""Configuración del mock por variables de entorno (conmutable, sin nube en dev/QA)."""

from __future__ import annotations

import os
from dataclasses import dataclass

MODES = ("fijo", "aleatorio", "regla")


def _bool(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).strip().lower() in ("1", "true", "yes", "on", "si", "sí")


def _float(name: str, default: float) -> float:
    return float(os.getenv(name, str(default)))


def _int(name: str, default: int) -> int:
    return int(os.getenv(name, str(default)))


@dataclass
class Config:
    """Parámetros del mock. Todos con defaults razonables para dev."""

    # Modo de evaluación: fijo | aleatorio | regla
    mode: str = "regla"

    # --- modo "fijo": siempre devuelve estos dos hechos ---
    fixed_es_arbol: bool = True
    fixed_parasitos: bool = True

    # --- modo "aleatorio": probabilidades independientes ---
    p_es_arbol: float = 0.8
    p_parasitos: float = 0.6

    # --- modo "regla": determinista y reproducible por observation_id ---
    regla_p_es_arbol: float = 0.85
    regla_p_parasitos: float = 0.55

    # Semilla (None = no determinista en "aleatorio"; "regla" siempre es determinista por id)
    seed: int | None = None

    # --- latencia simulada del validador (ms) ---
    latency_ms_min: int = 50
    latency_ms_max: int = 250

    # --- transporte ---
    broker_kind: str = "redis"  # redis | memory
    redis_url: str = "redis://localhost:6379/0"

    # --- identidad ---
    model_version: str = "mock"
    consumer_name: str = "mock-1"

    def __post_init__(self) -> None:
        if self.mode not in MODES:
            raise ValueError(f"MOCK_MODE invalido: {self.mode!r}. Use uno de {MODES}.")
        if self.latency_ms_max < self.latency_ms_min:
            raise ValueError("LATENCY_MS_MAX no puede ser menor que LATENCY_MS_MIN.")

    @classmethod
    def from_env(cls) -> "Config":
        seed_raw = os.getenv("MOCK_SEED")
        return cls(
            mode=os.getenv("MOCK_MODE", "regla").strip().lower(),
            fixed_es_arbol=_bool("MOCK_FIXED_ES_ARBOL", True),
            fixed_parasitos=_bool("MOCK_FIXED_PARASITOS", True),
            p_es_arbol=_float("MOCK_P_ES_ARBOL", 0.8),
            p_parasitos=_float("MOCK_P_PARASITOS", 0.6),
            regla_p_es_arbol=_float("MOCK_REGLA_P_ES_ARBOL", 0.85),
            regla_p_parasitos=_float("MOCK_REGLA_P_PARASITOS", 0.55),
            seed=int(seed_raw) if seed_raw not in (None, "") else None,
            latency_ms_min=_int("MOCK_LATENCY_MS_MIN", 50),
            latency_ms_max=_int("MOCK_LATENCY_MS_MAX", 250),
            broker_kind=os.getenv("MOCK_BROKER", "redis").strip().lower(),
            redis_url=os.getenv("REDIS_URL", "redis://localhost:6379/0"),
            model_version=os.getenv("MOCK_MODEL_VERSION", "mock"),
            consumer_name=os.getenv("MOCK_CONSUMER_NAME", "mock-1"),
        )
