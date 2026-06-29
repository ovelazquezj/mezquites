# CR-022 — Cada foto registra su propio árbol (ENMIENDA a R3 / T3, selladas)

| Campo | Valor |
|---|---|
| **ID** | CR-022 |
| **Fecha** | 2026-06-28 |
| **Estado** | ✅ Implementado en `main` (local), pendiente de desplegar |
| **Alcance** | `backend/` |
| **Relación** | ⚠️ **ENMIENDA a una decisión SELLADA** — regla **R3** (Q2-D1) / criterio **T3** (agrupación a 10 m) |
| **Ejecución** | Directo sobre `main`, por el orquestador |

> ⚠️ **Esto es una ENMIENDA a una decisión SELLADA de la bitácora** (R3 / T3: agrupación de
> observaciones dentro de 10 m bajo un mismo `tree_id`), **autorizada por el usuario el 2026-06-28**, en
> la misma línea en que **CR-001/CR-002** enmendaron gates sellados. La decisión original **no se borra**;
> se anota la enmienda con su fecha y motivo (ver §3 de la bitácora, Q2-D1 y T3).

## 1. Contexto y decisión del usuario

En campo se percibía que **"no se registraban todos los árboles"**. El backend **nunca** bloqueaba
capturas duplicadas, pero `assign_tree` **agrupaba** las observaciones dentro de **10 m** bajo un mismo
`tree_id` (regla **R3**, criterio **T3**, **sellados** en la bitácora). Visualmente, varias capturas de
árboles cercanos colapsaban en un solo árbol.

**Decisión humana (2026-06-28):** **cada observación crea su propio árbol** (asignación **1:1**). **No es
una eliminación**: se conserva el concepto de árbol, la tabla `tree` y el mapa; solo cambia la regla de
asignación.

## 2. Por qué es aceptable el trade-off

- **Consecuencia:** se **pierde la serie temporal por árbol** — revisitas al mismo árbol físico ahora
  generan árboles distintos (ya no se agrupan ni encadenan por `observation_seq`).
- **Atenuante:** el **ruido del GPS de celular (~3–10 m)** ya hacía esa re-agrupación a 10 m **poco
  fiable**; en la práctica agrupaba/separaba árboles de forma inconsistente.
- **Mapa público:** el mapa de calor agrega por **celda de 300 m**, **no** por árbol → **no se ve
  afectado** por este cambio.

## 3. Qué se hizo

| Pieza | Detalle |
|---|---|
| `assign_tree` | Ahora **siempre crea un `Tree` nuevo**; se **quitó** la reutilización por `ST_DWithin` (10 m). |
| `observation_seq` | Queda en **1** por captura (cada árbol tiene una sola observación). |
| `test_tree_grouping.py` | **Reescrito**: dos observaciones cercanas → **2 árboles** (antes esperaba 1). |
| Mapa de calor | Sin cambios — agrega por celda de 300 m, ajeno al `tree_id`. |

## 4. Gates

- **Sin violaciones nuevas.**
- **Gate #5 (obfuscación):** **intacto** — el público sigue viendo celdas de 300 m; el cambio es de
  agrupación interna, no de exposición de coords.
- Resto de gates: sin cambios.

## 5. Enmienda de la bitácora

Registrada en `docs/sdd/bitacora_sdd_mezquite.md` con el mismo estilo que CR-001/CR-009:

- **Q2-D1 (R3, "Revisitas"):** nota *"Enmendado por CR-022 (2026-06-28)…"* junto a la regla de
  agrupación a 10 m.
- **T3 (criterio de aceptación):** nota análoga sobre la consulta que agrupaba dentro de 10 m.

El texto sellado original **no se borra**; solo se añade la nota de enmienda.

## 6. Pruebas / verificación

- `backend/tests/test_tree_grouping.py` reescrito → **2 árboles** para dos observaciones cercanas, contra
  PostGIS real.
- Suite backend verde tras el cambio (**144**).

## 7. Notas

- Si más adelante se quisiera recuperar la serie temporal por árbol con una identidad estable, requeriría
  una señal mejor que el GPS de celular (p. ej. un identificador físico del árbol) — decisión humana
  futura, fuera del alcance de este CR.
