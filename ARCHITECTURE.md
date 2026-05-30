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
  `estado`, `municipio`, estado de validación (`pendiente`|`valida`|`ruido`).
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
| `POST` | `/observations` | voluntario | `submit_observation`: 8 etiquetas + imagen. Encola job, responde recompensa base (fire-and-forget). |
| `GET` | `/observations/mine` | voluntario | Historial propio (sin estado de validación individual en UI). |
| `GET` | `/me/feedback` | voluntario | Feedback **agregado** de tasa de validación. |
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

**Nota interna:** el resultado de validación **no** entra por REST; llega por la cola (§6) y lo
consume un worker del backend.

## 6. Frontera de validación (la cola)

Toda la integración con el validador es la cola + el contrato §6. Detalle y código:
[`/contract`](contract/README.md). El backend es **productor** de `validation_jobs` y
**consumidor** de `validation_results`; el **veredicto es autoritativo en el backend**
(`valida ⟺ es_arbol ∧ parasitos_presentes`). El [`mock-validator`](mock-validator/README.md)
cumple el mismo contrato hasta que exista el YOLO real.

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
| 5. Obfuscación 1 km | `/public/*` usa `ST_SnapToGrid`; exactas solo `/restricted/*` |
| 6. Paridad de entornos | `StorageProvider`, `MessageBroker`, `DATABASE_URL` conmutables |
| 7. Trazabilidad | [`TRACEABILITY.md`](TRACEABILITY.md): criterio → prueba |
| 8. Alcance validación (es-árbol + parásitos) | Esquema §6.3 con `additionalProperties:false` (rechaza especie/G4) |
| 9. Etiquetado válida/ruido | `compute_verdict` autoritativo en backend; puntos solo si válida |
| 10. Contrato §6 (mock↔real sin cambios) | Toda integración por `/contract`; `make_broker` conmutable |

## 12. Roadmap de incrementos

1. **Fundación** *(hecho)* — esta arquitectura + modelo de datos + design system + `/contract` +
   `/mock-validator` + matriz de trazabilidad. **Verificado** (30 pruebas verdes).
2. **Backend** — OpenAPI completo, FastAPI (auth, `tree_id`/obfuscación, productor/consumidor de cola,
   etiquetado, indicadores), migraciones PostGIS, `StorageProvider`, manifiestos K8s, compose con DB+API.
3. **App móvil Flutter** — captura cámara-nativa+EXIF, aprendizaje, gamificación, dashboards cliente.
4. **Web admin** — F3, indicadores organizacionales, snapshots, dashboards público/restringido
   *(resolver framework aquí)*.
5. **Tester/QA E2E** — en K8s contra el mock; cierre de la matriz de trazabilidad.
