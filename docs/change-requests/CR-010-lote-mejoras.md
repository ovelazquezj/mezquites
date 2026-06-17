# CR-010 — Lote de mejoras (branding, mapa consola, analista, evaluación, captura, instituciones, evidencia)

| Campo | Valor |
|---|---|
| **ID** | CR-010 |
| **Fecha** | 2026-06-17 |
| **Estado** | ✅ **Integrado en `main`** (2026-06-17; 292 pruebas verdes) |
| **Alcance** | `backend/`, `mobile/`, `web-admin/` en **3 carriles paralelos** (rutas disjuntas) |
| **Orquestación** | 3 subagentes (Backend ∥ Móvil ∥ Web-admin) que **desarrollan y prueban**; el orquestador integra, verifica gates y corre las suites completas |

## Decisiones del usuario (selladas para este CR)
1. Nombre oficial: **Club Rotario Bosques Aguascalientes** (sin cambio a `Copy.orgName`).
2. Captura estado/municipio: **auto-detectar y preseleccionar** de la lista, **editable** por el usuario; la derivación por GPS (`admin_boundary`) queda de **respaldo**.
3. Instituciones: el voluntario puede **registrar una nueva** desde el móvil (queda `solicitada`).
4. Horas = **tiempo de sesión**; evidencia **en pantalla**; sesiones **persistidas en backend** para analítica.
5. Evaluación: además de Confirmar/Retirar, **botón para revertir a "aceptada"**.

## Gates aplicables
- **#5 (obfuscación 300 m):** el analista y la consola **no** son `aliado_firmante` → CSV/mapa/tablas exponen **solo celda 300 m**, nunca coords exactas; la imagen de revisión sigue con GPS-EXIF saneado server-side.
- **#1:** nada promete control fitosanitario (evidencia/mapa/CSV son descriptivos).
- **#2 (PII):** sin email/nombre; handle seudónimo permitido; sesiones guardan solo `account_id` + tiempos.
- **#3 (sin gating):** la evidencia y la elección de institución no bloquean nada.
- **#4 (captura):** se mantiene cámara nativa con EXIF; estado/municipio son autodeclarados.
- **#8:** especie/nivel/estado/municipio autodeclarados (auto-detección pre-llena, el usuario corrige).

## Contrato compartido (fuente única de coordinación)

### Cambios de wire / endpoints (los implementa **Backend**; **Móvil** y **Web-admin** consumen)
- `ObservationCreate` += `estado: str | None`, `municipio: str | None` (autodeclarados). En `POST /observations`: si vienen, se usan; si no, se **derivan** (`derive_estado_municipio`, respaldo). Se guardan en `observation.estado/municipio`.
- `VerdictRequest.veredicto` ∈ **{`aceptada`, `confirmada`, `rechazada`}** (antes solo confirmada/rechazada). `POST /review/observations/{id}/verdict` acepta `aceptada` (revierte; mensaje "Observación devuelta a aceptada (pendiente de revisión)."). Verificar/`ALTER` cualquier CHECK de `human_review.veredicto`.
- **Instituciones:** `POST /institutions/request` (auth de voluntario) body `{name: str, estado: str|None}` → crea `Institution(status='solicitada')` → 201 `{id, name, status}`. El `GET /institutions` público sigue devolviendo solo `aprobada`. **Siembra** idempotente (`backend/app/seed_institutions.py`, CLI) de instituciones **aprobadas**: Universidad Autónoma de Aguascalientes (UAA), Instituto Tecnológico de Aguascalientes (TecNM), Universidad Politécnica de Aguascalientes, Universidad Tecnológica de Aguascalientes, Universidad Cuauhtémoc Aguascalientes, UVM campus Aguascalientes, Tecnológico de Monterrey campus Aguascalientes, e "Institución Independiente" (todas `estado='Aguascalientes'`).
- **Analítica (analista):** `GET /admin/analytics/summary` (auth `REVIEW_ROLES`) → conteos por `estado_revision`, por `municipio`, por `nivel_g4`, totales. `GET /admin/analytics/observations.csv` (auth `REVIEW_ROLES`) → `text/csv` de observaciones con columnas `observation_id, captured_at, handle, estado, municipio, nivel_g4, flag_cuscuta, flag_danio, tamanio, contexto, estado_revision, lat_celda_300m, lon_celda_300m` (**coords obfuscadas a 300 m**, gate #5). Filtros query: `estado, municipio, nivel_g4, estado_revision, desde, hasta`.
- **Sesiones/evidencia (#7):** nueva tabla `participation_session(id, account_id FK, started_at, ended_at, duration_seconds)` + **migración Alembic 0005** (y agregarla a la lista TRUNCATE de `conftest.py`). `POST /me/sessions` (auth voluntario) body `{started_at, ended_at}` → calcula `duration_seconds`, guarda → 201. `GET /me/evidence` (auth voluntario) → `{capturas:int, horas_totales:float, sesiones:int, primera: datetime|null, ultima: datetime|null}` (capturas = nº de observaciones propias; horas = Σ duration/3600).
- **Mapa consola (#2):** sin endpoint nuevo — reusa `GET /public/grid` (ya obfuscado 300 m).

## Carriles

### Carril BACKEND (solo `backend/`)
Implementa **todo el contrato de arriba** + pruebas pytest (`PYTHONPATH=…/contract/python python -m pytest -q`, usa PostGIS de prueba propio). Migración 0005 para `participation_session`. Verdict acepta `aceptada`. Endpoints analytics/sesiones/evidencia/solicitud-institución. Seed de instituciones.

### Carril MÓVIL (solo `mobile/`)
- **#5 captura:** agrega selección de **estado** (default Aguascalientes) y **municipio** (los 11 municipios de Aguascalientes) al formulario; **auto-detecta** desde el GPS de la captura (lookup local por cercanía/polígono de los municipios) y **preselecciona**, editable; envía `estado/municipio` en el payload.
- **#6 instituciones:** el alta lista el catálogo (ahora poblado) y permite **"Registrar nueva institución"** → `POST /institutions/request` (post-login) con confirmación.
- **#7 evidencia:** rastrea **tiempo de sesión** (lifecycle de la app) y lo envía a `POST /me/sessions`; pantalla de **Evidencia** que muestra capturas + horas acumuladas + rango (de `GET /me/evidence`). Solo pantalla (sin PDF).
- Pruebas `flutter test` (mockean la API). Gate #4 intacto.

### Carril WEB-ADMIN (solo `web-admin/`)
- **#4 evaluación:** **arregla el visor de imagen en web** (Flutter Web ignora `headers` en `Image.network`) → descargar bytes con el cliente HTTP autenticado y pintar con `Image.memory`; agrega **botón "Volver a aceptada"** (veredicto `aceptada`).
- **#1 branding:** copia `logo_horizontal.png` a `web-admin/assets/branding/`, decláralo en `pubspec.yaml`, úsalo en el AppBar (`home_shell`) y en el login junto al nombre del Club.
- **#2 mapa:** agrega `flutter_map`+`latlong2`; pestaña **Mapa** (mapa de calor de `/public/grid`, 300 m) visible para **todos los roles** de consola.
- **#3 analista:** pantalla de **datos** (tabla con filtros estado/municipio/nivel/fecha + **resúmenes** de `GET /admin/analytics/summary` + botón **Descargar CSV** de `GET /admin/analytics/observations.csv`), visible para `analista`/`administrador`.
- **#5 tablas:** auditar todas las `DataTable` para **scroll horizontal** en web.
- Pruebas `flutter test` (mockean la API).

## Reglas de coordinación
- Cada carril edita **solo su carpeta**. **No** tocar `CLAUDE.md`, `TRACEABILITY.md`, ni `docs/` (el orquestador documenta al integrar).
- Móvil y Web-admin **mockean** la API según este contrato; no dependen de que el backend esté corriendo para sus pruebas.
- "Hecho" por carril = código + pruebas **verdes** de su superficie (números reales).

## Integración (orquestador)
Merge de los 3 carriles → correr migración 0005 → sembrar instituciones → suites completas (contract, mock, backend, móvil, web-admin) → verificar gates → refrescar demo (`appctl … -Build`) → actualizar `TRACEABILITY.md`, `CLAUDE.md`, este CR.

## Resultado (2026-06-17)
Integrado por merges 3-way en `main` (`merge(cr-010)` Carriles A/B/C). Los carriles se ramificaron de
`52ba434` (sin la terminología de esta sesión); al integrar se reconciliaron los solapes en
`copy.dart`/pantallas conservando **mi `roleLabel` aprobado** y la nueva terminología, y la **feature del
agente** (logo, mapa, datos, fix de evaluación). Migración **0005 en head**; **8 instituciones** sembradas.
**292 pruebas verdes** (21 contract · 9 mock · **131** backend · **61** móvil · **70** web-admin); demo
refrescado por `appctl`. Un test del analista se reescribió (la `key` de un `DataRow` no es localizable;
se afirma el contenido de celda). Tiles OSM en los widget tests del mapa generan ruido de red (no fallan).
