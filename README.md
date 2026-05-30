# Software — Proyecto de ciencia ciudadana del mezquite

Software del piloto de ciencia ciudadana del **mezquite** (*Prosopis laevigata*) y sus parásitos
visibles. Tres clientes + backend, integrados con un **sistema externo de validación de imágenes**
(YOLO, otro repo) únicamente por la cola y el **contrato §6**.

> **Fuente de verdad:** [`bitacora_sdd_mezquite.md`](bitacora_sdd_mezquite.md). Las decisiones
> selladas no se reabren. La arquitectura que las materializa está en [`ARCHITECTURE.md`](ARCHITECTURE.md).
> El **Protocolo de ciencia ciudadana** y el **Documento de presentación** son entregables aparte.

## Qué es y qué no es

- **Es** una plataforma de **concientización y observación** ciudadana, estilo eBird: registro
  abierto, sin certificación, sin gating, dataset de acceso abierto con caveat de origen ciudadano.
- **No** promete control fitosanitario directo, reducción medible de infestación, ni recomendaciones
  de manejo químico/mecánico autónomas (boundary Q1).
- **No** captura PII: cuenta seudonimizada por handle.

## Estructura del monorepo

| Carpeta | Qué es | Estado |
|---|---|---|
| [`contract/`](contract/README.md) | `mezquite_contract` — **frontera §6** (fuente de verdad): schemas, modelos, regla de veredicto, broker conmutable | ✅ Inc 1 |
| [`mock-validator/`](mock-validator/README.md) | Worker que cumple §6 mientras no existe el YOLO real (modos fijo/aleatorio/regla + latencia) | ✅ Inc 1 |
| [`backend/`](backend/README.md) | FastAPI + PostGIS: API REST, auth 3 roles sin PII, `tree_id`/obfuscación, productor/consumidor de cola, indicadores | ✅ Inc 2 |
| `mobile/` | App Flutter del voluntario | ⏳ Inc 3 |
| `web-admin/` | Web app del consorcio | ⏳ Inc 4 |
| [`infra/`](infra/compose/docker-compose.dev.yml) | Compose (dev sin nube) + manifiestos K8s | 🟡 Inc 1–2 |
| [`docs/`](ARCHITECTURE.md) | Arquitectura: [data-model](docs/data-model/postgis-model.md), [design-system](docs/design-system/design-tokens.md), [ADRs](docs/adr/) | ✅ Inc 1 |
| [`TRACEABILITY.md`](TRACEABILITY.md) | Matriz criterio de aceptación → prueba (gate #7) | ✅ vivo |

## Quickstart (Incremento 1, sin nube)

Requiere Python ≥ 3.11 (con `pydantic`, `jsonschema`, `redis`, `pytest`).

```bash
# 1) Pruebas de la frontera (contrato) — sin Redis
cd contract/python && python -m pytest -q

# 2) Pruebas del mock + lazo E2E de la frontera contra el mock — sin Redis
cd ../../mock-validator && python -m pytest -q

# 3) Stack dev con broker real (Redis) + mock-validator
docker compose -f infra/compose/docker-compose.dev.yml up --build
```

## Gates innegociables

El Orquestador rechaza cualquier violación de: boundary Q1 · sin PII · sin gating · captura
cámara-nativa+EXIF · obfuscación 1 km · paridad de entornos · trazabilidad · alcance de validación
(solo es-árbol + presencia-de-parásitos) · etiquetado válida/ruido autoritativo en backend ·
integración solo por el contrato §6 (mock↔real sin tocar cliente ni backend). Detalle y estado en
[`ARCHITECTURE.md` §11](ARCHITECTURE.md) y [`TRACEABILITY.md`](TRACEABILITY.md).

## Estado

**Incrementos 1 (Fundación) y 2 (Backend) completos y verificados:** 79 pruebas verdes
(21 contrato + 9 mock + 49 backend con PostGIS real) + E2E en vivo por compose (submit → mock →
etiquetado → recompensa diferida). Siguiente: Incremento 3 (app móvil Flutter) y manifiestos K8s.
