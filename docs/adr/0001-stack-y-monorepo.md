# ADR-0001 — Stack y estructura de monorepo

- **Estado:** aceptado (Incremento 1).
- **Contexto:** la bitácora §2 sella el stack (Flutter, FastAPI, PostGIS, Redis, K8s, StorageProvider
  conmutable). Falta fijar la estructura del repo y los defaults derivables no nombrados.

## Decisión

**Monorepo** con componentes desacoplados, frontera de validación compartida como paquete:

```
/contract        paquete mezquite_contract — frontera §6 (fuente de verdad), schemas + broker
/mock-validator  worker que cumple §6 mientras no existe el YOLO real
/backend         FastAPI + PostGIS (Incremento 2)
/mobile          app Flutter del voluntario (Incremento 3)
/web-admin       web app del consorcio (Incremento 4)
/infra           compose (dev) + manifiestos K8s
/docs            arquitectura: data-model, design-system, ADRs
```

**Defaults derivables adoptados** (la bitácora los deja abiertos; no son decisiones humanas):
- Migraciones de DB: **Alembic**.
- Versionado de API: prefijo `/api/v1`.
- Transporte de cola: **Redis Streams + consumer groups** (ver [ADR-0002](0002-transporte-redis-streams.md)).
- Auth: token sobre `handle` seudonimizado, **sin PII** (recuperación por código de respaldo/QR).

**Decisión diferida (derivable, no sellada):** framework de la **web admin** (Flutter Web vs.
React+Vite). Se resuelve al iniciar el Incremento 4. Criterio: maximizar reuso del design system y
simplicidad operativa del consorcio.

## Consecuencias

- El paquete `/contract` es importado por backend, mock y (futuro) validador real ⇒ no pueden
  divergir del protocolo de cable.
- Cada componente se contenedoriza por separado (coherente con T5 / RC1).
- Monorepo simplifica la trazabilidad criterio→prueba (gate #7) en un solo árbol.
