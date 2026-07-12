# `/backend` — API FastAPI del mezquite (Incremento 2)

Backend del proyecto de ciencia ciudadana del mezquite. API REST versionada (`/api/v1`), PostGIS,
productor/consumidor de la cola del **contrato §6**, etiquetado válida/ruido autoritativo,
indicadores Q6. Materializa `bitacora_sdd_mezquite.md`, `ARCHITECTURE.md` y
`docs/data-model/postgis-model.md`. **No reimplementa** la frontera: depende del paquete
`mezquite_contract` (`../contract/python`).

## Estructura

```
backend/
  app/
    config.py            Config conmutable por entorno (DATABASE_URL, STORAGE_BACKEND, BROKER, ...)
    db.py                Engine/sesión SQLAlchemy 2.0
    models.py            Modelo PostGIS (account sin PII, tree, observation, validation_event, ...)
    security.py          Auth sin PII: handle + código de respaldo (PBKDF2), JWT
    deps.py              Dependencias FastAPI de auth + rol (3 roles)
    storage.py           StorageProvider: LocalFSStorage (dev/QA) | S3CompatibleStorage (stg/prod)
    geo.py               obfuscate_to_grid (binning del heatmap, EPSG:6372), assign_tree, estado/municipio
    queue.py             Productor de la cola §6 (make_broker, ValidationJob)
    validation_apply.py  Aplicación autoritativa e idempotente del resultado (gate #9)
    indicators.py        Indicadores Q6 (sin umbrales, U1)
    gamification.py      Rankings (E3/C2), lifelist, insignias, etiqueta L3
    snapshots.py         Snapshot trimestral (Qn)
    routers/             auth, observations, me, gamification, public, restricted, admin
    main.py              create_app(); OpenAPI en /api/v1/openapi.json
  result_worker.py       Entrypoint del consumidor de resultados: python -m backend.result_worker
  alembic/               Migración inicial (extensión postgis + modelo)
  tests/                 49 pruebas pytest (PostGIS real + lógica pura)
  Dockerfile             Imagen del api y del result-worker
```

## Roles y endpoints (`/api/v1`)

`voluntario` · `aliado_firmante` · `admin_consorcio`.

| Método | Ruta | Rol |
|---|---|---|
| POST | `/auth/register`, `/auth/recover` | público (sin PII) |
| POST | `/observations` | voluntario+ (8 etiquetas + imagen; fire-and-forget) |
| GET  | `/observations/mine`, `/me/feedback`, `/me/profile` | voluntario+ |
| GET  | `/gamification/rankings` | voluntario+ |
| GET  | `/public/observations` (coords exactas), `/public/grid` (heatmap, binning de celda), `/public/indicators` | público |
| GET  | `/restricted/observations` (coords exactas) | roles de consola (CR-025) |
| POST | `/admin/indicators/organizational`, `/admin/allies`, `/admin/snapshots` | admin_consorcio |
| GET/POST | `/admin/institutions` | admin_consorcio |

## Correr en dev SIN nube (gate #6)

Requiere un PostGIS accesible. Opción rápida con contenedor:

```bash
docker run -d --rm --name mezquite-pg -e POSTGRES_USER=mezquite -e POSTGRES_PASSWORD=mezquite \
  -e POSTGRES_DB=mezquite -p 5432:5432 postgis/postgis:16-3.4

# (Windows PowerShell: usar $env:VAR en vez de export)
export DATABASE_URL="postgresql+psycopg://mezquite:mezquite@localhost:5432/mezquite"
export STORAGE_BACKEND=local        # filesystem local; sin nube
export BROKER=memory                # o redis con REDIS_URL=redis://localhost:6379/0

# migraciones
python -m alembic -c backend/alembic.ini upgrade head    # desde la raíz del repo

# API
uvicorn backend.app.main:app --reload      # http://localhost:8000/api/v1/docs

# worker de resultados (broker=redis; con memory el worker corre in-proc en pruebas)
python -m backend.result_worker
```

Conmutadores (paridad de entornos): `STORAGE_BACKEND=local|s3`, `BROKER=memory|redis`,
`DATABASE_URL`. dev/QA no requieren nube.

## Stack completo con Docker Compose

```bash
docker compose -f infra/compose/docker-compose.dev.yml up --build
```

Levanta `postgres` (PostGIS), `redis`, `api` (aplica migraciones y sirve en :8000),
`result-worker` y `mock-validator`. Lazo E2E: `api` encola jobs → `mock-validator` valida →
`result-worker` etiqueta y otorga recompensa diferida. El paso **mock → YOLO real** sustituye solo
el servicio `mock-validator` (mismo Redis, mismos streams); el backend no cambia (gate #10).

## Pruebas

```bash
cd backend && python -m pytest -q
```

Las pruebas geoespaciales/idempotencia usan un PostGIS real (`testcontainers` o `docker run`); si
Docker no está disponible se **omiten** (no fallan en falso). Las pruebas de lógica pura
(obfuscación, storage, auth/no-PII, autoridad del veredicto) corren sin DB.
