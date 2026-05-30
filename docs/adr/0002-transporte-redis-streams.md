# ADR-0002 — Transporte de la cola: Redis Streams + consumer groups

- **Estado:** aceptado (Incremento 1).
- **Contexto:** T6 sella "Redis + task queue de Python" y exige que **la frontera sea la cola** (el
  validador es *consumidor*, no un endpoint síncrono) y que el paso **mock → real** no toque cliente
  ni backend. Además, la paridad de entornos (gate #6) exige un transporte **conmutable** que corra
  sin nube en dev/QA.

## Decisión

Usar **Redis Streams con consumer groups** como transporte de referencia, detrás de una interfaz
`MessageBroker` con dos implementaciones conmutables por configuración:

- `RedisStreamsBroker` — staging/producción y dev con Redis. `XADD` / `XREADGROUP` / `XACK`.
- `InMemoryBroker` — dev/QA sin nube y pruebas deterministas; mismo contrato, en proceso.

Dos streams: `mezquite:validation_jobs` (backend→validador) y `mezquite:validation_results`
(validador→backend). Dos groups: `validators` y `backend`.

## Por qué Streams y no Celery/RQ "result backend"

- El contrato §6 modela **dos flujos de mensajes independientes**, con el validador como consumidor
  autónomo que **publica** un resultado que el backend consume por separado. Esto encaja con streams
  (publicar/suscribir con entrega *at-least-once* y *pending*), no con el modelo RPC tarea→resultado
  de Celery.
- Los **consumer groups** dan: entrega *at-least-once*, mensajes *pending* hasta `ack` (reintentos y
  *dead-letter*, §6.4) y múltiples consumidores (escalado horizontal del validador).
- El cambio **mock → real** es solo "otro proceso consume `validation_jobs`": sin tocar streams,
  backend ni clientes.

> Celery/RQ podrían introducirse luego **detrás de la misma interfaz `MessageBroker`** sin cambiar
> el código de aplicación, si se justificara.

## Consecuencias

- La **idempotencia** de aplicación (un resultado por `observation_id`) es del backend (PK en
  `validation_event`), no del broker. El broker garantiza entrega, no unicidad.
- `InMemoryBroker` permite la suite E2E de la frontera **sin Redis** (ya verde en el Incremento 1).
