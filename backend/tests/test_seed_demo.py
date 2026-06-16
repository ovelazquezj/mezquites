"""Siembra de demo del mapa de calor (CR-009): idempotente y legible en /public/grid."""

from __future__ import annotations

from sqlalchemy import text

from backend.app import seed_demo as seed_module


def test_seed_demo_is_idempotent_and_populates_several_cells(client, db_session):
    # Primera siembra: inserta el lote de demo.
    insertadas, sembrada = seed_module.seed_demo(db_session)
    assert sembrada is True
    assert insertadas == len(seed_module.SEED_OBSERVACIONES)
    db_session.expire_all()
    total_1 = db_session.execute(text("SELECT count(*) FROM observation")).scalar_one()
    assert total_1 == len(seed_module.SEED_OBSERVACIONES)

    # Segunda invocación: NO duplica (idempotente).
    insertadas_2, sembrada_2 = seed_module.seed_demo(db_session)
    assert sembrada_2 is False
    assert insertadas_2 == 0
    total_2 = db_session.execute(text("SELECT count(*) FROM observation")).scalar_one()
    assert total_2 == total_1

    # El mapa de calor es legible: varias celdas y al menos una con conteo > 1.
    grid = client.get("/api/v1/public/grid").json()
    assert len(grid) >= 5, grid
    assert any(c["n"] > 1 for c in grid)
    # Mezcla de paxtle/cúscuta presente en el dataset sembrado.
    assert any(c["n_paxtle"] > 0 for c in grid)
    assert any(c["n_cuscuta"] > 0 for c in grid)
    # G4 variado: hay celdas con índice bajo (sano) y alto (severo).
    indices = [c["g4_indice"] for c in grid]
    assert min(indices) == 0.0
    assert max(indices) == 3.0


def test_seed_demo_account_has_no_pii(db_session):
    """La cuenta sembradora no porta PII (gate #2): sin email; provider_subject opaco."""
    seed_module.seed_demo(db_session)
    row = db_session.execute(
        text(
            "SELECT email, role, auth_provider FROM account WHERE handle = :h"
        ),
        {"h": seed_module.SEED_HANDLE},
    ).one()
    email, role, auth_provider = row
    assert email is None
    assert role == "voluntario"
    assert auth_provider == "social_google"
