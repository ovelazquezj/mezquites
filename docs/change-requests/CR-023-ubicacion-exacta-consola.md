# CR-023 — Ubicación EXACTA en la consola de administración (mapa + tabla + CSV) para reportes

> **Superado en parte por CR-025 (2026-07-12):** la ubicación exacta deja de ser "uso interno restringido":
> pasa a ser **pública** y disponible para **todos** los roles de consola (`EXACT_LOCATION_ROLES` +=
> `evaluador`). Se conserva el toggle calor⇄exacto pero se retira el banner de "uso interno". Ver
> `CR-025-ubicacion-exacta-publica.md`.

| Campo | Valor |
|---|---|
| **ID** | CR-023 |
| **Fecha** | 2026-07-02 |
| **Estado** | ✅ Integrado en `main` (local), pendiente de desplegar |
| **Alcance** | `backend/` · `web-admin/` (la app móvil y la vista pública **no** se tocan) |
| **Relación** | ⚠️ **ENMIENDA ACOTADA al gate #5** (obfuscación) — amplía el conjunto de roles con acceso a coords exactas **dentro de la consola autenticada** · complementa CR-009 (300 m) y CR-010/CR-011 (mapa + CSV de la consola) |
| **Ejecución** | Directo sobre `main`, por el orquestador |

> ⚠️ **Esto es una ENMIENDA ACOTADA a un gate SELLADO** (gate #5, obfuscación), **autorizada por el
> usuario el 2026-07-02**, en la misma línea en que CR-009 lo enmendó (1 km → 300 m). La decisión
> original **no se borra**; se anota la enmienda con su fecha y motivo en la bitácora (gate #5 y
> Q5.B-D1). **La vista pública NO cambia:** sigue viendo solo la celda agregada de 300 m.

## 1. Contexto y motivación (desde el campo)

Con CR-009/CR-010 el mapa de calor y el CSV de la consola quedaron **obfuscados a 300 m** para
**todos** los roles internos salvo `aliado_firmante`. En la práctica, cuando el **`administrador`** y el
**`analista`** preparan **reportes** para autoridades, universidades y el propio Club, necesitan
**capturas de pantalla que muestren la distribución EXACTA** de los árboles (dónde está cada mezquite
afectado), no solo la nube de celdas de 300 m. Hoy no pueden: la única forma de ver coords exactas es
ser `aliado_firmante`, un rol pensado para el acuerdo de uso con aliados externos, no para la operación
interna de reportes.

La protección de gate #5 se sostiene por **protección del árbol** (tala oportunista/vandalismo), **no**
por privacidad del voluntario (no se captura PII). Esa protección se dirige al **público**; **dentro de
la consola autenticada** el riesgo es operativo y se cubre con una salvaguarda de uso.

## 2. Decisión del usuario (2026-07-02)

Ampliar el acceso a **ubicación exacta** —solo **dentro de la consola autenticada**— a los roles
administrativos y de análisis, para poder **presentar reportes**:

- **Nuevo conjunto de roles con acceso a coords exactas:**
  `EXACT_LOCATION_ROLES = (aliado_firmante, administrador, admin_consorcio, analista)`.
  Antes: **solo** `aliado_firmante`.
- **NO se incluyen** `voluntario` ni `evaluador` (el `evaluador` sigue viendo solo celda/obfuscado, en
  línea con la salvaguarda de CR-001 de saneo de EXIF GPS al servir imágenes de revisión).
- **El público NO cambia:** la app móvil, la web pública, `GET /public/grid` y `GET /public/observations`
  siguen exponiendo **únicamente la celda de 300 m**. **Ningún endpoint público** expone coords exactas.
- **Salvaguarda operativa:** el mapa arranca por defecto en **modo calor 300 m**; el modo exacto se
  activa a propósito y muestra un **banner de "uso interno para reportes — no publicar sin obfuscar"**.
  Qué se publica es una **responsabilidad operativa** (gobernanza humana), no un candado de software.

## 3. Gate afectado — enmienda ACOTADA al gate #5

- **Gate #5 (obfuscación):** **enmendado (acotado)**. La regla pública **sigue intacta** (celda de
  300 m; nada más fino sale al público). Lo único que cambia es **quién** puede ver coords exactas
  **en la consola autenticada**: pasa de `{aliado_firmante}` a
  `{aliado_firmante, administrador, admin_consorcio, analista}`. Registrado en
  `bitacora_sdd_mezquite.md` (gate #5 y Q5.B-D1) con el estilo de CR-009.
- **Gates intactos:** #1 (el reporte muestra distribución/impacto, **no** control/erradicación ni
  recetas), #2 (sin PII: la ubicación del **árbol** no es dato del voluntario; no se añade PII), #3 (sin
  gating: el acceso a exactas es de **vista por rol**, nunca bloquea funcionalidad), #6 (conmutable por
  `obfuscation_grid_m`), #7 (trazas).

## 4. Qué se hizo

### Backend (solo `backend/`)

| Pieza | Detalle |
|---|---|
| `EXACT_LOCATION_ROLES` | Constante única `(aliado_firmante, administrador, admin_consorcio, analista)` que sustituye el chequeo directo de `aliado_firmante` para el acceso a coords exactas. |
| `GET /restricted/observations` | Ahora **acepta los 4 roles** de `EXACT_LOCATION_ROLES` (antes solo `aliado_firmante`) y responde coords exactas; **rechaza** (403) `voluntario` y `evaluador`; sin token → 401. |
| `GET /admin/analytics/observations.csv` | Sirve coords **EXACTAS** (columnas `lat`, `lon`) a los roles de `EXACT_LOCATION_ROLES`; para el resto (p. ej. `evaluador`) sigue **obfuscado** (columnas `lat_celda_300m`, `lon_celda_300m`). El endpoint elige columnas por rol. |
| Público | `GET /public/grid` y `GET /public/observations` **sin cambios**: celda 300 m, nunca exactas. |

### Web-admin (solo `web-admin/`)

| Pieza | Detalle |
|---|---|
| Pestaña **"Mapa"** — toggle | Nuevo conmutador **"Mapa de calor (300 m)" / "Ubicaciones exactas"**. **Default = calor 300 m.** El modo **exacto** dibuja **un marcador por árbol** (coords exactas del backend) + **banner** "uso interno para reportes — no publicar sin obfuscar". El toggle solo es visible para los 4 roles de `EXACT_LOCATION_ROLES`. |
| Pestaña **"Vista restringida"** | La tabla de coords exactas se **abre a los 4 roles** (antes solo `aliado_firmante`). |
| Sesión | Getter `canSeeExactLocation` (en `session.dart`) = el rol pertenece a `EXACT_LOCATION_ROLES`; gobierna la visibilidad del toggle y de la vista restringida. |

## 5. Criterios de aceptación

- **AC1 (backend/restricted):** `GET /restricted/observations` responde coords exactas a `aliado_firmante`,
  `administrador`, `admin_consorcio` y `analista`; **rechaza** (403) `voluntario` y `evaluador`; sin
  token → 401.
- **AC2 (backend/CSV):** `GET /admin/analytics/observations.csv` incluye columnas `lat`/`lon` (exactas)
  para los roles de `EXACT_LOCATION_ROLES` y columnas `lat_celda_300m`/`lon_celda_300m` (obfuscadas) para
  el resto (p. ej. `evaluador`).
- **AC3 (público intacto):** `GET /public/grid` y `GET /public/observations` **siguen** obfuscados a
  300 m; **ningún** endpoint público expone coords exactas (gate #5 público intacto).
- **AC4 (web-admin/toggle):** el toggle "Mapa de calor (300 m) / Ubicaciones exactas" es **visible solo**
  para los 4 roles; para `voluntario`/`evaluador` no aparece. Default = calor.
- **AC5 (web-admin/modo exacto):** en "Ubicaciones exactas" el mapa renderiza **un marcador por árbol** y
  muestra el **banner de uso interno**.
- **AC6 (web-admin/sesión):** el getter `canSeeExactLocation` es verdadero exactamente para
  `EXACT_LOCATION_ROLES` y gobierna toggle + vista restringida.
- **AC7:** suites backend + `flutter test` (web-admin) verdes; la app móvil y la vista pública sin
  cambios; enmienda de gate #5 registrada en la bitácora y trazada en `TRACEABILITY.md`.

## 6. Qué NO cambia

- **La vista pública** (móvil nativo, web pública, `GET /public/grid`, `GET /public/observations`): sigue
  a **celda de 300 m**. Este CR **no** afecta lo que ve el público.
- **`voluntario` y `evaluador`:** **no** ganan acceso a coords exactas.
- **La app móvil (`mobile/`):** **no** se toca.
- **La obfuscación server-side y su conmutador** (`obfuscation_grid_m`, gate #6): intactos.
- **El modelo de datos / migraciones:** este CR **no** añade migración (es autorización de vistas por
  rol, no cambio de esquema).

## 7. Pruebas / verificación

- **Backend:** `test_roles.py` (restricted acepta los 4 roles y rechaza `evaluador`/`voluntario`) +
  cobertura del CSV por rol (columnas exactas vs. `*_celda_300m`) y verificación de que el público sigue
  obfuscado (`test_obfuscation.py` / `test_public_grid.py` sin regresión).
- **Web-admin:** pruebas de widget del mapa (toggle visible por rol, modo exacto renderiza marcadores +
  banner) y del getter `canSeeExactLocation`.
- **Números reales:** el total del repo se reconcilia tras correr las suites (lo ajusta el orquestador en
  `TRACEABILITY.md`).

## 8. Notas

- La **responsabilidad de qué se publica** (no difundir capturas de ubicaciones exactas sin obfuscar) es
  **operativa/gobernanza**, reforzada por el default a calor y el banner de uso interno; el software no
  intenta impedir una captura de pantalla interna.
- El **punto de gobernanza** heredado de Inc 4 —"`admin_consorcio` no ve exactas salvo que sea
  `aliado_firmante`"— queda **resuelto** para la consola por esta decisión humana: los roles
  administrativos y el analista ya ven exactas por diseño, para reportes.
