"""tree_id agrupa observaciones dentro de 10 m (Q2/R3, criterio T3). Requiere PostGIS real."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import text

from .helpers import register, submit_observation

# ~5 m de desplazamiento en latitud (1° lat ≈ 111_320 m → 0.000045° ≈ 5 m).
DELTA_5M = 0.000045
# ~25 m → fuera del radio de 10 m.
DELTA_25M = 0.000225


def _tree_ids(db):
    return [r[0] for r in db.execute(text("SELECT DISTINCT tree_id FROM observation")).all()]


def test_two_close_observations_share_tree(client, db_session):
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.8853, lon=-102.2916)
    submit_observation(client, reg["token"], lat=21.8853 + DELTA_5M, lon=-102.2916)
    ids = _tree_ids(db_session)
    assert len(ids) == 1  # ≤ 10 m → mismo árbol
    assert db_session.execute(text("SELECT count(*) FROM tree")).scalar_one() == 1


def test_far_observations_get_distinct_trees(client, db_session):
    reg = register(client)
    submit_observation(client, reg["token"], lat=21.8853, lon=-102.2916)
    submit_observation(client, reg["token"], lat=21.8853 + DELTA_25M, lon=-102.2916)
    assert db_session.execute(text("SELECT count(*) FROM tree")).scalar_one() == 2


def test_observation_seq_increments_within_same_tree(client, db_session):
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
    assert seqs == [1, 2]
