# `/mock-validator` — Validador simulado que cumple el contrato §6

Worker que ocupa el lugar del sistema YOLO real **mientras éste no existe** (§6.5, Q5.A-D2).
Consume jobs (§6.2), evalúa con un *modo* configurable, simula latencia y publica resultados
(§6.3) con `model_version="mock"`.

> **Invariante de diseño:** el paso **mock → validador real** NO toca al backend ni a los
> clientes. Solo cambia qué proceso consume `mezquite:validation_jobs`. Este worker existe para
> probar la integración E2E contra esa frontera.

## Modos de evaluación (`MOCK_MODE`)

| Modo | Comportamiento | Para qué sirve |
|---|---|---|
| `fijo` | Devuelve siempre `(es_arbol, parasitos)` fijos. | Forzar válida/ruido en pruebas deterministas. |
| `aleatorio` | Booleanos por probabilidad independiente (`MOCK_P_*`). | Cargas mixtas; reproducible con `MOCK_SEED`. |
| `regla` *(default)* | Determinista por `observation_id` (hash). La **misma** observación obtiene **siempre** el mismo veredicto. | Integración reproducible end-to-end. |

Ninguno produce especie ni nivel G4 (fuera de alcance, Q5.A-D1).

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `MOCK_MODE` | `regla` | `fijo` \| `aleatorio` \| `regla`. |
| `MOCK_BROKER` | `redis` | `redis` \| `memory`. |
| `REDIS_URL` | `redis://localhost:6379/0` | Conexión Redis. |
| `MOCK_FIXED_ES_ARBOL` / `MOCK_FIXED_PARASITOS` | `true` / `true` | Modo `fijo`. |
| `MOCK_P_ES_ARBOL` / `MOCK_P_PARASITOS` | `0.8` / `0.6` | Modo `aleatorio`. |
| `MOCK_REGLA_P_ES_ARBOL` / `MOCK_REGLA_P_PARASITOS` | `0.85` / `0.55` | Modo `regla`. |
| `MOCK_SEED` | — | Semilla para `aleatorio`. |
| `MOCK_LATENCY_MS_MIN` / `MOCK_LATENCY_MS_MAX` | `50` / `250` | Latencia simulada (uniforme). |
| `MOCK_MODEL_VERSION` | `mock` | Valor de `model_version` en el resultado. |
| `MOCK_CONSUMER_NAME` | `mock-1` | Nombre del consumidor en el group. |

## Ejecutar

```bash
# Local contra Redis
REDIS_URL=redis://localhost:6379/0 MOCK_MODE=regla python -m mock_validator

# Stack dev completo (Redis + mock) sin nube
docker compose -f infra/compose/docker-compose.dev.yml up --build

# Docker (build desde la raíz del repo)
docker build -f mock-validator/Dockerfile -t mezquite/mock-validator .
```

## Pruebas

```bash
cd mock-validator
python -m pytest -q
```

`tests/test_worker_e2e.py` ejecuta el **lazo completo de la frontera** (backend produce job →
mock valida → backend consume resultado) sobre el broker en memoria, sin Redis, y verifica que
el backend etiqueta válida/ruido de forma autoritativa (§6.3).
