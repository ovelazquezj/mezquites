# Matriz de trazabilidad — criterio de aceptación → prueba (gate #7)

> Cada criterio de aceptación de `bitacora_sdd_mezquite.md` tiene una prueba asociada. Estado:
> ✅ verificado · 🟡 parcial (frontera/spec lista; falta cliente o backend) · ⏳ planificado.
> Se actualiza en cada incremento. Mantenida por el Documentador técnico.

## Decisiones de producto (Q*)

| Criterio (bitácora) | Componente | Inc. | Prueba | Estado |
|---|---|---|---|---|
| **Q5.A** Captura SOLO cámara nativa | móvil | 3 | `mobile/test/capture_camera_test.dart` (galería deshabilitada) | ⏳ |
| **Q5.A** Cada observación lleva EXIF del momento de toma | móvil + backend | 2–3 | backend exige `lat`/`lon`/`captured_at` en `POST /observations` (`ObservationCreate`): `backend/tests/test_observation_create.py`; móvil inyecta (Inc 3) | 🟡 (backend ✅; falta móvil) |
| **Q5.A** UI no muestra estado de validación individual | móvil | 3 | backend no devuelve `validation_state` en `/observations` ni `/observations/mine`: `backend/tests/test_observation_create.py::test_mine_does_not_expose_validation_state` ✅ · UI móvil Inc 3 | 🟡 (backend ✅) |
| **Q5.A** Imagen **válida** → puntos y se etiqueta como tal | backend | 2 | `backend/tests/test_worker_apply.py::test_valid_result_labels_valida_and_awards_deferred` | ✅ |
| **Q5.A** Imagen **no válida** → ruido, sin puntos | backend | 2 | `backend/tests/test_worker_apply.py::test_noise_result_labels_ruido_and_no_deferred` | ✅ |
| **Q5.A** Existe feedback **agregado** de tasa de validación | backend + móvil | 2–3 | `GET /me/feedback` agregado: `backend/tests/test_rankings_profile.py::test_feedback_is_aggregate_not_individual` ✅ · UI móvil Inc 3 | 🟡 (backend ✅) |
| **Q5.A** El submit no bloquea la UI (fire-and-forget) | backend + móvil | 2–3 | `backend/tests/test_observation_create.py::test_submit_enqueues_job_without_waiting` (encola y responde, sin esperar) ✅ · UI móvil Inc 3 | 🟡 (backend ✅) |
| **Q5.B** Vista pública solo coords a 1 km | backend | 2 | `backend/tests/test_obfuscation.py` (helper `obfuscate_1km`, EPSG:6372) + `backend/tests/test_roles.py::test_public_observations_are_obfuscated_to_1km` | ✅ |
| **Q5.B** Vista restringida exige auth de aliado firmante | backend | 2 | `backend/tests/test_roles.py::test_restricted_requires_aliado_firmante` / `test_restricted_allows_aliado_firmante_with_exact_coords` | ✅ |
| **Q5.B** Toda vista muestra fecha de snapshot (Qn) | backend + clientes | 2–4 | `/public/*` incluye `snapshot_quarter`: `backend/tests/test_roles.py` (público) + `snapshots.py` ✅ · clientes Inc 3–4 | 🟡 (backend ✅) |
| **Q5.B** La app NO genera PDFs (solo dashboards) | clientes | 3–4 | ausencia de export PDF (revisión + test de UI) | ⏳ |
| **Q7** Disclaimer una vez tras crear cuenta; descarte 1 tap; en Ayuda | móvil | 3 | `mobile/test/disclaimer_test.dart` | ⏳ |
| **Q3** Selector con 4 opciones G4 + rango % visible | móvil | 3 | `mobile/test/g4_selector_test.dart` | ⏳ |
| **Q3** Dos toggles binarios independientes | móvil | 3 | idem | ⏳ |
| **Q3** Backend acepta la triple etiqueta | backend | 2 | `backend/tests/test_observation_create.py::test_submit_accepts_eight_labels_and_returns_base_reward` (nivel G4 + 2 flags) | ✅ |
| **Q2** Submit con 8 campos | backend | 2 | `backend/tests/test_observation_create.py` (8 etiquetas vía `ObservationCreate`) | ✅ |
| **Q2** Backend asigna `tree_id` según R3 (10 m) | backend | 2 | `backend/tests/test_tree_grouping.py` (`ST_DWithin 10` sobre geography) | ✅ |
| **Q2** Dashboard muestra handle por observación | backend + clientes | 2–4 | `GET /public/observations` incluye `handle`: `backend/tests/test_roles.py` ✅ · UI clientes Inc 3–4 | 🟡 (backend ✅) |
| **Q4** Perfil muestra etiqueta L3 | backend + móvil | 2–3 | `GET /me/profile`: `backend/tests/test_rankings_profile.py::test_profile_shows_identity_label_lifelist_badges` ✅ · UI móvil Inc 3 | 🟡 (backend ✅) |
| **Q4** Ningún módulo gatea por nivel | clientes + backend | 2–4 | sin checks de nivel en deps/endpoints (rol ≠ nivel); rankings informativos · UI clientes Inc 3–4 | 🟡 (backend ✅) |
| **Q4** Registro permite elegir institución y "solicitar agregar" | backend + clientes | 2–4 | `POST /admin/institutions` (status solicitada): `backend/tests/test_rankings_profile.py` (alta) + `register(institution_id)` ✅ · UI clientes Inc 3–4 | 🟡 (backend ✅) |
| **Q4** Rankings por periodo (individual + institución) | backend | 2 | `backend/tests/test_rankings_profile.py::test_rankings_individual_and_by_institution` | ✅ |
| **Q6** Dashboard expone indicadores social/educativo/ecológico automáticos | backend | 2 | `backend/tests/test_indicators.py::test_indicators_compute_automatically` | ✅ |
| **Q6** Ningún indicador dispara aprobación/reprobación (U1) | backend | 2 | `backend/tests/test_indicators.py::test_indicators_have_no_threshold_logic` (AST: sin umbrales en código) | ✅ |
| **Q8** Toda observación atribuible a estado y municipio | backend | 2 | `derive_estado_municipio` (join `admin_boundary`); `/restricted` y filtros exponen estado/municipio · admin_boundary se carga por separado | 🟡 (lógica ✅; carga de límites = dato operativo) |
| **Q8** Dashboards y rankings con filtro geográfico | backend | 2 | `backend/tests/test_rankings_profile.py::test_rankings_geo_filter` + `test_indicators.py::test_indicators_filter_by_estado` | ✅ |
| **Q8** Agregar un estado no requiere nueva infraestructura (RC1) | infra | 2 | estado = filtro (`WHERE estado=...`), sin multi-tenancy: revisión + filtros geográficos ✅ | ✅ |

## Decisiones técnicas (T*)

| Criterio | Componente | Inc. | Prueba | Estado |
|---|---|---|---|---|
| **T1** Compila/corre en emulador y dispositivo Android; captura inyecta lat/lon/timestamp reales | móvil | 3 | build + `integration_test` en emulador | ⏳ |
| **T2** Endpoints REST documentados (OpenAPI) y consumibles por ambos clientes | backend | 2 | `/api/v1/openapi.json` + `backend/tests/test_openapi.py` (esquema + endpoints presentes) | ✅ |
| **T3** Consulta agrupa dentro de 10 m | backend/DB | 2 | `backend/tests/test_tree_grouping.py` (`ST_DWithin 10` contra PostGIS real) | ✅ |
| **T3** Consulta devuelve coord redondeada a celda de 1 km | backend/DB | 2 | `backend/tests/test_obfuscation.py` (`obfuscate_1km`, proyección métrica EPSG:6372) | ✅ |
| **T4** Cambiar entorno alterna disco local ↔ bucket sin tocar código | backend | 2 | `backend/tests/test_storage_provider.py` (local + s3 con moto) | ✅ |
| **T5** Levanta en K8s local con un comando; mismos manifiestos a stg/prod | infra | 2 | `infra/k8s` + script de despliegue local *(no en alcance del Dev backend; compose dev sí: `infra/compose/docker-compose.dev.yml`)* | ⏳ |
| **T6** `submit` retorna sin esperar al validador | backend | 2 | `backend/tests/test_observation_create.py::test_submit_enqueues_job_without_waiting` (InMemoryBroker) + E2E compose | ✅ |
| **T6** Resultado del **mock** dispara etiquetado válida/ruido y recompensa diferida correctos | contrato + backend | 1–2 | `backend/tests/test_worker_apply.py` (etiquetado + diferida + idempotencia) + E2E compose mock↔worker | ✅ |
| **T7** Existe design system documentado con tokens Rotary+verde | docs | 1 | `docs/design-system/design-tokens.json` + `.md` | ✅ |
| **T7** Ninguna pantalla introduce elementos fuera del sistema | clientes | 3–4 | revisión de UI + lints de tokens | ⏳ |

## Gates innegociables (Orquestador)

| Gate | Dónde / prueba | Estado |
|---|---|---|
| 1. Boundary Q1 (no control fitosanitario) | revisión de endpoints/copy + `backend/tests/test_openapi.py::test_boundary_q1_no_phytosanitary_promises_in_spec` (escaneo del OpenAPI) | ✅ (backend) |
| 2. Sin PII | `account` sin email/teléfono; `/auth/register` y `/auth/recover` sin PII; token sin PII: `backend/tests/test_security_no_pii.py` (8 pruebas) | ✅ |
| 3. Sin gating | sin checks de nivel/capacitación en deps/endpoints; rol ≠ nivel; rankings informativos · UI clientes Inc 3–4 | 🟡 (backend ✅) |
| 4. Captura cámara-nativa + EXIF | móvil fuerza cámara (Inc 3); backend exige `lat`/`lon`/`captured_at`: `backend/tests/test_observation_create.py` | 🟡 (backend exige EXIF ✅) |
| 5. Obfuscación 1 km | `/public/*` obfusca server-side (`obfuscate_1km`, EPSG:6372); exactas solo `/restricted/*` (rol firmante): `test_obfuscation.py` + `test_roles.py` | ✅ |
| 6. Paridad de entornos (conmutable sin nube) | `make_broker("memory")` + `StorageProvider` local↔s3 + `DATABASE_URL`: `test_storage_provider.py`; compose dev sin nube (storage local, redis/postgis local) | ✅ |
| 7. Trazabilidad | este documento | ✅ (vivo) |
| 8. Alcance validación (es-árbol + parásitos; rechaza especie/G4) | `contract/python/tests/test_schema.py`; backend nunca valida G4/especie (autodeclarados) | ✅ |
| 9. Etiquetado válida/ruido autoritativo en backend | `backend/tests/test_worker_apply.py` (veredicto autoritativo recomputado + puntos diferidos solo si válida + idempotencia) | ✅ |
| 10. Contrato §6 (mock↔real sin cambios; conmutable) | `backend/tests/test_worker_apply.py::test_process_once_consumes_results_stream` + E2E compose (api→mock→result-worker) + `make_broker` | ✅ |

## Resumen del Incremento 1

**30 pruebas verdes** (`contract/python`: 21 · `mock-validator`: 9). Verificado: la frontera §6
(contrato + mock), la regla autoritativa de veredicto, el rechazo de especie/G4 (gate #8), el
etiquetado válida/ruido (gate #9), el transporte conmutable y el lazo E2E mock↔backend sin Redis
(gate #10), y el design system documentado (T7, parte de documentación).

## Resumen del Incremento 2 (backend)

**49 pruebas verdes del backend** (`backend/tests`), sobre **PostGIS real** (`postgis/postgis:16-3.4`
vía contenedor) para lo geoespacial/idempotencia y **sin DB** para lógica pura (obfuscación,
storage, auth/no-PII, autoridad del veredicto). Total del repo: **79 verdes**
(`contract`: 21 · `mock-validator`: 9 · `backend`: 49).

Verificado en backend: API REST en `/api/v1` con OpenAPI (T2); auth sin PII con código de respaldo
(gate #2); `tree_id` por `ST_DWithin 10 m` y `observation_seq` (Q2/T3); `obfuscate_1km` métrica
(EPSG:6372) y vistas pública/restringida por rol (gate #5); `StorageProvider` local↔s3 conmutable
(T4/gate #6); submit fire-and-forget que encola por el contrato §6 (T6); consumidor de resultados
con veredicto autoritativo, idempotencia y puntos diferidos solo si válida (gate #9/#10);
indicadores Q6 automáticos sin umbrales (U1); rankings y filtros geográficos (Q4/Q8). Migración
Alembic inicial habilita `postgis` y crea el modelo `postgis-model.md` (verificada `upgrade head`).
Stack completo levantado con `docker compose -f infra/compose/docker-compose.dev.yml up --build`
(postgres + api + result-worker + redis + mock-validator) y lazo E2E real verificado
(register → submit → mock valida → worker etiqueta `valida` + recompensa diferida).
