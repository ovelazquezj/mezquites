"""Configuración conmutable por entorno (paridad de entornos, gate #6).

Todo recurso con dependencia de infraestructura (DB, storage, broker) se selecciona por
variable de entorno, para que **dev/QA corran SIN nube**:

- ``DATABASE_URL``         — PostgreSQL+PostGIS (contenedor en dev/QA, gestionado en stg/prod).
- ``STORAGE_BACKEND``      — ``local`` (filesystem) | ``s3`` (object storage S3-compatible).
- ``BROKER``               — ``memory`` (InMemoryBroker) | ``redis`` (RedisStreamsBroker).
- ``AUTH_SECRET``          — secreto para firmar tokens (sin PII en el payload).

Ninguna de estas decisiones toca el código de aplicación: solo cambia la configuración.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- Base de datos (PostGIS) ---
    database_url: str = "postgresql+psycopg://mezquite:mezquite@localhost:5432/mezquite"

    # --- Storage (T4 / gate #6) ---
    storage_backend: str = "local"          # local | s3
    storage_local_dir: str = "./_storage"   # raíz del filesystem local (dev/QA)
    storage_public_base_url: str = "/files"  # prefijo para construir url() en local

    # S3 / object storage (stg/prod)
    s3_bucket: str = "mezquite-observations"
    s3_endpoint_url: str | None = None       # p.ej. MinIO; None ⇒ AWS por defecto
    s3_region: str = "us-east-1"
    s3_access_key: str | None = None
    s3_secret_key: str | None = None
    s3_presign_ttl: int = 3600

    # --- Broker / cola §6 (T6 / gate #6) ---
    broker: str = "memory"                   # memory | redis
    redis_url: str = "redis://localhost:6379/0"

    # --- Auth (gate #2 acotado por CR-002: identidad real con mínima PII) ---
    auth_secret: str = "dev-insecure-secret-change-me"
    auth_algorithm: str = "HS256"
    auth_token_ttl_seconds: int = 60 * 60 * 24 * 30  # 30 días

    # Proveedor de auth conmutable (gate #6): mock en dev/QA/test (sin red), firebase en prod.
    auth_provider: str = "mock"              # mock | firebase
    # No secreto: identifican el proyecto/cliente OAuth de Google (verificación del ID token).
    firebase_project_id: str | None = None   # aud/iss esperados al verificar el ID token
    google_oauth_audience: str | None = None  # alias explícito del aud si difiere del project id
    # Token que acepta el MockAuthProvider (sin red); el `sub` se deriva del propio token.
    mock_google_token: str = "mock-google-id-token"

    # Bootstrap del primer administrador (config/CLI). Cierra el hueco del gate #5.
    bootstrap_admin_username: str | None = None
    bootstrap_admin_password: str | None = None
    bootstrap_admin_email: str | None = None

    # SMTP para el reset por correo del administrador (secreto). Si falta, el reset degrada a
    # "reset por el administrador" (riesgo §9 del CR).
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_user: str | None = None
    smtp_password: str | None = None
    smtp_from: str = "no-reply@mezquite.local"

    # --- Reglas de dominio (refinables por AU2, H8 — no reabren decisiones) ---
    tree_radius_m: float = 10.0              # R3: radio de agrupamiento
    revisit_gap_days: int = 30               # R3: ventana de serie temporal
    obfuscation_grid_m: float = 1000.0       # gate #5: celda pública mínima (1 km)
    metric_srid: int = 6372                  # EPSG:6372 (México ITRF2008 LCC) para metros
    points_base: int = 5                     # recompensa base (fire-and-forget)
    points_deferred: int = 10                # recompensa diferida (solo si válida)
    feedback_window: int = 20                # "de tus últimas N observaciones"


@lru_cache
def get_settings() -> Settings:
    return Settings()
