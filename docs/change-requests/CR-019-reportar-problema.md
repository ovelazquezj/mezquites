# CR-019 — Botón "Reportar un problema" + vista de admin + diagnóstico

| Campo | Valor |
|---|---|
| **ID** | CR-019 |
| **Fecha** | 2026-06-28 |
| **Estado** | ✅ Implementado en `main` (local), pendiente de desplegar |
| **Alcance** | `backend/` · `mobile/` · `web-admin/` |
| **Relación** | Complementa CR-018 (el error de cámara enlaza aquí) · gate #2 (sin PII) · gate #3 (sin gating) |
| **Ejecución** | Directo sobre `main`, por el orquestador |

## 1. Contexto

No había **logs del lado del cliente**. Las fallas de campo (p. ej. la cámara de CR-018) son
**invisibles** en los logs del backend porque el cliente **nunca llega a hacer la petición HTTP** (falla
antes). El usuario pidió un **botón** para que los voluntarios reporten un problema y poder **depurar
desde la consola de admin**, capturando un mínimo de diagnóstico técnico.

## 2. Decisión del usuario (2026-06-28)

Agregar un canal de reporte voluntario, **sin PII**, visible en la app (Bienvenida y Perfil) y desde el
error de cámara, con una **vista de admin** para triage. El diagnóstico se limita a metadatos técnicos
(navegador, plataforma, versión) más una nota libre y el detalle técnico del error.

## 3. Qué se hizo

### Backend

| Pieza | Detalle |
|---|---|
| Modelo `ProblemReport` | Tabla `problem_report` (`models.py`); `status` ∈ {nuevo, visto, resuelto}; `account_id`/`handle` **nullable** (reporte anónimo permitido). **Sin PII** (solo diagnóstico + nota + error técnico). |
| Migración **0006_problem_reports** | `down_revision = 0005`; crea la tabla. |
| Schemas | `schemas.py` (entrada del reporte + salida de admin). |
| Router (`/api/v1`) | `routers/problem_reports.py`: `POST /problem-reports` con **auth OPCIONAL** → **201** anónimo o con `handle`; `GET /admin/problem-reports`; `POST /admin/problem-reports/{id}/status`. |
| Dependencia | `get_current_user_optional` (resuelve usuario si hay token, no exige login). |
| Gateo de admin | Lectura/estado solo para `admin_consorcio` / `administrador`. |
| Pruebas | **8** en `backend/tests/test_problem_reports.py`. |

### Móvil

| Pieza | Detalle |
|---|---|
| `device_diagnostics.dart` | Export **condicional** web / no-web: en web envía el `user_agent` real + `platform = 'web'`; en la VM de pruebas, un **stub vacío**. |
| `ProblemReportScreen` | `mobile/lib/src/ui/screens/problem_report_screen.dart`: nota libre + envío del diagnóstico. |
| `ApiClient.submitProblemReport(...)` | Cliente del nuevo endpoint. |
| Entradas | Botones en **Bienvenida** y **Perfil**, y **enlace desde el error de cámara** (CR-018). |

### Web-admin

| Pieza | Detalle |
|---|---|
| Pantalla **"Reportes"** | `web-admin/lib/src/screens/problem_reports_screen.dart` con `PagedTable` (columnas **Fecha · Contexto · Navegador · Versión · Usuario · Estado · Mensaje**); diálogo de detalle con `error_detail`. |
| Acciones | Marcar **Visto** / **Resuelto**. |
| Navegación | Entrada del NavigationRail **gateada** a `admin_consorcio` / `administrador`. |
| Pruebas | **10** en `web-admin/test/problem_reports_test.dart`. |

## 4. Gates

- **Gate #2 (sin PII):** **intacto** — el reporte solo lleva diagnóstico (`user_agent` / `platform` /
  `app_version`) + nota libre + detalle técnico del error; **nunca** email/teléfono/nombre. El `handle`
  es seudónimo y opcional.
- **Gate #3 (sin gating):** **intacto** — el reporte **funciona sin login** (auth opcional, 201 anónimo).
- Resto de gates: sin cambios.

## 5. Pruebas / verificación

- Backend: **8** pruebas (`test_problem_reports.py`) — alta anónima/autenticada, gateo de admin, cambios
  de estado.
- Web-admin: **10** pruebas (`problem_reports_test.dart`) — render de la tabla paginada, detalle,
  acciones, gateo de la entrada del NavigationRail.
- Móvil: el diagnóstico web se valida en navegador; en la VM el stub no rompe la suite.

## 6. Notas

- Es un canal de **depuración**, no de soporte formal; el detalle técnico ayuda a reproducir fallas como
  las de cámara (CR-018) que antes no dejaban rastro en el backend.
