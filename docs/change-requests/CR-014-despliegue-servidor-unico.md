# CR-014 — Despliegue en un solo servidor (piloto a producción, on-prem/cloud)

| Campo | Valor |
|---|---|
| **ID** | CR-014 |
| **Fecha** | 2026-06-18 |
| **Estado** | 📋 **Propuesto — formalizado** (paquete listo para infra; **sin desplegar**) |
| **Alcance** | `infra/compose/` (compose prod + Caddy + env) · `docs/` (runbook) |
| **Depende de** | CR-004 W1 (Firebase real, para auth pública) |
| **Alternativa** | [CR-008](CR-008-despliegue-azure.md) (Azure gestionado, sin K8s) |

## Decisión del usuario (2026-06-18)
El **primer piloto a producción** muy probablemente correrá **todo dentro de un solo servidor** (cualquier
cloud o servidor propio). Se pide un **paquete listo para entregar al equipo de infra**, con:
1. Artefactos ejecutables: `docker-compose.prod.yml` + `Caddyfile` + `.env.prod.example`.
2. Runbook con **requerimientos de hardware y software**, **configuración de Firebase paso a paso**
   (incluida la ejecución de `flutterfire configure`) y el procedimiento de despliegue.
3. **Build en el propio servidor** (sin exigir un registro de imágenes), **subdominios** `app.`/`admin.`,
   runbook **agnóstico de proveedor**.

## Por qué es viable sin cambios de código
El gate #6 (paridad de entornos) ya obliga a que DB, storage y broker sean **conmutables por configuración**.
Tras CR-001 la frontera YOLO está inactiva, así que el stack mínimo es pequeño: **API + PostGIS + 2 bundles
web + un reverse proxy con TLS**. `STORAGE_BACKEND=local`, `BROKER=memory` (sin Redis), `AUTH_PROVIDER=firebase`.

## Arquitectura
Un host con Docker corre `caddy` + `api` + `postgres`. Caddy termina HTTPS (Let's Encrypt) y sirve cada
bundle en su subdominio, proxyeando `/api`, `/files` y `/healthz` al backend en el **mismo origen** (CORS
deja de ser un problema). Diagrama y detalle en [`docs/DESPLIEGUE-SERVIDOR-UNICO.md`](../despliegue/DESPLIEGUE-SERVIDOR-UNICO.md).

## Entregables (este CR)
| Archivo | Qué es |
|---|---|
| `infra/compose/docker-compose.prod.yml` | Stack prod single-host (caddy + api + postgres; sin Redis/YOLO). |
| `infra/compose/Caddyfile` | Reverse proxy + estático, 2 subdominios, TLS automático, mismo-origen. |
| `infra/compose/.env.prod.example` | Plantilla de **todas** las variables (secretos marcados 🔒). |
| `docs/DESPLIEGUE-SERVIDOR-UNICO.md` | Runbook: hardware, software, Firebase (con `flutterfire configure`), build, deploy, backups, smoke test. |
| `.gitignore` | Excepción `!.env.prod.example` (el `.env.prod` real sigue ignorado). |

## Gates
- **Gate #6** (paridad): se cumple por diseño — solo configuración, sin tocar código de aplicación.
- **Gate #5** (`OBFUSCATION_GRID_M=300`), **Gate #2** (PII mínima; secretos fuera de git) explícitos en el runbook.
- **Gate #1/#3/#4/#8**: sin cambios (no toca producto).

## Dependencia / advertencia
- **Auth pública (CR-004 W1):** Google real en **web** requiere generar `firebase_options.dart`
  (`flutterfire configure`) y pasar las opciones a `Firebase.initializeApp` en `mobile/lib/main.dart`
  (hoy se llama sin opciones). El runbook §5 lo documenta paso a paso (es trabajo del equipo de desarrollo).
  Para un **piloto cerrado** se puede arrancar con `AUTH_MODE=mock`/`AUTH_PROVIDER=mock` y migrar antes de abrir.

## Estado
Paquete y runbook **creados y listos para entregar a infra**. **No se ejecuta el despliegue** (decisión y
orden del usuario; formalizar un CR ≠ ejecutarlo). Sin cambios de backend ni migración; sin pruebas nuevas
(son artefactos de infra/documentación).
