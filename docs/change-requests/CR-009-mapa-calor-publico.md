# CR-009 — Mapa de calor público (celdas 300 m) en la app del voluntario

| Campo | Valor |
|---|---|
| **ID** | CR-009 |
| **Título** | Mapa de calor público de Aguascalientes (celdas 300 m) — vista "Mapa" de la app (móvil nativo + web) y entrada pública sin login |
| **Fecha** | 2026-06-16 |
| **Estado** | **Aprobado — en ejecución** (go del usuario 2026-06-16) |
| **Prioridad** | Alta (impacto comunitario; alimenta el lanzamiento 10-jul) |
| **Depende de** | CR-001 (público = no-rechazadas), CR-005 (la app compila a web) |
| **Alcance** | `backend/` (obfuscación 300 m + endpoint grid + caveat + siembra) y `mobile/` (mapa de calor + entrada pública). **web-admin NO se toca.** |

---

## 1. Contexto y decisiones (del usuario, 2026-06-16)

La pantalla "Mapa de observaciones" hoy **no tiene mapa** (solo lista + indicadores; el código lo marca
como placeholder de Inc 4). Referencia visual: `https://app.henomotita.mx/mapa`. El usuario pide un
**mapa de calor público** para entender el **impacto del paxtle** en los mezquites de **Aguascalientes**.

Decisiones:
- **a)** El mapa es la **vista "Mapa" de la app del voluntario** (un solo código Flutter ⇒ **móvil nativo + web**), con **entrada pública sin login**. Al integrar, **se documenta la URL/forma de acceso**.
- **b)** **Celdas de calor** y **obfuscación 1 km → 300 m** (enmienda gate #5, ver §2).
- **c)** **Zoom inicial en Aguascalientes**.
- **d)** **Siembra** de pocos datos pero significativos (plataforma de desarrollo).
- **e)** **OpenStreetMap** como tiles (etapas tempranas).
- **Solo el mapa:** la pantalla es **mapa puro**. Indicadores numéricos y disclaimer van **detrás de un botón "ⓘ"** (opción ii); se eliminan la tarjeta de indicadores y la lista de la pantalla.

## 2. Gate enmendado (¡decisión humana, registrada!)

- **Gate #5 (obfuscación): 1 km → 300 m.** Enmendado en `bitacora_sdd_mezquite.md` (gate #5 y Q5.B-D1,
  2026-06-16). La celda de 300 m (≈9 ha) **sigue ocultando el árbol exacto**; el wire público **nunca**
  expone coords más finas que 300 m; coords exactas **solo** a `aliado_firmante`. **Conmutable** por
  `obfuscation_grid_m` (gate #6 intacto). Motivo: soportar el mapa de calor sin perder protección efectiva.
- **Gates intactos:** #1 (el mapa muestra impacto/presencia, **no** control/erradicación; disclaimers
  visibles), #8 (especie y G4 autodeclarados; el caveat corregido lo dice), #3 (sin gating), #7 (trazas).

## 3. Contrato — `GET /public/grid` (sin auth)

Agrega las observaciones **no rechazadas** por celda de 300 m (centro de celda obfuscado, gate #5):

```jsonc
// GET /public/grid?estado=Aguascalientes&limit=2000
[
  {
    "lat": 21.8855, "lon": -102.2915,   // centro de celda 300 m (obfuscado)
    "n": 4,                              // nº de observaciones en la celda
    "n_paxtle": 3,                       // con paxtle (flag_danio)
    "n_cuscuta": 1,                      // con cúscuta (flag_cuscuta)
    "g4_indice": 2.0,                    // promedio 0..3 (sano,leve,moderado,severo) → color del calor
    "snapshot_quarter": "2026-Q2"
  }
]
```

- **Color del calor:** por `g4_indice` (intensidad de severidad). El popup de la celda muestra `n`,
  `n_paxtle`, `n_cuscuta` y la mezcla de severidad. **Nunca** coords exactas ni lista de árboles.
- `/public/observations` y `/public/indicators` **se conservan** (otros usos); la pantalla de mapa usa
  **`/public/grid`**.

## 4. Diseño técnico

### 4.1 Backend (Carril A — solo `backend/`)
- `config.py`: `obfuscation_grid_m` **1000 → 300**.
- `geo.py`: la obfuscación ya parametriza por `obfuscation_grid_m` (no hardcode 1 km); generalizar el
  nombre si aplica (`obfuscate_to_grid`), conservando compatibilidad.
- `routers/public.py` + `schemas.py`: **`GET /public/grid`** (agregación por celda; agrupar en SQL o en
  Python tras obfuscar). Nuevo schema `PublicGridCell`.
- `indicators.py`: **corregir `CAVEAT`** — quitar "La validación automática confirma…" (pre-CR-001);
  dejar algo como: *"Datos de origen ciudadano, sin validación por expertos; especie y nivel autodeclarados."*
- **Siembra** (`backend/app/seed_demo.py`, idempotente, invocable por CLI): **8–12 observaciones**
  alrededor de Aguascalientes, repartidas en **varias celdas de 300 m** con **G4 variado** (sano…severo)
  y mezcla de **paxtle/cúscuta**, para que el calor sea legible. No depende de subir imágenes reales.
- **Pruebas:** actualizar `tests/test_obfuscation.py` (umbrales 300 m); test de `/public/grid` (agrega,
  no expone coords <300 m, solo no-rechazadas); que el resto siga verde.

### 4.2 Móvil/web (Carril B — solo `mobile/`)
- `pubspec.yaml`: `flutter_map` + `latlong2` (compilan en web).
- **Pantalla de mapa puro** (rehacer `dashboard_screen.dart` o nueva `heat_map_screen.dart`):
  `FlutterMap` con **TileLayer OSM**, **capa de celdas de calor** (círculos/markers coloreados por
  `g4_indice`), **leyenda**, **popup por celda**, **encuadre inicial en Aguascalientes**. Sin indicadores
  ni lista en la pantalla.
- **Botón "ⓘ"** (esquina): abre un panel con el **disclaimer** (gates #5/#1: "ubicaciones aproximadas
  ~300 m para proteger a los árboles; dato ciudadano, sin validación experta; nivel autodeclarado") **y
  los indicadores numéricos** (de `/public/indicators`).
- **Entrada pública sin login:** botón "Ver el mapa público" en `welcome_screen.dart` que navega a la
  misma pantalla **sin sesión** (los endpoints `public/*` no requieren auth; verificar que `_headers`
  no rompa sin token). La pestaña **Mapa** del `HomeShell` usa la misma pantalla con sesión.
- `api_client.dart` + `models.dart` + `providers.dart`: método `publicGrid()` + modelo `GridCell` +
  provider. `copy.dart`: "~1 km" → "~300 m".
- **Pruebas:** widget test del mapa (carga celdas mock, leyenda, popup, botón ⓘ); que el gate #4 y los
  tests previos sigan verdes; `flutter build web` OK.

## 5. Desglose por agente

| Carril | Agente | Alcance | Archivos |
|---|---|---|---|
| **G0** | Arquitecto (orquestador) | Enmienda gate #5 (bitácora), contrato `/public/grid`, este CR | bitácora, `docs/change-requests/` |
| **A** | Dev backend | §4.1 (300 m, `/public/grid`, caveat, siembra, pruebas) | **solo `backend/`** |
| **B** | Dev móvil/web | §4.2 (flutter_map, mapa puro, ⓘ, entrada pública, pruebas) | **solo `mobile/`** |
| **QA** | Tester/QA (orquestador) | Integra; corre backend (PostGIS) + `flutter test` + `flutter build web`; verifica gates; siembra; refresca demo `appctl`; **entrega URL de acceso** | — |
| **Doc** | Documentador | `TRACEABILITY.md`, `CLAUDE.md` (gate #5 + estado), `QUICKSTART.md` (acceso al mapa), índice CRs | docs |

**Secuencia:** G0 → (A ∥ B en paralelo, rutas disjuntas) → QA → Doc.

## 6. Criterios de aceptación
- AC1: La vista **Mapa** (móvil nativo + web) muestra un **mapa de calor** centrado en Aguascalientes; **sin** indicadores ni lista en pantalla.
- AC2: Existe **entrada pública sin login** a esa pantalla desde la Bienvenida.
- AC3: El botón **ⓘ** muestra disclaimer (gates #5/#1) + indicadores numéricos.
- AC4: **Gate #5 a 300 m:** ninguna respuesta pública trae coords más finas que la celda de 300 m; `aliado_firmante` intacto.
- AC5: `GET /public/grid` agrega por celda (no-rechazadas) y alimenta el calor.
- AC6: **Siembra** produce varias celdas con severidad variada en Aguascalientes.
- AC7: `CAVEAT` ya no menciona validación automática (gate #8). Pruebas backend + `flutter test` verdes; `flutter build web` OK; web-admin intacto.

## 7. Riesgos
- **Privacidad (300 m):** menor enmascaramiento que 1 km → mitigado: celda agregada (no punto), registrado como enmienda revisable; conmutable por config.
- **Datos escasos:** mitigado por la siembra.
- **Tiles OSM:** uso de demo; producción puede requerir proveedor con términos (anotado, no bloquea).
- **`flutter_map` en web:** validar render de tiles + capa de celdas en `flutter build web`.

## 8. Definition of Done
Mapa de calor público (móvil + web) centrado en Aguascalientes, abrible sin login; backend con celdas de
300 m + `/public/grid` + caveat corregido + datos sembrados; gate #5 enmendado en la bitácora; pruebas
verdes (números reales) y build web OK; web-admin intacto; trazabilidad y docs actualizadas; **URL de
acceso entregada al usuario**.
