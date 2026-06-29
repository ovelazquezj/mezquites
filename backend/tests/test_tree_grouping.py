"""CR-022 (enmienda R3/T3): cada foto registra su propio árbol — 1:1 observación↔árbol.

Antes (R3/gate T3) dos observaciones a ≤ 10 m compartían ``tree_id``; CR-022 retira esa
reutilización: cada captura crea su propio árbol y su ``observation_seq`` siempre es 1.
Requiere PostGIS real.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import text

from .helpers import register, submit_observation

# ~5 m de desplazamiento en latitud (1° lat ≈ 111_320 m → 0.000045° ≈ 5 m).
DELTA_5M = 0.000045
# ~25 m → bien separado.
DELTA_25M = 0.000225


def _tree_ids(db):
    return [r[0] for r in db.execute(text("SELECT DISTINCT tree_id FROM observation")).all()]


def test_two_close_observations_each_get_own_tree(client, db_session):
    """CR-022: dos observaciones cercanas (≤ 10 m) ahora crean DOS árboles (1:1), ya no comparten."""
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.8853, lon=-102.2916)
    submit_observation(client, reg["token"], lat=21.8853 + DELTA_5M, lon=-102.2916)
    ids = _tree_ids(db_session)
    assert len(ids) == 2  # CR-022: cada foto su propio árbol (antes era 1)
    assert db_session.execute(text("SELECT count(*) FROM tree")).scalar_one() == 2


def test_far_observations_get_distinct_trees(client, db_session):
    """Observaciones separadas siguen produciendo árboles distintos (sin cambio bajo CR-022)."""
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.8853, lon=-102.2916)
    submit_observation(client, reg["token"], lat=21.8853 + DELTA_25M, lon=-102.2916)
    assert db_session.execute(text("SELECT count(*) FROM tree")).scalar_one() == 2


def test_each_observation_seq_is_one(client, db_session):
    """CR-022: al ser cada árbol único, ``observation_seq`` es 1 para cada captura (antes 1,2)."""
    reg = register(client)
    base = datetime(2026, 1, 1, tzinfo=timezone.utc)
    submit_observation(client, reg["token"], lat=21.8853, lon=-102.2916, captured_at=base)
    submit_observation(
        client, reg["token"], lat=21.8853 + DELTA_5M, lon=-102.2916,
        captured_at=base + timedelta(days=40),
    )
    seqs = sorted(
        r[0] for r in db_session.execute(
            text("SELECT observation_seq FROM observation ORDER BY captured_at")
        ).all()
    )
    assert seqs == [1, 1]  # CR-022: cada observación en su propio árbol → seq=1
