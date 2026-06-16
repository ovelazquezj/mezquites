# CR-001 — Revisión humana en el backend (sin YOLO)

| Campo | Valor |
|---|---|
| **ID** | CR-001 |
| **Título** | Aceptación por defecto + revisión humana desde el backend; retiro de la validación ML/YOLO |
| **Fecha** | 2026-06-15 |
| **Estado** | Aprobado por el usuario — **sin codificar** |
| **Prioridad** | Alta (va primero en la secuencia) |
| **Depende de** | — |
| **Habilita** | CR-002 (auth con identidad real) |

---

## 1. Contexto y motivación

Hoy la observación nace `pendiente`, se encola a un validador externo (mock de YOLO) por el contrato
§6, y un `result-worker` la etiqueta `valida`/`ruido` con la regla `valida ⟺ es_arbol ∧ parasitos`
(gate #9). Solo las **válidas** entran al dataset público y otorgan puntos diferidos.

El usuario decidió **cambiar el modelo**: toda imagen se **acepta por defecto** como captura de
mezquite, queda **visible**, y la calidad se decide por **revisión humana desde el backend** (UI). Se
**retira por completo** la clasificación ML/YOLO por ahora.

## 2. Decisiones tomadas (del usuario)

1. **UI de revisión = ampliar el web-admin** existente (Flutter Web), no una UI nueva servida por el backend.
2. **Rol Administrador = nuevo y distinto** de `admin_consorcio`. Se agregan 3 roles de backend:
   `administrador`, `evaluador`, `analista`. Los roles existentes **no se modifican**.
3. **Visibilidad pública = todo lo no-rechazado** (`estado_revision <> 'rechazada'`).
4. **Bitácora: enmendar** Q5.A-D1 y gates #8/#9/#10 (autorizado).
5. **Defaults confirmados:** YOLO queda **inactivo, no eliminado**; los **puntos se otorgan al subir**
   y un rechazo **no los revierte**; el evaluador revisa con la **imagen**, sin coordenada exacta.

## 3. Gates — enmiendas y salvaguardas

**Se enmiendan (documentar en la bitácora con fecha/motivo):**
- **Gate #8** (validación automática es-árbol + parásitos) → **eliminada**; la calidad la decide un humano.
- **Gate #9** (`valida ⟺ es_arbol ∧ parasitos`; solo válidas al dataset/puntos) → **reemplazada** por
  aceptación-por-defecto + veredicto humano; público = no-rechazadas.
- **Gate #10 / T6** (YOLO solo por la cola) → la frontera §6 queda **inactiva** (no se borra).

**Siguen vigentes (NO romper):**
- **Gate #5** (obfuscación 1 km; coords exactas solo a `aliado_firmante`). ⚠️ **Salvaguarda nueva:** la
  imagen guardada lleva **GPS en EXIF**; al servirla a `evaluador`/`analista` (que no son
  `aliado_firmante`) hay que **quitar el GPS del EXIF** server-side. El detalle de ubicación que vea
  la UI de revisión es a lo más **municipio/estado** (no coord exacta) salvo rol `aliado_firmante`.
- **Gate #2** (sin PII): las cuentas siguen seudónimas en este CR (la identidad real llega en CR-002).
- **Gate #3** (sin gating), **#4** (solo cámara), **#6** (paridad), **#7** (trazabilidad).

## 4. Alcance

**Incluye:** modelo de estado de revisión + tabla de auditoría; RBAC con 3 roles nuevos; endpoints de
revisión; servir imagen con EXIF-GPS saneado; cambio del filtro público; UI de revisión y monitor en
el web-admin; ajuste de copy móvil; desconexión de YOLO; pruebas y docs.

**No incluye:** autenticación con identidad real (CR-002); gestión de usuarios con usuario/contraseña
(CR-002 — en este CR los roles se asignan por el bootstrap/CLI temporal existente).

## 5. Diseño técnico

### 5.1 Modelo de datos (`backend/app/models.py` + migración Alembic `0002_revision_humana`)

- **Estado de revisión:** renombrar el concepto `validation_state` → **`estado_revision`** en
  `Observation`. Valores nuevos: `aceptada` (default), `confirmada`, `rechazada`. Sustituir el
  `CheckConstraint` `ck_obs_validation_state` por `ck_obs_estado_revision IN ('aceptada','confirmada','rechazada')`.
- **Roles:** ampliar `ROLES` y `ck_account_role` a
  `('voluntario','aliado_firmante','admin_consorcio','administrador','evaluador','analista')`.
- **Tabla de auditoría `human_review`** (gate #7): `id` PK, `observation_id` FK→observation,
  `reviewer_account_id` FK→account, `veredicto` CHECK IN `('confirmada','rechazada')`, `nota` Text
  nullable, `created_at`. **Log append-only** (varias filas por observación posibles); el estado actual
  vive en `observation.estado_revision`.
- `ValidationEvent` se **conserva** (auditoría histórica) pero deja de escribirse.
- **Migración:** como los datos de dev son desechables (arranque limpio), la migración puede recrear el
  CHECK y la columna directamente. Generar `alembic revision` y verificar `upgrade head` en el contenedor.

### 5.2 Submit (`backend/app/routers/observations.py`)

- **Quitar** `enqueue_validation_job(...)` y su import.
- Persistir con `estado_revision='aceptada'`.
- **Puntos al subir:** otorgar `base` (como hoy) **y** `diferida` en el mismo submit (conservar los
  `kind` `base`/`diferida` para no migrar el CHECK ni romper la gamificación). Un rechazo posterior
  **no** revierte puntos. *(El Arquitecto puede proponer colapsar a un solo `kind`; si lo hace, ajustar
  CHECK + pruebas.)*
- `ObservationSubmitResponse` puede seguir devolviendo `base_points`; mensaje de UI: "registrada y aceptada".

### 5.3 RBAC + endpoints de revisión (nuevo `backend/app/routers/review.py`)

| Método | Ruta | Rol | Qué hace |
|---|---|---|---|
| GET | `/review/queue` | evaluador, analista, administrador | Lista observaciones con filtros (`estado`, `municipio`, `estado_revision`, `desde`/`hasta`) + paginación |
| GET | `/review/observations/{id}` | evaluador, analista, administrador | Detalle: 8 etiquetas + metadata + estado_revision + historial de `human_review` |
| GET | `/review/observations/{id}/image` | evaluador, analista, administrador | Sirve la imagen; **EXIF GPS saneado** salvo `aliado_firmante` (gate #5) |
| POST | `/review/observations/{id}/verdict` | evaluador, administrador | Body `{veredicto: confirmada\|rechazada, nota?}` → inserta en `human_review` y actualiza `estado_revision` |
| GET | `/review/stats` | evaluador, analista, administrador | Conteos por `estado_revision`, throughput, pendientes |

- `analista` es **solo lectura** (sin POST verdict). Usar `require_role(...)` de `deps.py`.
- **Servir imagen:** leer del `StorageProvider`; para roles ≠ `aliado_firmante`, **strip de los tags
  EXIF GPS** antes de responder (reutilizar la dependencia de EXIF ya usada por el móvil o `piexif`/PIL
  en backend — decisión del Arquitecto).

### 5.4 Dataset público (`backend/app/routers/public.py`)

- Cambiar `WHERE validation_state = 'valida'` → `WHERE estado_revision <> 'rechazada'` en
  `public_observations` (y donde aplique en `indicators.py`/`snapshots.py`).

### 5.5 Web-admin (`web-admin/lib/src/...`)

- **Sección Revisión** (evaluador/administrador): pantalla de **cola** con filtros; pantalla de
  **detalle** con **visor de imagen** + botones **Confirmar**/**Rechazar** + campo de nota.
- **Sección Monitor** (analista, solo lectura): métricas de `/review/stats`.
- **Nav role-gated** en `home_shell.dart` (mostrar Revisión a evaluador/admin; Monitor a los 3).
- Métodos nuevos en `web-admin/lib/src/api/api_client.dart` + modelos en `models.dart`.
- Copy en `web-admin/lib/src/ui/copy.dart` (humanizado, sin códigos internos).

### 5.6 App móvil (`mobile/lib/src/...`)

- Copy del envío → "registrada y aceptada" (`ui/copy.dart`, pantalla de captura).
- Perfil: el feedback "tasa de validación" pasa a "aceptadas/contadas" o se simplifica
  (`profile_screen.dart`, `me.py` ya devuelve un resumen — ajustar texto).
- **Sin cambios** en captura por cámara, EXIF, ni multipart.

### 5.7 Desconectar YOLO

- Backend: quitar el encolado (5.2); `queue.py`, `validation_apply.py`, `result_worker` quedan en el
  repo **sin usarse**.
- Compose (`infra/compose/docker-compose.dev.yml`): sacar `result-worker` y `mock-validator` del
  arranque por defecto (idealmente tras un `profiles:` para reactivar fácil), o documentar que quedan
  ociosos.
- K8s: en overlays, escalar a 0 / no aplicar `mock-to-real`. (Documentar en `docs/DESPLIEGUE.md`.)

## 6. Desglose por agente (unidades construibles)

| # | Agente | Unidad / objetivo | Archivos principales | Pruebas |
|---|---|---|---|---|
| A0 | **Arquitecto** | Validar diseño 5.1–5.7, decidir colapso de puntos y librería de EXIF-strip; enmendar bitácora | `bitacora_sdd_mezquite.md` | — |
| A1 | **Dev backend** | Modelo + migración (5.1) | `models.py`, `alembic/versions/0002_*.py` | migración aplica; CHECKs nuevos |
| A2 | **Dev backend** | Submit sin cola + puntos al subir (5.2); desconectar YOLO (5.7) | `routers/observations.py`, `queue.py`, compose | submit responde 201; sin encolado |
| A3 | **Dev backend** | Router de revisión + RBAC + servir imagen con EXIF saneado (5.3) | `routers/review.py`, `deps.py`, `main.py`, `schemas.py` | RBAC 403/200; verdict cambia estado; **imagen sin GPS** para no-aliado |
| A4 | **Dev backend** | Filtro público no-rechazadas (5.4) | `routers/public.py`, `indicators.py`, `snapshots.py` | público excluye `rechazada`, incluye `aceptada`/`confirmada` |
| A5 | **Dev web-admin** | Sección Revisión + Monitor + nav role-gated (5.5) | `web-admin/lib/src/screens/*`, `api_client.dart`, `copy.dart`, `home_shell.dart` | widget tests de cola/detalle/verdict |
| A6 | **Dev móvil** | Copy "registrada y aceptada" + perfil (5.6) | `mobile/lib/src/ui/copy.dart`, `screens/*` | tests de copy verdes |
| A7 | **Tester/QA** | Suite completa + trazabilidad | `backend/tests/*`, `web-admin/test/*`, `mobile/test/*`, `TRACEABILITY.md` | **todas** verdes; números reales |
| A8 | **Documentador** | Bitácora, ARCHITECTURE, QUICKSTART, DESPLIEGUE | docs varios | enlaces y gates al día |

## 7. Criterios de aceptación (trazables — gate #7)

- AC1: Una observación recién subida queda `estado_revision='aceptada'` y **aparece** en
  `GET /public/observations`. *(test backend)*
- AC2: `POST /review/observations/{id}/verdict {rechazada}` la **saca** del dataset público y escribe
  una fila en `human_review`. *(test backend)*
- AC3: `analista` recibe **403** al intentar emitir veredicto; `evaluador`/`administrador` reciben 200. *(test backend)*
- AC4: `GET /review/observations/{id}/image` devuelve la imagen **sin tags EXIF GPS** para
  `evaluador`/`analista`; con GPS solo para `aliado_firmante`. *(test backend, gate #5)*
- AC5: El web-admin muestra la **cola**, abre el **detalle con imagen** y permite **confirmar/rechazar**;
  `analista` ve Monitor pero no botones de veredicto. *(widget tests)*
- AC6: La app móvil muestra "registrada y aceptada" tras enviar; sin estado de validación individual. *(test móvil)*
- AC7: El submit **no encola** ningún job (`queue` sin publicaciones). *(test backend)*
- AC8: `TRACEABILITY.md` mapea AC1–AC7 a pruebas concretas; suite global verde.

## 8. Riesgos

- **Fuga de coords por EXIF** si se sirve la imagen cruda → mitigado por AC4 (strip GPS). **Bloqueante.**
- **Gamificación inconsistente** si los puntos diferidos quedan a medio camino → A2 debe cubrir el
  cambio con pruebas (test_rankings_profile).
- **Datos viejos** en dev con el esquema anterior → arranque limpio (`down -v`) antes de migrar.

## 9. Definition of Done

Pruebas verdes (números reales reportados), gates #2/#3/#4/#5/#6/#7 verificados, gates #8/#9/#10
enmendados en la bitácora, `TRACEABILITY.md` actualizado, y un recorrido manual
`subir → revisar → confirmar/rechazar → dashboard` en local.
