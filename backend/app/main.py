"""Aplicación FastAPI (T2). API REST versionada en /api/v1; OpenAPI en /api/v1/openapi.json.

Boundary Q1 (gate #1): esta API expone SOLO observación/datos. NINGÚN endpoint promete control
fitosanitario, reducción de infestación ni recomendaciones químicas/mecánicas.
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.responses import FileResponse, JSONResponse

from .config import get_settings
from .routers import (
    accounts,
    admin,
    auth,
    gamification,
    institutions,
    me,
    observations,
    public,
    restricted,
    review,
    users,
)

API_PREFIX = "/api/v1"


def create_app() -> FastAPI:
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

    for router in (
        auth.router,
        observations.router,
        me.router,
        gamification.router,
        institutions.router,
        public.router,
        restricted.router,
        review.router,
        admin.router,
        users.router,
        accounts.router,
    ):
        app.include_router(router, prefix=API_PREFIX)

    @app.get("/healthz", tags=["meta"])
    def healthz() -> JSONResponse:
        return JSONResponse({"status": "ok"})

    # En dev/QA con storage local, servir las imágenes desde el filesystem (S3 usa presigned URLs).
    settings = get_settings()
    if settings.storage_backend.lower() == "local":
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
