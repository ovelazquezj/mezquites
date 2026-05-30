# Matriz de trazabilidad — criterio de aceptación → prueba (gate #7)

> Cada criterio de aceptación de `bitacora_sdd_mezquite.md` tiene una prueba asociada. Estado:
> ✅ verificado · 🟡 parcial (frontera/spec lista; falta cliente o backend) · ⏳ planificado.
> Se actualiza en cada incremento. Mantenida por el Documentador técnico.

## Decisiones de producto (Q*)

| Criterio (bitácora) | Componente | Inc. | Prueba | Estado |
|---|---|---|---|---|
| **Q5.A** Captura SOLO cámara nativa | móvil | 3 | `mobile/test/capture_camera_test.dart` (galería deshabilitada; sin `image_picker`) | ✅ |
| **Q5.A** Cada observación lleva EXIF del momento de toma | móvil + backend | 2–3 | móvil inyecta EXIF GPS/fecha (`capture_service.dart` + test); backend exige `lat`/`lon`/`captured_at`: `backend/tests/test_observation_create.py` | ✅ |
| **Q5.A** UI no muestra estado de validación individual | móvil | 3 | móvil: `mobile/test/no_validation_state_test.dart` (modelo sin `validation_state`); backend tampoco lo devuelve | ✅ |
| **Q5.A** Imagen **válida** → puntos y se etiqueta como tal | backend | 2 | `backend/tests/test_worker_apply.py::test_valid_result_labels_valida_and_awards_deferred` | ✅ |
| **Q5.A** Imagen **no válida** → ruido, sin puntos | backend | 2 | `backend/tests/test_worker_apply.py::test_noise_result_labels_ruido_and_no_deferred` | ✅ |
| **Q5.A** Existe feedback **agregado** de tasa de validación | backend + móvil | 2–3 | backend `GET /me/feedback` agregado: `test_rankings_profile.py::test_feedback_is_aggregate_not_individual`; móvil: `profile_screen.dart` + `api_client_test.dart` | ✅ |
| **Q5.A** El submit no bloquea la UI (fire-and-forget) | backend + móvil | 2–3 | backend encola sin esperar: `test_observation_create.py::test_submit_enqueues_job_without_waiting`; móvil: cola local "pendiente" en `capture_screen.dart` | ✅ |
| **Q5.B** Vista pública solo coords a 1 km | backend | 2 | `backend/tests/test_obfuscation.py` (helper `obfuscate_1km`, EPSG:6372) + `backend/tests/test_roles.py::test_public_observations_are_obfuscated_to_1km` | ✅ |
| **Q5.B** Vista restringida exige auth de aliado firmante | backend | 2 | `backend/tests/test_roles.py::test_restricted_requires_aliado_firmante` / `test_restricted_allows_aliado_firmante_with_exact_coords` | ✅ |
| **Q5.B** Toda vista muestra fecha de snapshot (Qn) | backend + clientes | 2–4 | backend `/public/*` incluye `snapshot_quarter`; móvil `SnapshotStamp`; web admin `SnapshotStamp` + `boundary_test.dart` | ✅ |
| **Q5.B** La app NO genera PDFs (solo dashboards) | clientes | 3–4 | móvil `dashboard_boundary_test.dart` + web admin `boundary_test.dart` (sin dep pdf/printing; sin botón export) | ✅ |
| **Q7** Disclaimer una vez tras crear cuenta; descarte 1 tap; en Ayuda | móvil | 3 | `mobile/test/disclaimer_test.dart` | ✅ |
| **Q3** Selector con 4 opciones G4 + rango % visible | móvil | 3 | `mobile/test/g4_selector_test.dart` | ✅ |
| **Q3** Dos toggles binarios independientes | móvil | 3 | `mobile/test/observation_form_test.dart` (toggles independientes) | ✅ |
| **Q3** Backend acepta la triple etiqueta | backend | 2 | `backend/tests/test_observation_create.py::test_submit_accepts_eight_labels_and_returns_base_reward` (nivel G4 + 2 flags) | ✅ |
| **Q2** Submit con 8 campos | backend + móvil | 2–3 | backend (`ObservationCreate`) + móvil `observation_form_test.dart` + `api_client_test.dart` (multipart 8 etiquetas + imagen) | ✅ |
| **Q2** Backend asigna `tree_id` según R3 (10 m) | backend | 2 | `backend/tests/test_tree_grouping.py` (`ST_DWithin 10` sobre geography) | ✅ |
| **Q2** Dashboard muestra handle por observación | backend + clientes | 2–4 | backend `/public/observations` incluye `handle`; móvil `dashboard_screen.dart`; web admin `public_dashboard_screen.dart` | ✅ |
| **Q4** Perfil muestra etiqueta L3 | backend + móvil | 2–3 | backend `GET /me/profile` + móvil `profile_screen.dart` (identidad/lifelist/insignias) | ✅ |
| **Q4** Ningún módulo gatea por nivel | clientes + backend | 2–4 | backend sin checks de nivel; móvil `mobile/test/no_gating_test.dart` | ✅ |
| **Q4** Registro permite elegir institución y "solicitar agregar" | backend + móvil | 2–3 | backend `GET /institutions` público: `backend/tests/test_institutions_public.py`; móvil dropdown en `register_screen.dart` consume `/institutions` + "solicitar agregar" | ✅ |
| **Q4** Rankings por periodo (individual + institución) | backend | 2 | `backend/tests/test_rankings_profile.py::test_rankings_individual_and_by_institution` | ✅ |
| **Q6** Dashboard expone indicadores social/educativo/ecológico automáticos | backend | 2 | `backend/tests/test_indicators.py::test_indicators_compute_automatically` | ✅ |
| **Q6** Ningún indicador dispara aprobación/reprobación (U1) | backend | 2 | `backend/tests/test_indicators.py::test_indicators_have_no_threshold_logic` (AST: sin umbrales en código) | ✅ |
| **Q6** Indicadores organizacionales capturados manualmente en la web admin (amendment) | web admin | 4 | `POST /admin/indicators/organizational` desde `org_indicators_screen.dart`; `web-admin/test/api_client_test.dart` (sin umbrales, U1) | ✅ |
| **Q8** Toda observación atribuible a estado y municipio | backend | 2 | `derive_estado_municipio` (join `admin_boundary`); `/restricted` y filtros exponen estado/municipio · admin_boundary se carga por separado | 🟡 (lógica ✅; carga de límites = dato operativo) |
| **Q8** Dashboards y rankings con filtro geográfico | backend | 2 | `backend/tests/test_rankings_profile.py::test_rankings_geo_filter` + `test_indicators.py::test_indicators_filter_by_estado` | ✅ |
| **Q8** Agregar un estado no requiere nueva infraestructura (RC1) | infra | 2 | estado = filtro (`WHERE estado=...`), sin multi-tenancy: revisión + filtros geográficos ✅ | ✅ |

## Decisiones técnicas (T*)

| Criterio | Componente | Inc. | Prueba | Estado |
|---|---|---|---|---|
| **T1** Compila/corre en emulador y dispositivo Android; captura inyecta lat/lon/timestamp reales | móvil | 3 | `flutter build apk --debug` ✅ (APK generado) + `flutter analyze` limpio + 30 tests; cámara/EXIF real en hardware via `integration_test/capture_exif_test.dart` | 🟡 (compila ✅; cámara real en hardware = Inc 5) |
| **T2** Endpoints REST documentados (OpenAPI) y consumibles por ambos clientes | backend | 2 | `/api/v1/openapi.json` + `backend/tests/test_openapi.py` (esquema + endpoints presentes) | ✅ |
| **T3** Consulta agrupa dentro de 10 m | backend/DB | 2 | `backend/tests/test_tree_grouping.py` (`ST_DWithin 10` contra PostGIS real) | ✅ |
| **T3** Consulta devuelve coord redondeada a celda de 1 km | backend/DB | 2 | `backend/tests/test_obfuscation.py` (`obfuscate_1km`, proyección métrica EPSG:6372) | ✅ |
| **T4** Cambiar entorno alterna disco local ↔ bucket sin tocar código | backend | 2 | `backend/tests/test_storage_provider.py` (local + s3 con moto) | ✅ |
| **T5** Levanta en K8s local con un comando; mismos manifiestos a stg/prod | infra | 2–3 | `infra/k8s/` (base+overlays kustomize); `kubectl apply -k infra/k8s/overlays/dev` / `deploy-dev.ps1`; render limpio + `--dry-run=server` contra k3s; overlays stg/prod parametrizan vía patches | ✅ (manifiestos+dry-run; apply E2E real = Inc 5) |
| **T6** `submit` retorna sin esperar al validador | backend | 2 | `backend/tests/test_observation_create.py::test_submit_enqueues_job_without_waiting` (InMemoryBroker) + E2E compose | ✅ |
| **T6** Resultado del **mock** dispara etiquetado válida/ruido y recompensa diferida correctos | contrato + backend | 1–2 | `backend/tests/test_worker_apply.py` (etiquetado + diferida + idempotencia) + E2E compose mock↔worker | ✅ |
| **T7** Existe design system documentado con tokens Rotary+verde | docs | 1 | `docs/design-system/design-tokens.json` + `.md` | ✅ |
| **T7** Ninguna pantalla introduce elementos fuera del sistema | clientes | 3–4 | móvil `theme_tokens_test.dart` + web admin `theme_tokens_test.dart` (tema solo desde `design-tokens.json`, sin hex literal) | ✅ |

## Gates innegociables (Orquestador)

| Gate | Dónde / prueba | Estado |
|---|---|---|
| 1. Boundary Q1 (no control fitosanitario) | revisión de endpoints/copy + `backend/tests/test_openapi.py::test_boundary_q1_no_phytosanitary_promises_in_spec` (escaneo del OpenAPI) | ✅ (backend) |
| 2. Sin PII | `account` sin email/teléfono; `/auth/register` y `/auth/recover` sin PII; token sin PII: `backend/tests/test_security_no_pii.py` (8 pruebas) | ✅ |
| 3. Sin gating | backend: sin checks de nivel/capacitación; móvil: Learning/HomeShell sin bloqueos, identidad no desbloquea: `mobile/test/no_gating_test.dart` | ✅ |
| 4. Captura cámara-nativa + EXIF | móvil: `CaptureService` solo `takePicture()` + EXIF, **sin `image_picker`/galería**: `mobile/test/capture_camera_test.dart`; backend exige `lat`/`lon`/`captured_at` | ✅ (build APK ✅; cámara real en hardware = Inc 5) |
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

## Resumen del Incremento 3 (móvil Flutter) + T5 (K8s)

Construidos por **subagentes dedicados** (Dev móvil + Infra/Arquitecto) y verificados por el
Orquestador. Total del repo: **112 pruebas verdes** (`contract`: 21 · `mock-validator`: 9 ·
`backend`: 52 · `mobile`: 30) + manifiestos K8s validados (render + `--dry-run=server` contra k3s)
+ **APK Android debug construido** (`flutter build apk` ✅, `flutter analyze` limpio).

- **Móvil (`mobile/`, Flutter 3.27):** app del voluntario completa — cuenta seudonimizada sin PII,
  disclaimer D1, captura **solo cámara nativa + EXIF** (galería deshabilitada), formulario de 8
  etiquetas (selector G4 de 4 opciones + 2 toggles + 2 dropdowns), aprendizaje sin gating,
  gamificación (lifelist/rankings/identidad), dashboards públicos obfuscados, feedback agregado.
  Tema generado **solo** desde `design-tokens.json`. Cerró gates **#3, #4, #9** en cliente y los
  criterios Q5.A/Q5.B/Q7/Q3/Q2/Q4 del lado móvil.
- **K8s (`infra/k8s/`):** base + overlays dev/stg/prod (kustomize). Dev levanta sin nube con un
  comando (`kubectl apply -k infra/k8s/overlays/dev`); stg/prod parametrizan storage S3 / DB·redis
  gestionados / validador real vía patches (proveedor cloud = H6, placeholder). El `mock-validator`
  es un Deployment aislado y sustituible (gate #10). T5 ✅ a nivel de manifiestos + dry-run.
- **Cierre Q4 (Orquestador):** se añadió `GET /institutions` público (`backend`) y el móvil lo
  consume en el alta — el voluntario ya puede elegir institución (antes 🟡).

**Pendiente declarado:** apply E2E real en clúster con build de imágenes (Tester/QA, Inc 5);
`integration_test` de cámara en hardware; web admin (Inc 4); placeholders de contenido AU2, texto
final del disclaimer e iconos de marca (dato por verificar / decisión humana).

## Resumen del Incremento 4 (web admin del consorcio)

Construido por el **subagente Dev web admin** (Flutter Web, decisión del Orquestador) y verificado
por mí. Total del repo: **138 pruebas verdes** (`contract`: 21 · `mock-validator`: 9 · `backend`: 52
· `mobile`: 30 · `web-admin`: 26). `flutter analyze` limpio + **`flutter build web` ✅**.

- **`web-admin/` (Flutter Web):** login admin sin PII (handle + código de respaldo vía
  `/auth/recover`), lista F3 (aprobar/crear instituciones), gestión de **aliados firmantes**
  (promover → coords exactas), **captura manual de indicadores organizacionales** (Q6 amendment, sin
  umbrales/U1), **snapshots trimestrales**, **dashboard público** (obfuscado 1 km + caveat de origen
  ciudadano + "Qn" + filtro por estado) y **dashboard restringido** (coords exactas, solo visible si
  el rol es autorizado). Sin generación de PDFs. Tema solo desde `design-tokens.json`.
- Cerró del lado web admin: Q4 (F3 + aliados), Q6 (organizacionales), Q5.B (snapshots/Qn/sin PDF/
  restringido por rol), Q8 (filtro geográfico), T7, y gates #1/#2/#5 en cliente.

**Punto de gobernanza para humanos (no es defecto):** con el contrato actual, `admin_consorcio`
**no** ve coords exactas a menos que también sea `aliado_firmante` (la bitácora otorga coords
exactas solo a "aliados firmantes"). El subagente respetó esto sin asumir herencia de acceso; si el
consorcio espera ver exactas, es una decisión humana (relacionada con EA3/H3, fuera del software).
