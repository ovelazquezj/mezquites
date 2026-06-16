# Arquitectura del software — Proyecto de ciencia ciudadana del mezquite

> **Fuente de verdad:** `bitacora_sdd_mezquite.md`. Este documento **materializa** sus decisiones
> selladas (§1, §2) en una arquitectura concreta. No reabre decisiones; donde la bitácora deja un
> default derivable, lo fija aquí y lo marca; donde deja una *decisión humana pendiente*, la
> referencia sin inventarla.

## 1. Alcance del software

Tres clientes + backend compartido, integrados con un **sistema externo de validación de imágenes**
únicamente por la cola y el **contrato §6** (ver [`/contract`](contract/README.md)):

- **App móvil del voluntario** (Flutter) — captura cámara-nativa + EXIF, aprendizaje, gamificación,
  comunidad, dashboards cliente.
- **Web app de administración del consorcio** — F3, indicadores organizacionales, aliados firmantes,
  snapshots trimestrales, dashboards público vs. restringido.
- **Backend** (FastAPI) — API REST para ambos clientes; auth de 3 roles sin PII; `tree_id` /
  obfuscación; productor/consumidor de la cola; etiquetado válida/ruido; indicadores Q6 y nivel L3.

**Fuera de alcance (otro repo):** el sistema de validación de imágenes (YOLO). Aquí solo vive la
**frontera** (cola + contrato §6) y un **mock** que la cumple.

## 2. Mapa de componentes

```
        ┌─────────────────────┐        ┌──────────────────────────┐
        │  App móvil (Flutter) │        │  Web admin (consorcio)   │
        │  voluntario          │        │  F3, indicadores, snaps  │
        └──────────┬──────────┘        └────────────┬─────────────┘
                   │ REST/HTTPS (OpenAPI, versionada) │
                   └──────────────┬──────────────────┘
                                  ▼
                       ┌─────────────────────┐     StorageProvider
                       │   Backend (FastAPI) │────▶ local FS (dev/QA)
                       │  auth 3 roles s/PII │     S3-compatible (stg/prod)
                       │  tree_id, obfusc.   │
                       └───┬─────────────┬───┘
                  productor│             │consumidor
              (validation_ │             │ (validation_
                  jobs)    ▼             ▲   results)
                       ┌─────────────────────┐
                       │   Broker (Redis     │   ← MessageBroker conmutable
                       │   Streams, grupos)  │     (memory en dev/QA)
                       └──────────┬──────────┘
                                  │  contrato §6 (frontera)
                                  ▼
                ┌─────────────────────────────────────┐
                │  Validador de imágenes (OTRO REPO)  │
                │  • mock-validator (este repo, §6.5) │
                │  • YOLO real (track aparte)         │
                └─────────────────────────────────────┘

        DB: PostgreSQL + PostGIS  (tree_id radio 10 m, grid 1 km, dim estado/municipio)
```

## 3. Stack y defaults adoptados

| Tema | Decisión sellada (bitácora) | Materialización concreta | Nota |
|---|---|---|---|
| Cliente móvil | Flutter, un código base (T1) | Flutter (Android primario, iOS por el mismo código) | SDK Flutter = pendiente de tooling local |
| Backend | Python + FastAPI, REST versionada (T2) | FastAPI; prefijo `/* /api/v1`; OpenAPI autogenerado | — |
| Base de datos | PostgreSQL + PostGIS (T3) | PostgreSQL 16 + PostGIS 3; migraciones con **Alembic** | Alembic = default derivable |
| Almacenamiento | `StorageProvider` conmutable (T4) | Interfaz con impl `LocalFS` (dev/QA) y `S3Compatible` (stg/prod) | DB guarda clave/URL, no binario |
| Cola / integración | Redis + task queue, frontera = la cola (T6) | **Redis Streams + consumer groups** tras `MessageBroker` (impl `memory` para dev/QA) | Ver [ADR-0002](docs/adr/0002-transporte-redis-streams.md) |
| Hosting | Contenedores + K8s, dev en minikube/Rancher (T5) | Manifiestos K8s base + overlays; dev en Rancher Desktop | minikube no instalado; Rancher Desktop provee el clúster |
| Auth | Cuenta seudonimizada por handle, sin PII (Q5.D-D1) | Token opaco/JWT sobre `handle` + secreto; **sin** email/teléfono | Recuperación por código de respaldo / QR (hash) |
| UI/UX | Minimalista tipo eBird; Rotary azul+dorado + verdes (T7) | Design system de tokens compartido | Hex exactos = **token pendiente** (guía de marca Rotary) |
| **Web admin (framework)** | "web app de administración" — framework **no** sellado | **DECISIÓN DIFERIDA** al Incremento 4 | Candidatos: Flutter Web (máximo reuso del design system) vs. React+Vite. Se resuelve al iniciar el cliente admin |

## 4. Modelo de datos (PostGIS)

Detalle en [`docs/data-model/postgis-model.md`](docs/data-model/postgis-model.md). Núcleo:

- **`observation`** — 8 etiquetas de captura (Q2): foto (clave de storage), EXIF lat/lon/timestamp,
  nivel G4, flag cúscuta, flag daño, tamaño, contexto, handle; `tree_id`, `observation_seq`,
  `estado`, `municipio`, **`estado_revision`** (`aceptada`|`confirmada`|`rechazada`; CR-001).
- **`human_review`** (CR-001) — log append-only de veredictos humanos: `observation_id`,
  `reviewer_account_id`, `veredicto`, `nota`, `created_at` (gate #7). El estado actual vive en
  `observation.estado_revision`; `validation_event` se conserva pero ya no se escribe.
- **`tree`** — identidad de árbol por **radio 10 m** (R3); serie temporal con **gap > 30 días**.
- **Obfuscación** — vista pública a **grid 1 km** (`ST_SnapToGrid`); coords exactas solo a rol
  `aliado_firmante`.
- **Dimensión geográfica** — `estado`/`municipio` derivables del EXIF (join espacial a límites
  administrativos); habilita filtros y escalamiento (Q8) sin re-arquitectura.
- **Cuenta sin PII** — `account(handle, recovery_hash, role, institution_id)`.

## 5. Contrato REST/OpenAPI (esquema; YAML completo = Incremento 2)

Prefijo `/api/v1`. OpenAPI servido por FastAPI en `/api/v1/openapi.json`. **3 roles:**
`voluntario`, `aliado_firmante`, `admin_consorcio`.

| Método | Ruta | Rol | Propósito |
|---|---|---|---|
| `POST` | `/auth/register` | público | Crea handle seudonimizado; devuelve token + código de respaldo. Sin PII. |
| `POST` | `/auth/recover` | público | Recuperación por código de respaldo / QR. |
| `POST` | `/observations` | voluntario | `submit_observation`: 8 etiquetas + imagen. **CR-001:** persiste `estado_revision='aceptada'`, otorga puntos base + diferida al subir; **ya no encola job**. |
| `GET` | `/observations/mine` | voluntario | Historial propio (sin estado de validación individual en UI). |
| `GET` | `/me/feedback` | voluntario | Resumen **agregado** de aportaciones (no-rechazadas). |
| `GET` | `/me/profile` | voluntario | Lifelist, etiqueta de identidad L3, insignias. |
| `GET` | `/gamification/rankings` | voluntario | Rankings por periodo (individual + institución). |
| `GET` | `/learning/*` | voluntario | Contenidos AU2 (sin gating). |
| `GET` | `/public/observations` | público | Coords **obfuscadas a 1 km**; handle por observación; "última actualización Qn". |
| `GET` | `/public/indicators` | público | Indicadores social/educativo/ecológico (Q6). |
| `GET` | `/restricted/observations` | aliado_firmante | Coords **exactas** (requiere auth de firmante). |
| `POST` | `/admin/indicators/organizational` | admin_consorcio | Captura manual de indicadores organizacionales (Q6 amendment). |
| `POST` | `/admin/allies` | admin_consorcio | Alta/gestión de aliados firmantes y permisos de coords exactas. |
| `POST` | `/admin/snapshots` | admin_consorcio | Snapshot trimestral del dataset público. |
| `*` | `/admin/institutions` | admin_consorcio | Lista F3 + "solicitar agregar" (ticket a EA3). |
| `GET` | `/review/queue` | evaluador, analista, administrador | Cola de revisión (filtros + paginación; sin coord exacta). |
| `GET` | `/review/observations/{id}` | evaluador, analista, administrador | Detalle + historial `human_review` (sin coord exacta). |
| `GET` | `/review/observations/{id}/image` | evaluador, analista, administrador, aliado_firmante | Sirve la imagen; **EXIF GPS saneado** salvo `aliado_firmante` (gate #5). |
| `POST` | `/review/observations/{id}/verdict` | evaluador, administrador | Veredicto humano (`confirmada`/`rechazada`); escribe `human_review` y `estado_revision`. |
| `GET` | `/review/stats` | evaluador, analista, administrador | Conteos por `estado_revision` + throughput (Monitor). |

## 6. Revisión humana (CR-001) y frontera de validación (inactiva)

**Modelo vigente (CR-001, 2026-06-15):** la calidad se decide por **revisión humana** desde la web
admin. Toda observación nace `aceptada` (visible + con puntos); un revisor (`evaluador`/
`administrador`) la **confirma** o **rechaza** vía `/review/.../verdict`. El veredicto es
**autoritativo en el backend** y queda en el log append-only `human_review` (gate #7). El dataset
público = `estado_revision <> 'rechazada'`. Gate #5: la imagen de revisión se sirve con **EXIF GPS
saneado** (`app/exif.py`) salvo `aliado_firmante`.

**Frontera §6 (inactiva, conservada).** La integración con el validador externo (cola + contrato §6 +
[`mock-validator`](mock-validator/README.md)) **no se borra** pero queda **ociosa**: el submit ya no
encola y `validation_apply`/`result_worker` no se ejecutan (compose los pone tras el perfil `yolo`).
Si en el futuro se reactiva la validación automática, el paso mock→real sigue sin tocar cliente ni
backend. Detalle del contrato: [`/contract`](contract/README.md).

## 7. `StorageProvider`

Interfaz mínima: `put(key, bytes) -> ref`, `get(key) -> bytes`, `url(key) -> str`, `delete(key)`.
Implementaciones: `LocalFSStorage` (dev/QA) y `S3CompatibleStorage` (stg/prod). La DB guarda solo
la clave/URL. Conmutable por config (`STORAGE_BACKEND=local|s3`). *(Se materializa en el Incremento 2.)*

## 8. Paridad de entornos

Todo componente con dependencia de infraestructura se abstrae tras una interfaz conmutable por config,
para que **dev/QA corran sin nube**.

| Recurso | dev / QA (sin nube) | staging / producción (nube) | Conmutador |
|---|---|---|---|
| Storage | Filesystem local | Object storage S3-compatible | `STORAGE_BACKEND` |
| Broker | `InMemoryBroker` / Redis local | Redis gestionado | `BROKER` / `MOCK_BROKER` |
| DB | PostGIS en contenedor | PostGIS gestionado | `DATABASE_URL` |
| Validador | `mock-validator` | YOLO real (otro repo) | qué worker consume la cola |

## 9. Despliegue (Kubernetes)

Contenedores por componente (API, worker de resultados, mock-validator, DB, Redis). Manifiestos base
+ overlays por entorno (kustomize). Dev en **Rancher Desktop** (clúster K8s local ya disponible;
`minikube` opcional). Arquitectura **centralizada RC1**: una app, un dataset, un backend, una web admin;
los estados son filtros geográficos, no infraestructura nueva. *(Manifiestos = Incremento 2.)*

## 10. Design system

Tokens compartidos móvil + web admin en [`docs/design-system/`](docs/design-system/design-tokens.md)
(`design-tokens.json` legible por máquina). Estética minimalista tipo eBird; paleta Rotary
(azul royal + dorado) + verdes ecológicos. **Valores hex finales = pendientes de la guía de marca
oficial de Rotary** (los actuales son provisionales y están marcados como tales).

## 11. Dónde se hacen cumplir los gates

| Gate | Dónde se hace cumplir |
|---|---|
| 1. Boundary Q1 (no control fitosanitario) | Sin endpoints/UI de recomendación; revisión de copy por el Orquestador |
| 2. Sin PII | `account` sin email/teléfono/nombre; `/auth/register` no pide PII |
| 3. Sin gating | Ningún endpoint exige nivel/capacitación; gamificación sin multiplicadores |
| 4. Captura cámara-nativa + EXIF | App fuerza cámara; galería deshabilitada; backend exige EXIF |
| 5. Obfuscación 1 km | `/public/*` usa `ST_SnapToGrid`; exactas solo `/restricted/*`. **CR-001:** imagen de revisión con **EXIF GPS saneado** (`app/exif.py`) salvo `aliado_firmante` |
| 6. Paridad de entornos | `StorageProvider`, `MessageBroker`, `DATABASE_URL` conmutables |
| 7. Trazabilidad | [`TRACEABILITY.md`](TRACEABILITY.md): criterio → prueba; log `human_review` |
| 8. ~~Alcance validación automática~~ | **Enmendado (CR-001):** sin validación automática; calidad por revisión humana. Backend sigue sin validar especie/G4 |
| 9. ~~Etiquetado válida/ruido~~ | **Reemplazado (CR-001):** aceptación por defecto + veredicto humano autoritativo en backend (`/review/.../verdict`) |
| 10. ~~Contrato §6 (mock↔real)~~ | **Inactivo (CR-001):** frontera §6 conservada pero ociosa; el submit ya no encola |

## 12. Roadmap de incrementos

1. **Fundación** *(hecho)* — esta arquitectura + modelo de datos + design system + `/contract` +
   `/mock-validator` + matriz de trazabilidad. **Verificado** (30 pruebas verdes).
2. **Backend** — OpenAPI completo, FastAPI (auth, `tree_id`/obfuscación, productor/consumidor de cola,
   etiquetado, indicadores), migraciones PostGIS, `StorageProvider`, manifiestos K8s, compose con DB+API.
3. **App móvil Flutter** — captura cámara-nativa+EXIF, aprendizaje, gamificación, dashboards cliente.
4. **Web admin** — F3, indicadores organizacionales, snapshots, dashboards público/restringido
   *(resolver framework aquí)*.
5. **Tester/QA E2E** — en K8s contra el mock; cierre de la matriz de trazabilidad.
