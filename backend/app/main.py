"""Aplicación FastAPI (T2). API REST versionada en /api/v1; OpenAPI en /api/v1/openapi.json.

Boundary Q1 (gate #1): esta API expone SOLO observación/datos. NINGÚN endpoint promete control
fitosanitario, reducción de infestación ni recomendaciones químicas/mecánicas.
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

from .config import get_settings
from .routers import (
    accounts,
    admin,
    analytics,
    auth,
    gamification,
    geo,
    institutions,
    me,
    observations,
    problem_reports,
    public,
    restricted,
    review,
    users,
)

API_PREFIX = "/api/v1"


def create_app() -> FastAPI:
    # CR-027: falla al arrancar si el entorno no-dev conserva configuración insegura (hoy, el
    # AUTH_SECRET por defecto, que es público).
    get_settings().validate_for_environment()

    app = FastAPI(
        title="Mezquite — API de ciencia ciudadana",
        version="0.1.0",
        description=(
            "Backend del proyecto de ciencia ciudadana del mezquite. Observación y datos "
            "únicamente (boundary Q1: sin control fitosanitario ni recomendaciones de manejo). "
            "Sin PII (gate #2). Validación automática limitada a es-árbol + presencia de "
            "parásitos vía el contrato §6."
        ),
        openapi_url=f"{API_PREFIX}/openapi.json",
        docs_url=f"{API_PREFIX}/docs",
        redoc_url=f"{API_PREFIX}/redoc",
    )

    # CORS (CR-004 W3): el navegador (web admin + FE web del voluntario, CR-005) habla con la API
    # sin el workaround `--disable-web-security` de Chrome. Orígenes por entorno (gate #6: config),
    # nunca `*` con credenciales en prod (ver Settings.cors_kwargs).
    app.add_middleware(CORSMiddleware, **get_settings().cors_kwargs())

    for router in (
        auth.router,
        observations.router,
        me.router,
        gamification.router,
        institutions.router,
        geo.router,
        public.router,
        restricted.router,
        review.router,
        admin.router,
        analytics.router,
        users.router,
        accounts.router,
        problem_reports.router,
    ):
        app.include_router(router, prefix=API_PREFIX)

    @app.get("/healthz", tags=["meta"])
    def healthz() -> JSONResponse:
        return JSONResponse({"status": "ok"})

    # En dev/QA con storage local, servir las imágenes desde el filesystem (S3 usa presigned URLs).
    #
    # ⚠️ CR-027: esta ruta NO exige token — sirve la foto a quien tenga la clave. Nació como
    # comodidad de dev/QA, pero quedaba montada también en producción, donde el Caddyfile la
    # publicaba en ambos dominios: los mismos bytes que `/review/observations/{id}/image` protege
    # por rol salían por aquí sin rol alguno, sin caducidad y sin forma de revocarlos. Ningún
    # cliente la consume (las apps usan el endpoint autenticado), así que se restringe a dev y se
    # retira del Caddyfile. Ambas medidas son independientes a propósito.
    settings = get_settings()
    if settings.storage_backend.lower() == "local" and settings.is_dev:
        from pathlib import Path

        base_url = settings.storage_public_base_url.rstrip("/")
        root = Path(settings.storage_local_dir)

        @app.get(base_url + "/{key:path}", tags=["meta"], include_in_schema=False)
        def serve_local_file(key: str):
            path = (root / key).resolve()
            if root.resolve() not in path.parents or not path.is_file():
                return JSONResponse({"detail": "no encontrado"}, status_code=404)
            return FileResponse(path)

    return app


app = create_app()
