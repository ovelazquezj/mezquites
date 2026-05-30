"""Gamificación E3/C2 (Q4) y nivel de identidad L3 — SIN gating funcional (gate #3).

- Lifelist = nº de árboles únicos observados por la cuenta.
- Insignias por milestones (sin desbloquear funciones).
- Etiqueta de identidad L3 = función de observaciones válidas + tiempo activo (fórmula concreta
  TBD/H7; aquí una progresión mínima derivable, marcada como provisional).
- Rankings por periodo (individual + por institución), filtrables por estado (Q8).

Gate #3 / Q5.C-D1: NO hay multiplicadores por capacitación, NI certificados/tier que bloqueen.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import text
from sqlalchemy.orm import Session

# Milestones de insignias (provisional; refinable por diseño de gamificación, H7).
_BADGE_THRESHOLDS = [
    (1, "primera_observacion"),
    (10, "explorador"),
    (50, "observador_dedicado"),
    (100, "centinela_del_mezquite"),
]

# Etiqueta de identidad L3 por observaciones válidas (provisional; fórmula concreta = H7).
_IDENTITY_LEVELS = [
    (0, "nuevo_observador"),
    (5, "observador"),
    (25, "observador_experimentado"),
    (75, "veterano_del_mezquite"),
]


def account_points(db: Session, account_id: uuid.UUID) -> int:
    return int(
        db.execute(
            text("SELECT COALESCE(sum(points), 0) FROM points_ledger WHERE account_id = :a"),
            {"a": account_id},
        ).scalar_one()
    )


def account_lifelist(db: Session, account_id: uuid.UUID) -> int:
    return int(
        db.execute(
            text(
                "SELECT count(DISTINCT tree_id) FROM observation "
                "WHERE account_id = :a AND tree_id IS NOT NULL"
            ),
            {"a": account_id},
        ).scalar_one()
    )


def account_observation_count(db: Session, account_id: uuid.UUID) -> int:
    return int(
        db.execute(
            text("SELECT count(*) FROM observation WHERE account_id = :a"),
            {"a": account_id},
        ).scalar_one()
    )


def account_valid_count(db: Session, account_id: uuid.UUID) -> int:
    return int(
        db.execute(
            text(
                "SELECT count(*) FROM observation "
                "WHERE account_id = :a AND validation_state = 'valida'"
            ),
            {"a": account_id},
        ).scalar_one()
    )


def compute_badges(observation_count: int) -> list[str]:
    return [name for threshold, name in _BADGE_THRESHOLDS if observation_count >= threshold]


def compute_identity_label(valid_count: int) -> str:
    label = _IDENTITY_LEVELS[0][1]
    for threshold, name in _IDENTITY_LEVELS:
        if valid_count >= threshold:
            label = name
    return label


def refresh_identity_label(db: Session, account_id: uuid.UUID) -> str:
    """Recomputa y persiste la etiqueta L3 de la cuenta (llamado tras otorgar puntos diferidos)."""
    valid = account_valid_count(db, account_id)
    label = compute_identity_label(valid)
    db.execute(
        text("UPDATE account SET identity_label = :l WHERE id = :a"),
        {"l": label, "a": account_id},
    )
    return label


def _period_start(period: str) -> datetime | None:
    now = datetime.now(timezone.utc)
    if period == "all":
        return None
    if period == "month":
        return now - timedelta(days=30)
    if period == "quarter":
        return now - timedelta(days=90)
    if period == "year":
        return now - timedelta(days=365)
    return None


def rankings(db: Session, *, period: str = "all", estado: str | None = None, limit: int = 50) -> dict:
    """Rankings individual + por institución por periodo, filtrables por estado (Q8)."""
    start = _period_start(period)
    params = {"start": start, "estado": estado, "limit": limit}
    time_clause = "AND (CAST(:start AS timestamptz) IS NULL OR o.captured_at >= :start)"
    estado_clause = "AND (CAST(:estado AS text) IS NULL OR o.estado = :estado)"

    individual = [
        {
            "handle": r[0],
            "institution": r[1],
            "estado": r[2],
            "points": int(r[3] or 0),
            "observations": int(r[4] or 0),
        }
        for r in db.execute(
            text(
                f"""
                SELECT a.handle, i.name AS institution, i.estado AS estado,
                       COALESCE(sum(pl.points), 0) AS points,
                       count(DISTINCT o.id) AS observations
                FROM account a
                LEFT JOIN institution i ON i.id = a.institution_id
                LEFT JOIN observation o ON o.account_id = a.id
                    {time_clause} {estado_clause}
                LEFT JOIN points_ledger pl ON pl.account_id = a.id
                GROUP BY a.handle, i.name, i.estado
                HAVING count(DISTINCT o.id) > 0
                ORDER BY points DESC, observations DESC
                LIMIT :limit
                """
            ),
            params,
        ).all()
    ]

    by_institution = [
        {
            "institution": r[0],
            "estado": r[1],
            "points": int(r[2] or 0),
            "observations": int(r[3] or 0),
        }
        for r in db.execute(
            text(
                f"""
                SELECT i.name, i.estado,
                       COALESCE(sum(pl.points), 0) AS points,
                       count(DISTINCT o.id) AS observations
                FROM institution i
                JOIN account a ON a.institution_id = i.id
                LEFT JOIN observation o ON o.account_id = a.id
                    {time_clause} {estado_clause}
                LEFT JOIN points_ledger pl ON pl.account_id = a.id
                GROUP BY i.name, i.estado
                HAVING count(DISTINCT o.id) > 0
                ORDER BY points DESC
                LIMIT :limit
                """
            ),
            params,
        ).all()
    ]

    return {"period": period, "individual": individual, "by_institution": by_institution}
