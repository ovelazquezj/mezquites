# `/contract` — Frontera de integración con el sistema de validación de imágenes (§6)

> **Fuente de verdad.** Esta es la **única** frontera entre el software del mezquite (este repo)
> y el sistema de validación de imágenes (YOLO, repo aparte). Está espejada en la §6 de
> `bitacora_sdd_mezquite.md`. **Ninguno de los dos lados la modifica unilateralmente.**

## Qué es

Un canal **asíncrono** sobre una **cola de mensajes**. El validador es **consumidor**, nunca un
endpoint que el cliente invoque de forma síncrona.

```
backend ──XADD──▶ [mezquite:validation_jobs] ──XREADGROUP(validators)──▶ validador | mock
validador|mock ──XADD──▶ [mezquite:validation_results] ──XREADGROUP(backend)──▶ backend
```

1. El **backend** recibe `submit_observation`, persiste la observación en estado `pendiente`,
   sube la imagen vía `StorageProvider` y **encola un job** (§6.2). Responde de inmediato con la
   recompensa base (*fire-and-forget*).
2. El **validador / mock** toma el job, evalúa y **publica un resultado** (§6.3).
3. El **backend** consume el resultado, **etiqueta** la observación (`valida` | `ruido`),
   actualiza el dataset y, si es válida, otorga la **recompensa diferida**.

## Contenido del paquete `mezquite_contract`

| Módulo | Responsabilidad |
|---|---|
| `schemas/*.json` | **Esquemas JSON canónicos** (independientes de lenguaje) del job (§6.2) y el resultado (§6.3). |
| `models.py` | Modelos pydantic v2: `ValidationJob`, `ValidationResult`, `Scores`. |
| `verdict.py` | **Regla autoritativa** `compute_verdict`: `valida ⟺ es_arbol ∧ parasitos_presentes`. |
| `validation.py` | Validación de dicts contra los esquemas JSON (jsonschema, con respaldo stdlib). |
| `channels.py` | Nombres canónicos de streams y consumer groups. |
| `broker.py` | `MessageBroker` conmutable: `RedisStreamsBroker` (nube) e `InMemoryBroker` (dev/QA/pruebas). |
| `version.py` | `SCHEMA_VERSION = "1.0"`. |

## Reglas que el contrato impone (gates de la bitácora)

- **Alcance (§6.3, gate #8):** el resultado contiene **solo** `es_arbol` + `parasitos_presentes`.
  No hay campo de especie ni de nivel G4 — `additionalProperties: false` los **rechaza**.
- **Autoridad del backend (§6.3, gate #9):** el campo `veredicto` del mensaje viaja por
  consistencia, pero el backend usa `ValidationResult.authoritative_verdict` (recomputado). Nunca
  confía ciegamente en el `veredicto` recibido; `is_consistent` permite detectar productores con bug.
- **Idempotencia (§6.4):** el resultado se aplica **una sola vez** por `observation_id`. Es
  responsabilidad del **backend** (dedup al aplicar); el broker garantiza entrega *at-least-once*.
- **Pendiente/reintentos (§6.4):** un job no procesado queda `pendiente` (no se auto-etiqueta);
  el broker lo mantiene en *pending* hasta el `ack`.
- **Versionado (§6.4):** `schema_version` viaja en cada mensaje; cambios versionados y compatibles.

## Uso

```python
from mezquite_contract.models import ValidationJob
from mezquite_contract.broker import make_broker
from mezquite_contract.channels import JOBS_STREAM

broker = make_broker("redis", url="redis://localhost:6379/0")   # o "memory" en dev/QA
job = ValidationJob(observation_id=obs_id, image_ref=key, captured_at=ts, lat=lat, lon=lon)
broker.publish(JOBS_STREAM, job.to_message())
```

## Pruebas

```bash
cd contract/python
python -m pytest -q
```

Cubren: tabla de verdad del veredicto, round-trip de modelos, rechazo de campos fuera de alcance
(especie / G4), versionado y semántica del broker.

## Cambiar el transporte (paridad de entornos)

`make_broker("memory")` y `make_broker("redis", url=...)` exponen el **mismo** contrato. El
software de aplicación no cambia entre dev/QA (memory) y staging/producción (redis). El paso
**mock → validador real** tampoco toca este paquete: solo cambia *qué proceso* consume
`mezquite:validation_jobs`.
