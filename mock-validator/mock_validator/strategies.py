"""Estrategias de evaluación del mock: fijo | aleatorio | regla.

Cada estrategia produce los dos hechos binarios del contrato (es_arbol, parasitos_presentes)
y sus *scores*. NUNCA produce especie ni nivel G4 (fuera de alcance, Q5.A-D1).
"""

from __future__ import annotations

import hashlib
import random
from dataclasses import dataclass

from .config import Config


@dataclass
class Evaluation:
    es_arbol: bool
    parasitos_presentes: bool
    score_arbol: float
    score_parasitos: float


def _score_for(flag: bool, fraction: float) -> float:
    """Mapea un booleano + una fracción [0,1) a un score plausible y consistente con el booleano."""
    if flag:
        return round(0.5 + 0.5 * fraction, 4)  # [0.5, 1.0)
    return round(0.5 * fraction, 4)  # [0.0, 0.5)


def _hash_fractions(observation_id: str) -> tuple[float, float]:
    """Dos fracciones deterministas y reproducibles derivadas del observation_id."""
    digest = hashlib.sha256(observation_id.encode("utf-8")).digest()
    f1 = int.from_bytes(digest[0:4], "big") / 2**32
    f2 = int.from_bytes(digest[4:8], "big") / 2**32
    return f1, f2


def evaluate(cfg: Config, observation_id: str, *, rng: random.Random | None = None) -> Evaluation:
    mode = cfg.mode
    if mode == "fijo":
        es = cfg.fixed_es_arbol
        par = cfg.fixed_parasitos
        return Evaluation(es, par, _score_for(es, 0.98), _score_for(par, 0.98))

    if mode == "aleatorio":
        r = rng or random.Random(cfg.seed)
        f1, f2 = r.random(), r.random()
        es = f1 < cfg.p_es_arbol
        par = f2 < cfg.p_parasitos
        return Evaluation(es, par, _score_for(es, r.random()), _score_for(par, r.random()))

    if mode == "regla":
        # Determinista por observation_id: la misma observacion siempre obtiene el mismo veredicto.
        f1, f2 = _hash_fractions(observation_id)
        es = f1 < cfg.regla_p_es_arbol
        par = f2 < cfg.regla_p_parasitos
        return Evaluation(es, par, _score_for(es, f1), _score_for(par, f2))

    raise ValueError(f"modo desconocido: {mode!r}")
