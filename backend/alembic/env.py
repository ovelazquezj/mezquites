"""Entorno Alembic. La URL viene de DATABASE_URL (gate #6: conmutable por config)."""

from __future__ import annotations

import sys
from logging.config import fileConfig
from pathlib import Path

from alembic import context
from sqlalchemy import engine_from_config, pool

# Asegura que la RAÍZ DEL REPO (padre del paquete `backend`) esté en sys.path, de modo que
# `import backend.app...` funcione sin importar el CWD desde el que se invoque Alembic.
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

# Importa los modelos para autogenerate y target_metadata.
from backend.app.config import get_settings  # noqa: E402
from backend.app.db import Base  # noqa: E402
from backend.app import models  # noqa: F401,E402  (registra las tablas en Base.metadata)

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Inyecta la URL real desde la configuración (no se fija en alembic.ini).
config.set_main_option("sqlalchemy.url", get_settings().database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=config.get_main_option("sqlalchemy.url"),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
