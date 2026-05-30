# Mock-validator — cumple el contrato §6 mientras el validador YOLO real no existe.
# Build con contexto en la RAIZ del repo (necesita ./contract y ./mock-validator):
#   docker build -f mock-validator/Dockerfile -t mezquite/mock-validator .
FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# El contrato (frontera §6) se instala primero; el mock depende de el en runtime.
COPY contract/python /app/contract
COPY mock-validator /app/mock-validator

RUN pip install --no-cache-dir "/app/contract[redis]" /app/mock-validator

# Sin privilegios (nobody).
USER 65534:65534

# Configuracion por entorno (ver mock_validator/config.py). Defaults para nube:
ENV MOCK_BROKER=redis \
    REDIS_URL=redis://redis:6379/0 \
    MOCK_MODE=regla

CMD ["python", "-m", "mock_validator"]
