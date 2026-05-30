"""Modos del mock: fijo, aleatorio (reproducible con semilla), regla (determinista por id)."""

import random
import uuid

from mock_validator.config import Config
from mock_validator.strategies import evaluate


def test_modo_fijo():
    cfg = Config(mode="fijo", fixed_es_arbol=True, fixed_parasitos=False)
    ev = evaluate(cfg, str(uuid.uuid4()))
    assert ev.es_arbol is True
    assert ev.parasitos_presentes is False
    assert ev.score_arbol >= 0.5 and ev.score_parasitos < 0.5


def test_modo_aleatorio_reproducible_con_semilla():
    obs = str(uuid.uuid4())
    a = evaluate(Config(mode="aleatorio", seed=42), obs, rng=random.Random(42))
    b = evaluate(Config(mode="aleatorio", seed=42), obs, rng=random.Random(42))
    assert (a.es_arbol, a.parasitos_presentes) == (b.es_arbol, b.parasitos_presentes)


def test_modo_regla_determinista_por_observation_id():
    obs = str(uuid.uuid4())
    cfg = Config(mode="regla")
    a = evaluate(cfg, obs)
    b = evaluate(cfg, obs)
    assert (a.es_arbol, a.parasitos_presentes) == (b.es_arbol, b.parasitos_presentes)
    assert (a.score_arbol, a.score_parasitos) == (b.score_arbol, b.score_parasitos)


def test_modo_regla_distingue_observaciones():
    cfg = Config(mode="regla", regla_p_es_arbol=0.5, regla_p_parasitos=0.5)
    resultados = {
        evaluate(cfg, str(uuid.UUID(int=i))).es_arbol for i in range(50)
    }
    # con p=0.5 sobre 50 ids deterministas deben aparecer ambos valores
    assert resultados == {True, False}
