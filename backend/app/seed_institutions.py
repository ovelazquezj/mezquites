"""Siembra del catálogo de instituciones aprobadas (CR-010) — idempotente, por CLI.

Inserta como **aprobadas** (``estado='Aguascalientes'``) las instituciones de la lista F3 para que el
voluntario pueda elegir afiliación durante el alta. El voluntario también puede **solicitar** una
nueva desde la app (``POST /institutions/request``), que queda ``solicitada`` (no se siembra aquí).

Uso:
    python -m backend.app.seed_institutions

Idempotente: cada institución se siembra por ``name`` (no se duplica si ya existe; respeta el status
actual de una ya existente). No requiere nube (gate #6).

Notas de gates:
- Gate #2 (sin PII): instituciones = catálogo, sin datos personales.
- Gate #3 (sin gating): la elección de institución no bloquea nada.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from .db import get_sessionmaker
from .models import Institution

ESTADO = "Aguascalientes"

# Lista F3 inicial (CR-010). Todas APROBADAS, estado Aguascalientes. "Institución Independiente"
# cubre al voluntario sin afiliación formal.
INSTITUCIONES: list[str] = [
    "Universidad Autónoma de Aguascalientes (UAA)",
    "Instituto Tecnológico de Aguascalientes (TecNM)",
    "Universidad Politécnica de Aguascalientes",
    "Universidad Tecnológica de Aguascalientes",
    "Universidad Cuauhtémoc Aguascalientes",
    "UVM campus Aguascalientes",
    "Tecnológico de Monterrey campus Aguascalientes",
    "Institución Independiente",
]


def seed_institutions(db: Session) -> tuple[int, int]:
    """Siembra el catálogo aprobado. Devuelve ``(insertadas, ya_existian)``. Idempotente por nombre."""
    insertadas = 0
    ya_existian = 0
    for name in INSTITUCIONES:
        existente = db.query(Institution).filter(Institution.name == name).one_or_none()
        if existente is not None:
            ya_existian += 1
            continue
        db.add(Institution(name=name, estado=ESTADO, status="aprobada"))
        insertadas += 1
    db.commit()
    return insertadas, ya_existian


def main(argv: list[str] | None = None) -> int:  # pragma: no cover - envoltorio CLI
    SessionLocal = get_sessionmaker()
    db = SessionLocal()
    try:
        insertadas, ya_existian = seed_institutions(db)
    finally:
        db.close()

    print(
        f"siembra de instituciones: {insertadas} nuevas, {ya_existian} ya existían "
        f"(total objetivo={len(INSTITUCIONES)}, estado={ESTADO})"
    )
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
