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
| **Q5.A** (CR-001) Toda observación nace **aceptada** y otorga puntos al subir | backend | CR-001 | `backend/tests/test_observation_create.py::test_submit_persists_aceptada` / `::test_submit_awards_base_and_deferred_on_upload` | ✅ |
| **Q5.A** (CR-001) Calidad por **revisión humana** (confirmada/rechazada) autoritativa en backend | backend | CR-001 | `backend/tests/test_review.py` (verdict cambia `estado_revision` + log `human_review`) | ✅ |
| **Q5.A** Existe resumen **agregado** de aportaciones (sin acusación individual) | backend + móvil | 2–CR-001 | backend `GET /me/feedback` agregado: `test_rankings_profile.py::test_feedback_is_aggregate_not_individual`; móvil: `profile_screen.dart` + `no_validation_state_test.dart` | ✅ |
| **Q5.A** El submit no bloquea la UI | backend + móvil | 2–CR-001 | backend responde 201 sin encolar: `test_observation_create.py::test_submit_does_not_enqueue_any_job`; móvil: cola local "pendiente" de envío en `capture_screen.dart` | ✅ |
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
| **T6** `submit` retorna sin esperar (CR-001: ya no encola) | backend | 2–CR-001 | `backend/tests/test_observation_create.py::test_submit_does_not_enqueue_any_job` + `test_yolo_disconnected.py` (InMemoryBroker) | ✅ |
| ~~**T6** Resultado del **mock** dispara etiquetado válida/ruido~~ | — | — | **Superado por CR-001** (validación automática retirada; ver "Revisión humana" abajo). Código YOLO conservado e importable: `test_yolo_disconnected.py` | ⏸️ |
| **T7** Existe design system documentado con tokens Rotary+verde | docs | 1 | `docs/design-system/design-tokens.json` + `.md` | ✅ |
| **T7** Ninguna pantalla introduce elementos fuera del sistema | clientes | 3–4 | móvil `theme_tokens_test.dart` + web admin `theme_tokens_test.dart` (tema solo desde `design-tokens.json`, sin hex literal) | ✅ |

## Gates innegociables (Orquestador)

| Gate | Dónde / prueba | Estado |
|---|---|---|
| 1. Boundary Q1 (no control fitosanitario) | revisión de endpoints/copy + `backend/tests/test_openapi.py::test_boundary_q1_no_phytosanitary_promises_in_spec` (escaneo del OpenAPI) | ✅ (backend) |
| 2. ~~Sin PII~~ → **Acotado por CR-002** | Identidad real con mínima PII: voluntario guarda solo `provider_subject` (sin email/nombre); email SOLO para `administrador` (CHECK `ck_account_email_only_admin`); token sin PII. `backend/tests/test_security_no_pii.py` + `test_auth_google.py::test_ac4_*` + `test_auth_login_admin.py` | ✅ acotado |
| 3. Sin gating | backend: sin checks de nivel/capacitación; móvil: Learning/HomeShell sin bloqueos, identidad no desbloquea: `mobile/test/no_gating_test.dart` | ✅ |
| 4. Captura cámara-nativa + EXIF | móvil: `CaptureService` solo `takePicture()` + EXIF, **sin `image_picker`/galería**: `mobile/test/capture_camera_test.dart`; backend exige `lat`/`lon`/`captured_at` | ✅ (build APK ✅; cámara real en hardware = Inc 5) |
| 5. Obfuscación 1 km | `/public/*` obfusca server-side (`obfuscate_1km`, EPSG:6372); exactas solo `/restricted/*` (rol firmante): `test_obfuscation.py` + `test_roles.py`. **CR-001:** la imagen de revisión se sirve con **EXIF GPS saneado** salvo `aliado_firmante`: `backend/tests/test_review.py::test_ac4_image_gps_stripped_for_evaluador/analista` + `::test_ac4_image_keeps_gps_only_for_aliado_firmante` | ✅ |
| 6. Paridad de entornos (conmutable sin nube) | `make_broker("memory")` + `StorageProvider` local↔s3 + `DATABASE_URL`: `test_storage_provider.py`; compose dev sin nube (storage local, redis/postgis local) | ✅ |
| 7. Trazabilidad | este documento + `human_review` (log append-only de veredictos) | ✅ (vivo) |
| 8. ~~Alcance validación automática (es-árbol + parásitos)~~ | **Enmendado por CR-001** (bitácora): se elimina la validación automática; calidad por revisión humana. El backend sigue sin validar especie/G4 (autodeclarados) | ⏸️ enmendado |
| 9. ~~Etiquetado válida/ruido autoritativo~~ | **Reemplazado por CR-001:** aceptación por defecto + veredicto humano autoritativo en backend; público = no-rechazadas. `backend/tests/test_review.py` (AC1/AC2) | ⏸️ enmendado |
| 10. ~~Contrato §6 (mock↔real)~~ | **Inactivo por CR-001:** la frontera §6 no se borra pero el submit ya no encola: `backend/tests/test_yolo_disconnected.py` | ⏸️ inactivo |

## CR-001 — Revisión humana en el backend (sin YOLO)

> Decisión humana del 2026-06-15 (ver `docs/change-requests/CR-001-revision-humana.md` y el amendment
> de Q5.A-D1 + gates #8/#9/#10 en la bitácora). Aceptación por defecto + veredicto humano; YOLO inactivo.

| AC | Descripción | Prueba | Estado |
|---|---|---|---|
| **AC1** | Observación recién subida → `aceptada` y aparece en `/public/observations` | `backend/tests/test_review.py::test_ac1_new_observation_is_aceptada_and_public` | ✅ |
| **AC2** | `verdict {rechazada}` la saca del público y escribe en `human_review` | `backend/tests/test_review.py::test_ac2_reject_removes_from_public_and_logs` | ✅ |
| **AC3** | `analista` → 403 al emitir veredicto; `evaluador`/`administrador` → 200 | `backend/tests/test_review.py::test_ac3_analista_cannot_emit_verdict` / `::test_ac3_evaluador_and_admin_can_emit_verdict` | ✅ |
| **AC4** (gate #5) | `/review/.../image` sin EXIF GPS para evaluador/analista; con GPS solo aliado_firmante | `backend/tests/test_review.py::test_ac4_image_gps_stripped_for_evaluador` / `::..._for_analista` / `::test_ac4_image_keeps_gps_only_for_aliado_firmante` (+ `test_original_image_actually_has_gps`) | ✅ |
| **AC5** | Web-admin: cola + detalle con imagen + confirmar/rechazar; analista ve Monitor sin botones | `web-admin/test/widget_review_test.dart` + `review_api_test.dart` | ✅ |
| **AC6** | App móvil muestra "registrada y aceptada"; sin estado individual | `mobile/test/no_validation_state_test.dart::AC6...` | ✅ |
| **AC7** | El submit NO encola ningún job | `backend/tests/test_observation_create.py::test_submit_does_not_enqueue_any_job` + `test_yolo_disconnected.py` | ✅ |
| **AC8** | Trazabilidad AC1–AC7 + suite global verde | este documento + corridas abajo | ✅ |

**Pruebas verdes tras CR-001:** `backend`: **65** · `web-admin`: **37** · `mobile`: **31** (`contract`: 21 ·
`mock-validator`: 9 sin cambios). Migración Alembic `0002_revision_humana` verificada (`upgrade`/`downgrade`
en PostGIS). Gate #5 (EXIF GPS saneado) verificado con imágenes JPEG reales (Pillow). `flutter analyze`
limpio en móvil y web-admin.

## CR-002 — Autenticación con identidad real (Google/Firebase + usuario/contraseña)

> Decisión humana del 2026-06-15 (ver `docs/change-requests/CR-002-auth-identidad-real.md` y el
> amendment de Q5.D-D1 + gate #2 acotado en la bitácora). App = Sign in with Google (solo `sub`
> opaco); backend = usuario/contraseña (argon2). Proveedor de auth conmutable (`mock|firebase`).

| AC | Descripción | Prueba | Estado |
|---|---|---|---|
| **AC1** | `POST /auth/google` (mock) crea `voluntario` (solo `provider_subject`, sin email/nombre) + JWT válido | `backend/tests/test_auth_google.py::test_ac1_google_login_creates_voluntario_and_returns_jwt` / `::test_ac1_google_login_persists_only_opaque_subject` / `::test_ac1_second_login_same_subject_reuses_account` | ✅ |
| **AC2** | `POST /auth/login` valida usuario/contraseña (hash) y rechaza credenciales malas | `backend/tests/test_auth_login_admin.py::test_ac2_login_ok_with_valid_credentials` / `::test_ac2_login_rejects_bad_password` / `::test_ac2_login_rejects_unknown_user` | ✅ |
| **AC3** | El administrador crea `evaluador` (sin email) y 2º `administrador` (con email); `register` ya no acepta `role` | `backend/tests/test_auth_login_admin.py::test_ac3_admin_creates_evaluador_without_email` / `::test_ac3_admin_creates_second_admin_with_email` / `::test_ac3_register_no_longer_accepts_role` / `::test_ac3_evaluador_with_email_is_rejected` | ✅ |
| **AC4** | Sin PII de más: ninguna cuenta `voluntario` guarda email/nombre (CHECK lo blinda) | `backend/tests/test_auth_google.py::test_ac4_db_rejects_email_on_voluntario` / `::test_ac4_no_voluntario_account_carries_pii` + `test_security_no_pii.py::test_account_model_has_no_pii_columns` | ✅ |
| **AC5** | `AUTH_PROVIDER=mock` corre la suite sin red (gate #6) | `backend/tests/test_auth_google.py::test_ac5_mock_provider_runs_offline_with_fixed_token` (+ `conftest` fija `AUTH_PROVIDER=mock`) | ✅ |
| **AC6** | App: "Entrar con Google" completa login mockeado; sin código de respaldo/QR | `mobile/test/google_signin_test.dart` + `no_pii_test.dart` (payload solo `id_token`; sin `/auth/register`,`/auth/recover`); `flutter build apk --release` ✅ sin `google-services.json` | ✅ |
| **AC7** | Web-admin entra con usuario/contraseña; el administrador ve gestión de usuarios | `web-admin/test/widget_login_test.dart` + `session_test.dart` + `widget_users_test.dart` | ✅ |
| **AC8** | Trazabilidad AC1–AC7 + suite global verde | este documento + corridas abajo | ✅ |

**Gate #2 (acotado):** ninguna cuenta `voluntario` guarda email/teléfono/nombre (solo `provider_subject`
opaco); el `email` lo porta SOLO `administrador` (CHECK `ck_account_email_only_admin`); el JWT no lleva
PII. Verificado por `test_auth_google.py::test_ac4_*` y `test_security_no_pii.py`.

**Pruebas verdes tras CR-002:** `backend`: **86** · `web-admin`: **43** · `mobile`: **40** (`contract`: 21 ·
`mock-validator`: 9 sin cambios) = **199 verdes**. Migración Alembic `0003_auth_identidad` verificada
(`upgrade`/`downgrade`/`upgrade` en PostGIS efímero). `flutter analyze` limpio en móvil y web-admin;
`flutter build apk --release` (móvil, sin `google-services.json`) y `flutter build web` (web-admin) ✅.
Build sin Firebase real: la init de Firebase es condicional a `AUTH_MODE=firebase`.

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

## CR-009 — Mapa de calor público (celdas 300 m)

Construido por dos subagentes (A backend ∥ B móvil) e integrado/verificado por el Orquestador.
**Total del repo tras CR-009: 250 pruebas verdes** (`contract` 21 · `mock` 9 · `backend` 111 ·
`mobile` 56 · `web-admin` 53). `flutter analyze` limpio + `flutter build web` ✅.

| Criterio (CR-009 §6) | Prueba / verificación |
|---|---|
| AC1 vista Mapa = mapa de calor (móvil+web), sin indicadores/lista | `mobile/test/heat_map_test.dart` (render capa + leyenda + popup); `flutter build web` ✅ |
| AC2 entrada pública sin login | `welcome_screen.dart` botón "Ver el mapa público" → `HeatMapScreen.openPublic`; endpoints `public/*` sin auth |
| AC3 botón ⓘ con disclaimer + indicadores | `heat_map_test.dart` (bottom sheet ⓘ) |
| AC4 gate #5 a 300 m (público nunca < celda) | `backend/tests/test_obfuscation.py` (umbral 300 m); `test_public_grid.py` (claves exactas de celda) |
| AC5 `GET /public/grid` agrega no-rechazadas | `backend/tests/test_public_grid.py` (agregación, exclusión de rechazadas, filtro estado) |
| AC6 siembra de Aguascalientes | `backend/tests/test_seed_demo.py` (idempotencia, sin PII); verificación CLI → 9 celdas, 11 obs |
| AC7 `CAVEAT` sin "validación automática"; suites verdes; web-admin intacto | `indicators.py::CAVEAT`; `pytest` 111 + `flutter test` 56; `git diff` vacío fuera de `backend/`+`mobile/` |

**Enmienda de gate:** gate #5 (1 km → 300 m) registrada en `bitacora_sdd_mezquite.md` (gate #5 y
Q5.B-D1, 2026-06-16). Sigue ocultando el árbol exacto; coords exactas solo a `aliado_firmante`;
conmutable por `obfuscation_grid_m` (gate #6). **Pendiente humano:** `admin_boundary` no cargado ⇒ la
derivación de estado/municipio queda en `None` (el mapa no filtra por estado; muestra todas las celdas).

## CR-010 — Lote de mejoras (branding, mapa consola, analista, evaluación, captura, instituciones, evidencia)

Construido por 3 subagentes en paralelo (backend ∥ móvil ∥ web-admin) e integrado/verificado por el
Orquestador. **Total del repo tras CR-010: 292 pruebas verdes** (`contract` 21 · `mock` 9 · `backend` 131 ·
`mobile` 61 · `web-admin` 70). `flutter build web` ✅ (móvil + web-admin); migración 0005 en head.

| Criterio (CR-010) | Prueba / verificación |
|---|---|
| #1 logo horizontal + Club en headers | `web-admin/test/widget_map_data_test.dart` ("el header muestra el logo"); keys `login-logo`/`appbar-logo` |
| #2 mapa en consola para todos los roles | `widget_map_data_test.dart` ("Mapa visible para {evaluador,analista,administrador,admin_consorcio}") |
| #3 analista: tabla/filtros/resúmenes/CSV (obfuscado 300 m) | `widget_map_data_test.dart` (datos + Descargar CSV); `backend/tests/test_cr010_analytics.py` (CSV celda 300 m, summary) |
| #4 evaluador ve imagen y taggea (3 estados) | visor `Image.memory` (web); `backend/tests/test_cr010_verdict_aceptada.py` (veredicto `aceptada`) |
| #5 estado/municipio en captura (auto-detecta, editable) | `mobile/test/observation_form_test.dart` (auto-detección + editable); `backend/tests/test_cr010_autodeclared_estado.py` |
| #5 tablas con scroll horizontal | `DataTable` envueltas en `SingleChildScrollView` horizontal (public/restricted/review/datos) |
| #6 registrar institución (móvil) + siembra | `mobile/test/cr010_movil_test.dart` (POST request); `backend/tests/test_cr010_institutions_request.py`; `seed_institutions.py` (8 universidades) |
| #7 evidencia (capturas+horas) + sesiones en backend | `mobile/test/cr010_movil_test.dart` (evidencia + SessionTracker); `backend/tests/test_cr010_sessions_evidence.py` |

**Gate #5:** el CSV y el mapa de la consola exponen solo celda 300 m. **Migración 0005**
(`participation_session` + CHECK de veredicto con `aceptada`) validada upgrade/downgrade. **Decisiones del
usuario** registradas en `docs/change-requests/CR-010-lote-mejoras.md`.

## CR-011 — Ajustes post-CR-010 (hallazgos de revisión visual)

Ejecutado directo sobre `main` por el Orquestador. **Total del repo tras CR-011: 299 pruebas verdes**
(`contract` 21 · `mock` 9 · `backend` **136** · `mobile` **61** · `web-admin` **72**). Sin migración nueva.

| Hallazgo | Arreglo | Prueba / verificación |
|---|---|---|
| #1 logo diminuto | logo 32→44 + `toolbarHeight` | `web-admin` build; `widget_map_data_test` ("header muestra el logo") |
| #2 tablas cortadas sin scroll | `HScroll` (Scrollbar visible) en 5 tablas | inspección + `flutter test` web-admin verde |
| #3 sin botones de revisión | filas clicables (`onSelectChanged`) + scroll expone "Abrir" | `widget_review_test` (3 botones de veredicto) |
| #4 "Datos" no funciona | nuevo `GET /admin/analytics/observations` (faltaba → 404) | `backend/tests/test_cr011_consola_analytics.py`; verificado vivo (2 filas) |
| #5a sin página de instituciones para admin | nav + `_admin` incluyen `administrador`; `POST /admin/institutions/{id}/approve` | `test_cr011_consola_analytics.py` (administrador usa consola; aprobar); `widget_cr011_test.dart` |
| #5b móvil: registrar institución desde login | "Registrar nueva institución" (opción A) + `/institutions/request` asocia la cuenta | `test_cr011_consola_analytics.py` (asociación); `mobile` build + `legal_test` |

**Gate #5:** `GET /admin/analytics/observations` NO expone coords exactas (prueba lo verifica). Decisiones
del usuario y causa raíz de cada hallazgo en `docs/change-requests/CR-011-ajustes-post-cr010.md`.

## CR-012 — Paginación de tablas + header (solo web-admin)

Directo sobre `main`. **Total tras CR-012: 301 pruebas verdes** (`contract` 21 · `mock` 9 · `backend` 136 ·
`mobile` 61 · `web-admin` **74**).

| Hallazgo | Arreglo | Prueba |
|---|---|---|
| #1 barra horizontal hasta el final | páginas cortas (`PagedTable`) | `widget_cr012_test.dart` (rango "1–10 de 25") |
| #2 ¿paginan? | sí: `PagedTable<T>` cliente (10/25/50) en las 5 tablas | `widget_cr012_test.dart` ("Siguiente" avanza) |
| #3 header pequeño | logo 44→56, AppBar 64→80, Club como subtítulo (el logo ya era correcto) | `widget_map_data_test` (`appbar-logo`); web-admin build |

Detalle en `docs/change-requests/CR-012-paginacion-header.md`.

## CR-013 — Licencia MIT + pantalla "Acerca de"

Directo sobre `main`. **Total tras CR-013: 303 pruebas verdes** (`contract` 21 · `mock` 9 · `backend` 136 ·
`mobile` **62** · `web-admin` **75**). Backend/contract/mock sin tocar (CR-013 no cambia backend).

| Requisito (usuario) | Implementación | Prueba |
|---|---|---|
| Licencia tipo MIT | `LICENSE` (raíz): `Copyright (c) 2026 Club Rotario Bosques Aguascalientes` + `Autor: Omar Velázquez <ovelazquezj@gmail.com>` | — (archivo) |
| "Acerca de" — voluntario | `mobile/.../about_screen.dart` desde **Perfil**; proyecto, `beta-2606`, copyright del Club, autoría + correo, MIT | `mobile/test/about_test.dart` |
| "Acerca de" — web-admin | `web-admin/.../about_screen.dart`, entrada del NavigationRail (todos los roles) | `web-admin/test/widget_about_test.dart` |
| Gate #2 (sin PII) | autoría/copyright = metadato del proyecto, no dato de usuario ni cambio al modelo | aserciones de copyright/autoría en ambos tests |

Detalle en `docs/change-requests/CR-013-licencia-acerca-de.md`.

## CR-015 — Autenticación con Google sin Firebase (Google Identity Services)

Directo sobre `main` + desplegado en la VM (Testing). **Total tras CR-015/016: 304 pruebas verdes**
(`contract` 21 · `mock` 9 · `backend` 136 · `mobile` **63** · `web-admin` 75). Amend de CR-002 / cierre
de CR-004 W1 por vía sin Firebase.

| Requisito (usuario) | Implementación | Prueba |
|---|---|---|
| Login con Google **sin Firebase** | App: GIS (`google_sign_in` 7.x + `google_sign_in_web`, `renderButton` + `authenticationEvents`) → ID token de Google; `google_auth_service.dart`, `welcome_screen.dart`, `main.dart` | `mobile/test/google_signin_test.dart` (contrato `signInWithGoogle`/`completeGoogleSignIn` intacto) |
| Backend verifica token de Google "puro" | `FirebaseAuthProvider` (`iss=accounts.google.com`, `aud=Web Client ID`); `google-auth`+`requests` en `pyproject.toml`; `AUTH_PROVIDER=firebase` + `GOOGLE_OAUTH_AUDIENCE` sin `FIREBASE_PROJECT_ID` | Verificación en vivo: `/auth/google` con token mock → **401** |
| Gate #2 (sin PII) | la app solo entrega el ID token; backend guarda solo el `sub` opaco | `google_signin_test.dart` (sin email/name en el cuerpo) |
| Gate #6 (conmutable) | `AUTH_MODE=mock`/`google`; `AUTH_PROVIDER=mock`/`firebase` | suites dev/test verdes en modo mock |

Detalle en `docs/change-requests/CR-015-auth-google-sin-firebase.md`.

## CR-016 — Botón "Instalar app" (PWA) en la app del voluntario

Directo sobre `main` (solo web). Sin backend ni migración.

| Requisito (usuario) | Implementación | Prueba |
|---|---|---|
| Botón propio "Instalar app" en Bienvenida y Perfil | `install_app_button.dart` (auto-oculta si no aplica); `welcome_screen.dart` + `profile_screen.dart` | `mobile/test/install_app_button_test.dart` (fuera de web no se muestra) |
| Disparar instalación aunque el banner esté en cooldown | `index.html` captura `beforeinstallprompt`; servicio `pwa_install*.dart` (import condicional) | manual en navegador (Android) |
| iOS sin prompt programático | instrucciones "Compartir → Agregar a inicio" | — |
| Gate #3 (sin gating) | el botón es opcional; nunca bloquea el uso | revisión |

Detalle en `docs/change-requests/CR-016-pwa-install.md`.

## CR-017 — Imágenes y base de datos en el Cloud Volume (bind durable y configurable)

Directo sobre `main` + aplicado en la VM. Infra/config; sin pruebas automáticas (verificación operativa).

| Requisito (usuario) | Implementación | Prueba |
|---|---|---|
| Imágenes **y** DB en el Cloud Volume, no en el disco raíz | `docker-compose.prod.yml` parametrizado `${OBSDATA_HOST_DIR:-obsdata}` / `${PGDATA_HOST_DIR:-pgdata}`; `.env.prod` con las rutas; `--env-file` | verificación en VM: captura aterriza en `/mnt/HC_Volume_106165488/obsdata`; `df` crece |
| Durable entre redeploys | parametrización versionada (ya no se edita el compose a mano) | runbooks actualizados sin paso de re-bind |
| Gate #6 (storage conmutable) | ruta = config; dev usa volúmenes nombrados | — |

Detalle en `docs/change-requests/CR-017-almacenamiento-cloud-volume.md`.
