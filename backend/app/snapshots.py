"""Utilidades de snapshot trimestral (Q5.B-D1: toda vista muestra 'última actualización Qn')."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import text
from sqlalchemy.orm import Session

from .models import Snapshot


def current_quarter_label(now: datetime | None = None) -> str:
    now = now or datetime.now(timezone.utc)
    q = (now.month - 1) // 3 + 1
    return f"{now.year}-Q{q}"


def latest_snapshot_label(db: Session) -> str:
    """Etiqueta del último snapshot registrado; si no hay ninguno, el trimestre actual."""
    row = db.execute(
        text("SELECT quarter FROM snapshot ORDER BY created_at DESC LIMIT 1")
    ).first()
    return row[0] if row else current_quarter_label()


def create_snapshot(db: Session) -> Snapshot:
    total = db.execute(text("SELECT count(*) FROM observation")).scalar_one()
    snap = Snapshot(quarter=current_quarter_label(), observations_total=int(total))
    db.add(snap)
    db.flush()
    return snap
