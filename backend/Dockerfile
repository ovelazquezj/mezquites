# Backend FastAPI del mezquite. Build con contexto en la RAÍZ del repo (necesita ./contract y
# ./backend, igual que mock-validator/Dockerfile):
#   docker build -f backend/Dockerfile -t mezquite/backend .
FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Dependencias de sistema para psycopg/GeoAlchemy y pyproj (proj) en runtime.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 proj-bin \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# El contrato (frontera §6) se instala primero; el backend depende de él.
COPY contract/python /app/contract
COPY backend /app/backend

# Instala el contrato (con redis para el broker) y el backend.
RUN pip install --no-cache-dir "/app/contract[redis]" \
    && pip install --no-cache-dir /app/backend

# El paquete `backend` debe ser importable como tal (alembic env.py + entrypoints).
ENV PYTHONPATH=/app

# Defaults para nube; en dev/QA el compose los sobreescribe (storage local, broker redis local).
ENV DATABASE_URL=postgresql+psycopg://mezquite:mezquite@postgres:5432/mezquite \
    STORAGE_BACKEND=local \
    STORAGE_LOCAL_DIR=/data/storage \
    BROKER=redis \
    REDIS_URL=redis://redis:6379/0

EXPOSE 8000

# Aplica migraciones y arranca la API. (El result-worker usa su propio comando en compose.)
CMD ["sh", "-c", "alembic -c /app/backend/alembic.ini upgrade head && uvicorn backend.app.main:app --host 0.0.0.0 --port 8000"]
