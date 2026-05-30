"""Conexión a PostgreSQL+PostGIS vía SQLAlchemy 2.0 (T3).

El engine se construye desde ``DATABASE_URL`` (paridad de entornos, gate #6): el mismo código
corre contra el contenedor PostGIS de dev/QA y contra la DB gestionada de stg/prod.
"""

from __future__ import annotations

from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import get_settings


class Base(DeclarativeBase):
    """Base declarativa de todos los modelos."""


_engine = None
_SessionLocal: sessionmaker[Session] | None = None


def get_engine():
    global _engine
    if _engine is None:
        settings = get_settings()
        _engine = create_engine(settings.database_url, pool_pre_ping=True, future=True)
    return _engine


def get_sessionmaker() -> sessionmaker[Session]:
    global _SessionLocal
    if _SessionLocal is None:
        _SessionLocal = sessionmaker(bind=get_engine(), autoflush=False, expire_on_commit=False)
    return _SessionLocal


def get_db() -> Iterator[Session]:
    """Dependencia FastAPI: una sesión por request, con commit/rollback gestionado por el caller."""
    session = get_sessionmaker()()
    try:
        yield session
    finally:
        session.close()
