# Matriz de trazabilidad — criterio de aceptación → prueba (gate #7)

> Cada criterio de aceptación de `bitacora_sdd_mezquite.md` tiene una prueba asociada. Estado:
> ✅ verificado · 🟡 parcial (frontera/spec lista; falta cliente o backend) · ⏳ planificado.
> Se actualiza en cada incremento. Mantenida por el Documentador técnico.

## Decisiones de producto (Q*)

| Criterio (bitácora) | Componente | Inc. | Prueba | Estado |
|---|---|---|---|---|
| **Q5.A** Captura SOLO cámara nativa | móvil | 3 | `mobile/test/capture_camera_test.dart` (galería deshabilitada) | ⏳ |
| **Q5.A** Cada observación lleva EXIF del momento de toma | móvil + backend | 2–3 | `backend` exige EXIF en `POST /observations`; móvil inyecta | 🟡 (contrato job incluye `captured_at`/`lat`/`lon`: `contract/python/tests/test_models.py`) |
| **Q5.A** UI no muestra estado de validación individual | móvil | 3 | `mobile/test/no_individual_status_test.dart` | ⏳ |
| **Q5.A** Imagen **válida** → puntos y se etiqueta como tal | backend | 2 | etiqueta: `contract/.../test_verdict.py` ✅ · puntos: `backend` Inc 2 | 🟡 |
| **Q5.A** Imagen **no válida** → ruido, sin puntos | backend | 2 | `contract/.../test_verdict.py` (ruido) ✅ · ledger sin diferida: Inc 2 | 🟡 |
| **Q5.A** Existe feedback **agregado** de tasa de validación | backend + móvil | 2–3 | `GET /me/feedback` agregado | ⏳ |
| **Q5.A** El submit no bloquea la UI (fire-and-forget) | backend + móvil | 2–3 | `mock-validator/tests/test_worker_e2e.py::test_job_pendiente_si_el_worker_no_corre` (frontera async) | 🟡 |
| **Q5.B** Vista pública solo coords a 1 km | backend | 2 | `backend/tests/test_obfuscation.py` (`ST_SnapToGrid`) | ⏳ |
| **Q5.B** Vista restringida exige auth de aliado firmante | backend | 2 | `backend/tests/test_roles.py` | ⏳ |
| **Q5.B** Toda vista muestra fecha de snapshot (Qn) | backend + clientes | 2–4 | `GET /public/*` incluye `snapshot_quarter` | ⏳ |
| **Q5.B** La app NO genera PDFs (solo dashboards) | clientes | 3–4 | ausencia de export PDF (revisión + test de UI) | ⏳ |
| **Q7** Disclaimer una vez tras crear cuenta; descarte 1 tap; en Ayuda | móvil | 3 | `mobile/test/disclaimer_test.dart` | ⏳ |
| **Q3** Selector con 4 opciones G4 + rango % visible | móvil | 3 | `mobile/test/g4_selector_test.dart` | ⏳ |
| **Q3** Dos toggles binarios independientes | móvil | 3 | idem | ⏳ |
| **Q3** Backend acepta la triple etiqueta | backend | 2 | `backend/tests/test_observation_create.py` | ⏳ |
| **Q2** Submit con 8 campos | backend | 2 | `backend/tests/test_observation_create.py` | ⏳ |
| **Q2** Backend asigna `tree_id` según R3 (10 m) | backend | 2 | `backend/tests/test_tree_grouping.py` (`ST_DWithin 10`) | ⏳ |
| **Q2** Dashboard muestra handle por observación | backend + clientes | 2–4 | `GET /public/observations` incluye `handle` | ⏳ |
| **Q4** Perfil muestra etiqueta L3 | backend + móvil | 2–3 | `GET /me/profile` | ⏳ |
| **Q4** Ningún módulo gatea por nivel | clientes + backend | 2–4 | revisión de gates + `test_no_gating` | ⏳ |
| **Q4** Registro permite elegir institución y "solicitar agregar" | backend + clientes | 2–4 | `POST /admin/institutions` (solicitada) | ⏳ |
| **Q4** Rankings por periodo (individual + institución) | backend | 2 | `backend/tests/test_rankings.py` | ⏳ |
| **Q6** Dashboard expone indicadores social/educativo/ecológico automáticos | backend | 2 | `backend/tests/test_indicators.py` | ⏳ |
| **Q6** Ningún indicador dispara aprobación/reprobación (U1) | backend | 2 | revisión: sin umbrales en código | ⏳ |
| **Q8** Toda observación atribuible a estado y municipio | backend | 2 | `backend/tests/test_geo_dimension.py` (join admin) | ⏳ |
| **Q8** Dashboards y rankings con filtro geográfico | backend | 2 | `backend/tests/test_geo_filters.py` | ⏳ |
| **Q8** Agregar un estado no requiere nueva infraestructura (RC1) | infra | 2 | revisión de arquitectura (sin multi-tenancy) | ⏳ |

## Decisiones técnicas (T*)

| Criterio | Componente | Inc. | Prueba | Estado |
|---|---|---|---|---|
| **T1** Compila/corre en emulador y dispositivo Android; captura inyecta lat/lon/timestamp reales | móvil | 3 | build + `integration_test` en emulador | ⏳ |
| **T2** Endpoints REST documentados (OpenAPI) y consumibles por ambos clientes | backend | 2 | `/api/v1/openapi.json` + `backend/tests/test_openapi.py` | ⏳ |
| **T3** Consulta agrupa dentro de 10 m | backend/DB | 2 | `backend/tests/test_tree_grouping.py` | ⏳ |
| **T3** Consulta devuelve coord redondeada a celda de 1 km | backend/DB | 2 | `backend/tests/test_obfuscation.py` | ⏳ |
| **T4** Cambiar entorno alterna disco local ↔ bucket sin tocar código | backend | 2 | `backend/tests/test_storage_provider.py` (local + s3 mock) | ⏳ |
| **T5** Levanta en K8s local con un comando; mismos manifiestos a stg/prod | infra | 2 | `infra/k8s` + script de despliegue local | ⏳ |
| **T6** `submit` retorna sin esperar al validador | backend | 2 | frontera async verificada: `mock-validator/tests/test_worker_e2e.py` | 🟡 |
| **T6** Resultado del **mock** dispara etiquetado válida/ruido y recompensa diferida correctos | contrato + backend | 1–2 | `mock-validator/tests/test_worker_e2e.py` (etiquetado) ✅ · recompensa diferida: backend Inc 2 | 🟡 |
| **T7** Existe design system documentado con tokens Rotary+verde | docs | 1 | `docs/design-system/design-tokens.json` + `.md` | ✅ |
| **T7** Ninguna pantalla introduce elementos fuera del sistema | clientes | 3–4 | revisión de UI + lints de tokens | ⏳ |

## Gates innegociables (Orquestador)

| Gate | Dónde / prueba | Estado |
|---|---|---|
| 1. Boundary Q1 (no control fitosanitario) | revisión de endpoints/copy; sin recomendaciones | ⏳ (vigilado desde Inc 1) |
| 2. Sin PII | `account` sin email/teléfono; `/auth/register` sin PII | ⏳ (modelo de datos definido) |
| 3. Sin gating | sin checks de nivel/capacitación | ⏳ |
| 4. Captura cámara-nativa + EXIF | móvil fuerza cámara; backend exige EXIF | ⏳ |
| 5. Obfuscación 1 km | `/public/*` con `ST_SnapToGrid`; exactas solo `/restricted/*` | ⏳ |
| 6. Paridad de entornos (conmutable sin nube) | `make_broker("memory")` ✅; `StorageProvider` Inc 2 | 🟡 (`contract/.../test_broker.py`) |
| 7. Trazabilidad | este documento | ✅ (vivo) |
| 8. Alcance validación (es-árbol + parásitos; rechaza especie/G4) | `contract/python/tests/test_schema.py` | ✅ |
| 9. Etiquetado válida/ruido autoritativo en backend | `contract/python/tests/test_verdict.py` + `test_models.py` (autoridad) | ✅ (regla) / 🟡 (puntos en backend) |
| 10. Contrato §6 (mock↔real sin cambios; conmutable) | `mock-validator/tests/test_worker_e2e.py` + `make_broker` | ✅ |

## Resumen del Incremento 1

**30 pruebas verdes** (`contract/python`: 21 · `mock-validator`: 9). Verificado: la frontera §6
(contrato + mock), la regla autoritativa de veredicto, el rechazo de especie/G4 (gate #8), el
etiquetado válida/ruido (gate #9), el transporte conmutable y el lazo E2E mock↔backend sin Redis
(gate #10), y el design system documentado (T7, parte de documentación).
