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

    # --- CORS (CR-004 W3) ---
    # Orígenes permitidos para el navegador (web admin + FE web del voluntario, CR-005). Por
    # entorno: en dev se permite cualquier `http://localhost:*` / `http://127.0.0.1:*` (regex);
    # en QA/Prod se listan los dominios reales (coma-separados). NUNCA `*` con credenciales en prod.
    # - cors_allow_origins: lista explícita coma-separada (p.ej. "https://app.mezquite.org").
    # - cors_allow_origin_regex: regex de orígenes (p.ej. localhost en dev). Si está vacío en dev,
    #   se usa el patrón de localhost por defecto.
    cors_allow_origins: str = ""        # coma-separado; vacío = sin orígenes explícitos
    cors_allow_origin_regex: str = ""   # regex; vacío en dev ⇒ patrón localhost por defecto
    cors_env: str = "dev"               # dev | prod — en dev se relaja a localhost por regex

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


    def cors_kwargs(self) -> dict:
        """Argumentos para ``CORSMiddleware`` derivados por entorno (CR-004 W3).

        - **dev**: si no se dan orígenes/regex explícitos, se permite cualquier ``localhost``/
          ``127.0.0.1`` en cualquier puerto vía regex (cubre el web admin y el FE web del
          voluntario sin enumerar puertos). Nunca usa ``*``.
        - **prod/QA**: solo los orígenes de ``cors_allow_origins`` (lista explícita) y/o el regex
          de ``cors_allow_origin_regex``. Si no se configura ninguno, CORS queda cerrado (sin
          orígenes), que es el comportamiento seguro por defecto.
        """
        origins = [o.strip() for o in self.cors_allow_origins.split(",") if o.strip()]
        regex = self.cors_allow_origin_regex.strip() or None
        if self.cors_env.lower() == "dev" and not origins and not regex:
            # Dev sin nube: el navegador corre en localhost (puerto efímero de Flutter web).
            regex = r"^http://(localhost|127\.0\.0\.1)(:\d+)?$"
        return {
            "allow_origins": origins,
            "allow_origin_regex": regex,
            "allow_credentials": True,
            "allow_methods": ["*"],
            "allow_headers": ["*"],
        }


@lru_cache
def get_settings() -> Settings:
    return Settings()
