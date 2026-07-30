"""Gamificación E3/C2 (Q4) y nivel de identidad L3 — SIN gating funcional (gate #3).

- Lifelist = nº de árboles únicos observados por la cuenta.
- Insignias por milestones (sin desbloquear funciones).
- Etiqueta de identidad L3 = función de observaciones válidas + tiempo activo (fórmula concreta
  TBD/H7; aquí una progresión mínima derivable, marcada como provisional).
- Rankings por periodo (individual + por institución), filtrables por estado (Q8).

**CR-026 (solicitud de las universidades participantes):** todo lo que este módulo *cuenta y
presenta* — lifelist, conteo de observaciones, insignias, etiqueta L3 y rankings — considera
únicamente las observaciones **confirmadas** por revisión humana (``estado_revision =
'confirmada'``). Una foto que nadie ha revisado todavía, o que resultó no ser un mezquite, no
suma. El dato crudo NO se toca: ``account_review_counts`` sigue devolviendo el total sin filtrar y
``points_ledger`` sigue registrando cada alta; el criterio se aplica **al leer**.

**CR-030:** ``account_review_counts`` reemplaza al viejo ``account_observation_count`` (un solo
``count(*)``) y devuelve los cuatro estados de golpe, porque las pantallas del voluntario ahora
presentan el total subido y el confirmado uno al lado del otro.

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

# Etiqueta de identidad L3 por observaciones CONFIRMADAS (provisional; fórmula concreta = H7).
# CR-001 la movió de "válidas automáticas" a "no-rechazadas"; CR-026 la ajusta a "confirmadas".
_IDENTITY_LEVELS = [
    (0, "nuevo_observador"),
    (5, "observador"),
    (25, "observador_experimentado"),
    (75, "veterano_del_mezquite"),
]


def account_points(db: Session, account_id: uuid.UUID) -> int:
    """Puntos de la cuenta contando SOLO los de observaciones confirmadas (CR-026).

    El ledger sigue registrando la recompensa al subir (bitácora cruda, append-only); el filtro se
    aplica aquí, al leer. Así, si un veredicto se revierte (``confirmada`` → ``aceptada``, CR-010) o
    la observación se rechaza, el total se ajusta solo, sin lógica de compensación.
    """
    return int(
        db.execute(
            text(
                """
                SELECT COALESCE(sum(pl.points), 0)
                FROM points_ledger pl
                JOIN observation o ON o.id = pl.observation_id
                WHERE pl.account_id = :a AND o.estado_revision = 'confirmada'
                """
            ),
            {"a": account_id},
        ).scalar_one()
    )


def account_lifelist(db: Session, account_id: uuid.UUID) -> int:
    """Árboles distintos con al menos una observación CONFIRMADA de la cuenta (CR-026)."""
    return int(
        db.execute(
            text(
                "SELECT count(DISTINCT tree_id) FROM observation "
                "WHERE account_id = :a AND tree_id IS NOT NULL "
                "AND estado_revision = 'confirmada'"
            ),
            {"a": account_id},
        ).scalar_one()
    )


def account_confirmed_count(db: Session, account_id: uuid.UUID) -> int:
    """Observaciones CONFIRMADAS por revisión humana (CR-026).

    Es el contador que la app presenta como "observaciones válidas registradas" y el que alimenta
    insignias y etiqueta L3. Sustituye al criterio "no-rechazada" de CR-001, que contaba también lo
    que nadie había revisado todavía.
    """
    return int(
        db.execute(
            text(
                "SELECT count(*) FROM observation "
                "WHERE account_id = :a AND estado_revision = 'confirmada'"
            ),
            {"a": account_id},
        ).scalar_one()
    )


def account_review_counts(db: Session, account_id: uuid.UUID) -> dict[str, int]:
    """Los cuatro conteos de revisión de la cuenta, en UNA consulta (CR-030).

    Devuelve ``total`` (crudo subido), ``confirmada``, ``aceptada`` (= en revisión) y ``rechazada``.
    ``account_confirmed_count`` sigue sirviendo a quien solo necesita ese número (la etiqueta L3);
    esta existe para las pantallas que presentan varios **juntos** (perfil, resumen de aporte,
    comprobante de participación) y evita tres viajes a la base para el mismo renglón.

    Que ``aceptada`` viaje aparte no es cosmético: la app deducía "en revisión" restando
    ``total − confirmadas``, y esa resta contaba las **rechazadas** como si siguieran en cola.
    """
    row = (
        db.execute(
            text(
                """
                SELECT count(*) AS total,
                       count(*) FILTER (WHERE estado_revision = 'confirmada') AS confirmada,
                       count(*) FILTER (WHERE estado_revision = 'aceptada') AS aceptada,
                       count(*) FILTER (WHERE estado_revision = 'rechazada') AS rechazada
                FROM observation
                WHERE account_id = :a
                """
            ),
            {"a": account_id},
        )
        .mappings()
        .one()
    )
    return {key: int(value) for key, value in row.items()}


def compute_badges(confirmed_count: int) -> list[str]:
    """Insignias por milestones. CR-026: sobre observaciones CONFIRMADAS, no sobre las subidas."""
    return [name for threshold, name in _BADGE_THRESHOLDS if confirmed_count >= threshold]


def compute_identity_label(confirmed_count: int) -> str:
    label = _IDENTITY_LEVELS[0][1]
    for threshold, name in _IDENTITY_LEVELS:
        if confirmed_count >= threshold:
            label = name
    return label


def refresh_identity_label(db: Session, account_id: uuid.UUID) -> str:
    """Recomputa y persiste la etiqueta L3 de la cuenta sobre sus observaciones confirmadas.

    Se llama al subir (para que la etiqueta exista) y debe llamarse tras cada veredicto humano: con
    CR-026 la etiqueta solo cambia cuando una observación pasa a ``confirmada`` o deja de serlo.
    """
    confirmed = account_confirmed_count(db, account_id)
    label = compute_identity_label(confirmed)
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
    """Rankings individual + por institución por periodo, filtrables por estado (Q8).

    CR-026: cuenta y puntúa **solo observaciones confirmadas**, igual que el resto de los contadores.

    Las agregaciones van en subconsultas por cuenta a propósito: al unir ``observation`` y
    ``points_ledger`` en el mismo JOIN, cada fila del ledger se repetía una vez por observación y
    ``sum(points)`` salía multiplicado por el número de observaciones de la cuenta.
    """
    start = _period_start(period)
    params = {"start": start, "estado": estado, "limit": limit}
    # Filtro compartido de observaciones: confirmadas (CR-026) + ventana del periodo + estado (Q8).
    obs_where = """
        o.estado_revision = 'confirmada'
        AND (CAST(:start AS timestamptz) IS NULL OR o.captured_at >= :start)
        AND (CAST(:estado AS text) IS NULL OR o.estado = :estado)
    """
    # Un renglón por cuenta con sus dos agregados ya calculados (sin producto cartesiano).
    per_account = f"""
        LEFT JOIN (
            SELECT o.account_id, count(*) AS observations
            FROM observation o
            WHERE {obs_where}
            GROUP BY o.account_id
        ) obs ON obs.account_id = a.id
        LEFT JOIN (
            SELECT pl.account_id, sum(pl.points) AS points
            FROM points_ledger pl
            JOIN observation o ON o.id = pl.observation_id
            WHERE {obs_where}
            GROUP BY pl.account_id
        ) pts ON pts.account_id = a.id
    """

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
                       COALESCE(pts.points, 0) AS points,
                       COALESCE(obs.observations, 0) AS observations
                FROM account a
                LEFT JOIN institution i ON i.id = a.institution_id
                {per_account}
                WHERE COALESCE(obs.observations, 0) > 0
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
                       COALESCE(sum(pts.points), 0) AS points,
                       COALESCE(sum(obs.observations), 0) AS observations
                FROM institution i
                JOIN account a ON a.institution_id = i.id
                {per_account}
                GROUP BY i.name, i.estado
                HAVING COALESCE(sum(obs.observations), 0) > 0
                ORDER BY points DESC
                LIMIT :limit
                """
            ),
            params,
        ).all()
    ]

    return {"period": period, "individual": individual, "by_institution": by_institution}
