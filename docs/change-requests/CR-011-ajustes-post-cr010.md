# CR-011 — Ajustes post-CR-010 (hallazgos de revisión visual)

| Campo | Valor |
|---|---|
| **ID** | CR-011 |
| **Fecha** | 2026-06-17 |
| **Estado** | ✅ **Integrado en `main`** (299 pruebas verdes) |
| **Alcance** | `backend/`, `web-admin/`, `mobile/` — arreglos de los 6 hallazgos del usuario sobre el demo |
| **Ejecución** | Directo sobre `main` (no agentes), por el orquestador |

## Decisiones del usuario (2026-06-17)
1. (5b) Registro de institución en el signup = **opción A**: crear cuenta → solicitar institución autenticado → asociarla.
2. (5a) El **`administrador`** ve y usa la consola (Instituciones/Aliados/Indicadores/Cortes).
3. Ejecución **directa** (sin worktrees: los agentes previos se ramificaban del inicio de sesión).

## Hallazgos y causa raíz → arreglo

| # | Hallazgo | Causa raíz | Arreglo |
|---|---|---|---|
| 1 | Logo diminuto en headers del web-admin | `Image.asset(height: 32)` | logo 32→**44** + `toolbarHeight: 64` (home_shell); login ya con logo |
| 2 | Tablas se cortan, sin scroll horizontal | `SingleChildScrollView` horizontal **sin barra visible** en web | nuevo `HScroll` (Scrollbar `thumbVisibility`) en las **5 tablas** |
| 3 | No hay botones de revisión / no se cambia estatus | la columna **"Abrir"** quedaba fuera de pantalla (consecuencia del #2) | scroll del #2 la expone **+** filas de revisión **clicables** (`onSelectChanged`) abren el detalle (3 botones: Confirmar/Retirar/Volver a aceptada) |
| 4 | "Datos y descargas" no funciona | `GET /admin/analytics/observations` (JSON de la tabla) **no existía** → 404 | nuevo endpoint backend (JSON, obfuscado 300 m, mismos filtros) |
| 5a | No hay página de instituciones/solicitudes para el admin | consola gateada a `admin_consorcio`; el usuario entra como `administrador` | gateo `isAdmin \|\| isAdministrador` (nav) + `_admin = require_role(admin_consorcio, administrador)` (backend) + botón **"Aprobar"** y `POST /admin/institutions/{id}/approve` |
| 5b | Móvil: institución registrada no aparece; login no permite registrar | la solicitada no entra al catálogo hasta aprobarse (sin loop de aprobación) + no había alta en el login | loop de aprobación (5a) + **"Registrar nueva institución" en el login** (opción A; `/institutions/request` ahora **asocia** la institución a la cuenta) |

## Gates
- **#5:** `/admin/analytics/observations` NO expone coords exactas (solo estado/municipio); CSV y mapa siguen a celda 300 m.
- **#2/#3:** sin cambios de PII; el `administrador` ya tenía las facultades, solo se hace visible/operable la consola.

## Pruebas (números reales)
**299 verdes** — `contract` 21 · `mock` 9 · **backend 136** (+5: `test_cr011_consola_analytics.py`) · **móvil 61** · **web-admin 72** (+2: `widget_cr011_test.dart`). Demo refrescado por `appctl` (backend reconstruido — `/admin/analytics/observations` verificado vivo; web + admin reconstruidas).

## Notas
- Sin migración nueva (CR-011 no toca el esquema).
- Los widget tests del mapa siguen generando ruido de red por tiles OSM (no fallan); stub pendiente.
