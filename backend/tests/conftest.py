"""Fixtures de pruebas del backend.

- Pruebas de **lógica pura** (obfuscación, storage, auth/roles, encolado) corren SIN DB.
- Pruebas que requieren **PostGIS** usan un contenedor real (`postgis/postgis:16-3.4`):
  intenta `testcontainers`; si no, levanta el contenedor con `docker run` y espera readiness.
  Si Docker no está disponible, esas pruebas se **omiten** (skip), nunca fallan en falso.

El esquema se crea con `Base.metadata.create_all` tras `CREATE EXTENSION postgis` (equivalente
a la migración Alembic 0001 para fines de prueba; la migración real se valida en compose/K8s).
"""

from __future__ import annotations

import os
import socket
import subprocess
import time
import uuid

import pytest

PG_IMAGE = "postgis/postgis:16-3.4"
PG_USER = "mezquite"
PG_PASSWORD = "mezquite"
PG_DB = "mezquite_test"


def _free_port() -> int:
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def _docker_available() -> bool:
    try:
        subprocess.run(
            ["docker", "version", "--format", "{{.Server.Version}}"],
            capture_output=True,
            timeout=15,
            check=True,
        )
        return True
    except Exception:
        return False


def _wait_for_pg(url: str, timeout: float = 90.0) -> bool:
    import sqlalchemy

    deadline = time.time() + timeout
    last_exc = None
    while time.time() < deadline:
        try:
            eng = sqlalchemy.create_engine(url)
            with eng.connect() as conn:
                conn.execute(sqlalchemy.text("SELECT 1"))
            eng.dispose()
            return True
        except Exception as exc:  # noqa: BLE001
            last_exc = exc
            time.sleep(1.5)
    print("PG no listo:", last_exc)
    return False


@pytest.fixture(scope="session")
def pg_url() -> str:
    """URL SQLAlchemy a un PostGIS real. Skip si Docker no está disponible."""
    if not _docker_available():
        pytest.skip("Docker no disponible; se omiten las pruebas que requieren PostGIS")

    # 1) Intentar testcontainers.
    try:
        from testcontainers.postgres import PostgresContainer

        container = PostgresContainer(
            PG_IMAGE, username=PG_USER, password=PG_PASSWORD, dbname=PG_DB
        )
        container.start()
        raw = container.get_connection_url()  # postgresql+psycopg2://...
        url = raw.replace("postgresql+psycopg2", "postgresql+psycopg").replace(
            "postgresql://", "postgresql+psycopg://"
        )
        if _wait_for_pg(url):
            yield url
            container.stop()
            return
        container.stop()
    except Exception as exc:  # noqa: BLE001
        print("testcontainers no usable, fallback a docker run:", exc)

    # 2) Fallback: docker run directo.
    port = _free_port()
    name = f"mezquite-pgtest-{uuid.uuid4().hex[:8]}"
    subprocess.run(
        [
            "docker", "run", "-d", "--rm", "--name", name,
            "-e", f"POSTGRES_USER={PG_USER}",
            "-e", f"POSTGRES_PASSWORD={PG_PASSWORD}",
            "-e", f"POSTGRES_DB={PG_DB}",
            "-p", f"{port}:5432",
            PG_IMAGE,
        ],
        check=True,
        capture_output=True,
    )
    url = f"postgresql+psycopg://{PG_USER}:{PG_PASSWORD}@127.0.0.1:{port}/{PG_DB}"
    try:
        if not _wait_for_pg(url):
            pytest.skip("PostGIS no alcanzó readiness a tiempo")
        yield url
    finally:
        subprocess.run(["docker", "rm", "-f", name], capture_output=True)


@pytest.fixture(scope="session")
def engine(pg_url):
    """Engine con esquema creado (extensión postgis + todas las tablas)."""
    import sqlalchemy
    from sqlalchemy import text

    from backend.app.db import Base
    from backend.app import models  # noqa: F401  (registra tablas)

    eng = sqlalchemy.create_engine(pg_url, future=True)
    with eng.begin() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS pgcrypto"))
    Base.metadata.create_all(eng)
    yield eng
    eng.dispose()


@pytest.fixture()
def db_session(engine):
    """Sesión por prueba, con limpieza de datos entre pruebas (TRUNCATE)."""
    from sqlalchemy import text
    from sqlalchemy.orm import sessionmaker

    Session = sessionmaker(bind=engine, expire_on_commit=False)
    with engine.begin() as conn:
        conn.execute(
            text(
                "TRUNCATE points_ledger, human_review, validation_event, observation, tree, "
                "account, institution, organizational_indicator, snapshot, admin_boundary "
                "RESTART IDENTITY CASCADE"
            )
        )
    session = Session()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture()
def client(engine, tmp_path, monkeypatch):
    """TestClient con la app real cableada al PostGIS de prueba, storage local y broker memory.

    Inyecta un InMemoryBroker compartido para verificar el encolado sin Redis (gate #6/T6).
    """
    from fastapi.testclient import TestClient
    from sqlalchemy.orm import sessionmaker
    from mezquite_contract.broker import InMemoryBroker

    from backend.app import db as db_module
    from backend.app import queue as queue_module
    from backend.app import storage as storage_module
    from backend.app.config import get_settings
    from backend.app.db import get_db
    from backend.app.main import app
    from backend.app.storage import LocalFSStorage

    # Engine/sessionmaker → contenedor de prueba.
    db_module._engine = engine
    db_module._SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)

    # Storage local en tmp.
    storage_module._storage = LocalFSStorage(str(tmp_path / "storage"))

    # Broker memory compartido (encolado verificable).
    broker = InMemoryBroker()
    queue_module.set_broker(broker)

    # Asegura settings cacheados coherentes (local + memory).
    get_settings.cache_clear()
    monkeypatch.setenv("STORAGE_BACKEND", "local")
    monkeypatch.setenv("BROKER", "memory")

    def _override_db():
        s = db_module._SessionLocal()
        try:
            yield s
        finally:
            s.close()

    app.dependency_overrides[get_db] = _override_db
    test_client = TestClient(app)
    test_client.broker = broker  # expuesto para aserciones de encolado
    yield test_client
    app.dependency_overrides.clear()
