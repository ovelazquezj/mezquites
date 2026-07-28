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
| ~~**Q5.B** Vista pública solo coords a 1 km~~ → **CR-025:** vista pública **exacta** | backend | CR-025 | `backend/tests/test_public_grid.py` (grid = binning del calor) + `test_obfuscation.py` (helper de binning) + `test_roles.py` (público devuelve coords exactas) | ✅ |
| **Q5.B** (CR-025) Ubicación exacta disponible a público y a todos los roles de consola | backend | CR-025 | `backend/tests/test_roles.py` + `test_cr023_ubicacion_exacta.py` (`EXACT_LOCATION_ROLES` incluye `evaluador`) | ✅ |
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
| 5. Obfuscación 1 km→300 m (CR-009) | `/public/*` obfusca server-side (celda 300 m); exactas en `/restricted/*` y CSV. **CR-023:** exactas en la consola para `EXACT_LOCATION_ROLES` (`aliado_firmante`/`administrador`/`admin_consorcio`/`analista`), público intacto (300 m): `test_obfuscation.py` + `test_roles.py`. **CR-001:** la imagen de revisión se sirve con **EXIF GPS saneado** salvo `aliado_firmante`: `backend/tests/test_review.py::test_ac4_image_gps_stripped_for_evaluador/analista` + `::test_ac4_image_keeps_gps_only_for_aliado_firmante` | ✅ |
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
| ~~**AC4** (gate #5) `/review/.../image` sin EXIF GPS~~ → **Retirado (CR-025)** | `/review/.../image` sirve la imagen **con** su GPS a todos los roles (ubicación exacta ya es pública); `app/exif.py` ocioso | `backend/tests/test_review.py` (actualizado en CR-025) | ✅ |
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
| Licencia tipo MIT | `LICENSE` (raíz): `Copyright (c) 2026 Club Rotario Bosques Aguascalientes` + `Autor: Omar Velázquez <contacto@rescatando-el-mezquite.org>` | — (archivo) |
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

## CR-018 — Cámara web robusta (`getUserMedia`)

Directo sobre `main` (solo el camino web). Sin backend ni migración. **Total tras CR-018..022: 325
pruebas verdes** (`contract` 21 · `mock` 9 · `backend` **144** · `mobile` **66** · `web-admin` **85**).

| Requisito (usuario) | Implementación | Prueba / verificación |
|---|---|---|
| La cámara web pide permiso del navegador | camino principal `getUserMedia` + preview `<video>` → `<canvas>` `toBlob('image/jpeg')` → bytes; `getUserMedia` dispara el permiso | `flutter build web` ✅; preview/permiso real en dispositivo (rutas web-only no se compilan en la VM) |
| No bloquear dispositivos no reconocidos (Honor X9) | se **quitó la compuerta de UA** (`isMobileWebBrowser` ya no deshabilita; pista informativa sin uso vivo) | `flutter test` 66 verdes |
| Robustez de cámara | `facingMode {ideal:'environment'}` con reintento `{video:true}` ante `OverconstrainedError`; `enumerateDevices()` + "Cambiar cámara"; teardown que detiene todos los tracks | revisión + build web |
| Recuperación ante error | mapeo de errores por `name` a textos en español; UI con "Reintentar" / "Tomar con la cámara del sistema" (fallback `image_picker`) / "Reportar un problema" (CR-019) | revisión `capture_pane_web.dart` |
| Gate #4 (cámara, nunca galería) | ambos caminos son cámara en vivo; escritorio con webcam captura como cámara | revisión |
| Gate #3 (sin gating) | ningún dispositivo queda bloqueado por UA | revisión |

Detalle en `docs/change-requests/CR-018-camara-web-robusta.md`.

## CR-019 — "Reportar un problema" + vista de admin + diagnóstico

Directo sobre `main` (backend + móvil + web-admin). **Migración 0006_problem_reports** (down_revision 0005).

| Criterio (CR-019) | Implementación | Prueba |
|---|---|---|
| Reporte con auth **opcional** (201 anónimo o con handle) | `POST /problem-reports` (`get_current_user_optional`); modelo `ProblemReport` (tabla `problem_report`, status nuevo/visto/resuelto, `account_id`/`handle` nullable) | `backend/tests/test_problem_reports.py` (**8**) |
| Admin lista y cambia estado, gateado | `GET /admin/problem-reports`; `POST /admin/problem-reports/{id}/status`; gateo `admin_consorcio`/`administrador` | `test_problem_reports.py` (gateo + estados) |
| Vista de admin "Reportes" | `problem_reports_screen.dart` con `PagedTable` (Fecha/Contexto/Navegador/Versión/Usuario/Estado/Mensaje) + detalle `error_detail`; entrada NavigationRail gateada | `web-admin/test/problem_reports_test.dart` (**10**) |
| Móvil: reportar desde Bienvenida/Perfil/error de cámara | `ProblemReportScreen`, `ApiClient.submitProblemReport`, `device_diagnostics.dart` (export condicional: web manda `user_agent`+platform; VM stub) | suite móvil verde |
| Gate #2 (sin PII) | solo diagnóstico (user_agent/platform/app_version) + nota libre + error técnico; nunca email/nombre | `test_problem_reports.py` |
| Gate #3 (sin gating) | funciona sin login (auth opcional) | `test_problem_reports.py` (alta anónima) |

Detalle en `docs/change-requests/CR-019-reportar-problema.md`.

## CR-020 — Quitar el sello "BORRADOR" de Términos/Aviso (ya aprobados)

Directo sobre `main` (solo lo legal). Sin backend ni migración. Cierra el pendiente de CR-006.

| Criterio (CR-020) | Implementación | Prueba |
|---|---|---|
| Móvil: sin banner BORRADOR en lo legal | se quitó `InfoNote(Copy.legalDraftBanner)` de `legal_screen.dart` + constante `legalDraftBanner` de `copy.dart` | `mobile/test/legal_test.dart` (`findsNothing` 'BORRADOR') |
| Web-admin: sin sello + contacto real | se quitó `_DraftBadge`/`Copy.legalDraftBadge`; `legalIntro` (aprobados); "Contacto" → contacto@rescatando-el-mezquite.org + domicilio | `web-admin/test/widget_legal_test.dart` (sin sello) |
| "Aprender" sigue en borrador | `learningDraftBanner` **conservado** (revisión AU2/H4) | revisión |
| Gate #2 (sin PII) | contacto/domicilio = dato del responsable, no de usuario | revisión |

Detalle en `docs/change-requests/CR-020-legal-sin-borrador.md`.

## CR-021 — `InfoNote` colapsable / descartable (móvil)

Directo sobre `main`. Sin backend ni migración.

| Criterio (CR-021) | Implementación | Prueba |
|---|---|---|
| Cerrar un aviso informativo | `InfoNote` → StatefulWidget con botón "X" (key `info_note_dismiss`) | **3** pruebas nuevas (móvil): oculta, persiste, `dismissible:false` sin "X" |
| Recordar el descarte entre sesiones | `SharedPreferences` (+ `localStorage` en web); acceso defensivo `try/catch`; id por `id` opcional o derivado del texto | pruebas de persistencia |
| Aplicación por defecto + fijos | 12 usos `dismissible:true`; claves fijas con `dismissible:false` (p. ej. intro de "Reportar un problema") | revisión `common.dart` |
| Gate #3 (sin gating) | cerrar el aviso NO bloquea nada | revisión |

Detalle en `docs/change-requests/CR-021-avisos-descartables.md`.

## CR-022 — Cada foto registra su propio árbol (ENMIENDA a R3 / T3)

Directo sobre `main` (backend). ⚠️ **Enmienda a decisión SELLADA** (R3/T3, 10 m → 1:1), autorizada por el
usuario el 2026-06-28; anotada en la bitácora (Q2-D1 y T3) con el estilo de CR-001/CR-009.

| Criterio (CR-022) | Implementación | Prueba |
|---|---|---|
| ~~**Q2/T3** Backend agrupa dentro de 10 m bajo un `tree_id`~~ | **Enmendado:** `assign_tree` siempre crea un `Tree` nuevo (1:1); se quitó la reutilización por `ST_DWithin`; `observation_seq`=1 | `backend/tests/test_tree_grouping.py` (reescrito: dos obs cercanas → **2 árboles**) |
| El mapa público no se ve afectado | el mapa de calor agrega por celda de 300 m, no por árbol | `test_public_grid.py` (sin cambios) |
| Gate #5 (obfuscación) | intacto: público sigue a 300 m | revisión |

**Consecuencia documentada:** se pierde la serie temporal por árbol (revisitas = árboles distintos);
atenuante: el ruido del GPS de celular (~3–10 m) ya hacía la re-agrupación poco fiable. Detalle en
`docs/change-requests/CR-022-foto-por-arbol.md`.

## CR-023 — Ubicación EXACTA en la consola (mapa + tabla restringida + CSV) para reportes

Directo sobre `main` (backend + web-admin). ⚠️ **Enmienda ACOTADA al gate #5** (obfuscación), autorizada
por el usuario el 2026-07-02; anotada en la bitácora (gate #5 y Q5.B-D1) con el estilo de CR-009. Sin
migración nueva. **La vista pública NO cambia** (sigue a celda 300 m). Nuevo conjunto de roles con acceso
a exactas: `EXACT_LOCATION_ROLES = (aliado_firmante, administrador, admin_consorcio, analista)`.

| AC (CR-023 §5) | Implementación | Prueba |
|---|---|---|
| **AC1** `GET /restricted/observations` acepta los 4 roles de `EXACT_LOCATION_ROLES` (exactas) y **rechaza** `voluntario`/`evaluador` (403); sin token → 401 | chequeo por `EXACT_LOCATION_ROLES` en `routers/restricted.py` (sustituye el `aliado_firmante` directo) | `backend/tests/test_cr023_ubicacion_exacta.py` (restricted acepta `aliado_firmante`/`administrador`/`admin_consorcio`/`analista`; rechaza `voluntario`/`evaluador`) |
| **AC2** CSV exacto vs. obfuscado por rol | `GET /admin/analytics/observations.csv` → `lat`/`lon` para `EXACT_LOCATION_ROLES`; `lat_celda_300m`/`lon_celda_300m` para el resto (p. ej. `evaluador`) | `backend/tests/test_cr023_ubicacion_exacta.py` (columnas exactas para admin/analista vs. `*_celda_300m` para evaluador) + `test_cr010_analytics.py` (obfuscación 300 m con `evaluador`) |
| **AC3** público intacto (nada más fino que 300 m; ningún endpoint público expone exactas) | `GET /public/grid` y `GET /public/observations` sin cambios | `backend/tests/test_obfuscation.py` + `test_public_grid.py` (sin regresión) |
| **AC4** web-admin: toggle "Mapa de calor (300 m) / Ubicaciones exactas" **visible solo** para los 4 roles; default = calor | `map_screen.dart` (toggle gateado por `canSeeExactLocation`) | `web-admin/test/widget_map_exact_test.dart` (toggle presente para administrador/analista/admin_consorcio; ausente para `evaluador`/sin sesión) |
| **AC5** web-admin: modo exacto renderiza **un marcador por árbol** + **banner** de uso interno | `map_screen.dart` (capa de marcadores exactos + banner "no publicar sin obfuscar") | `web-admin/test/widget_map_exact_test.dart` (N marcadores + banner `map_exact_banner` en modo exacto) |
| **AC6** getter `canSeeExactLocation` verdadero exactamente para `EXACT_LOCATION_ROLES`; gobierna toggle + vista restringida | `session.dart` (getter por rol) | `web-admin/test/session_test.dart` (getter) + `widget_shell_test.dart` (tabla restringida visible para admin_consorcio, no para evaluador) + nota CSV exacto `widget_map_data_test.dart` (`data-exact-note`) |
| **AC7** suites verdes; móvil y vista pública sin cambios; gate #5 enmendado en bitácora + trazado aquí | — | corridas de suites (números reales abajo) |

**Gate #5 (enmendado, acotado):** el público sigue a 300 m; dentro de la consola, `EXACT_LOCATION_ROLES`
ve exactas para reportes. **Salvaguarda:** default a calor 300 m + banner de uso interno; qué se publica
es responsabilidad operativa. Decisiones del usuario en `docs/change-requests/CR-023-ubicacion-exacta-consola.md`.

> **Total de pruebas tras CR-023: 345 verdes** (21 contrato · 9 mock · 153 backend · 66 móvil · 96 web-admin),
> corridas por el orquestador el 2026-07-02. Delta sobre las 325 previas: **+9 backend** (test_cr023 +
> ajuste de 1 test de analytics) y **+11 web-admin** (toggle exacto, getter, shell y nota CSV). Móvil,
> contrato y mock sin cambios.

## CR-025 — Ubicación EXACTA pública (retira la obfuscación del gate #5)

Directo sobre `main` (backend + móvil/web-voluntario + web-admin + docs). **Retira la parte pública del
gate #5** (obfuscación), por **decisión de gobernanza del Club** (legales del punto 5 re-aprobados). Sin
migración. Supera los criterios de obfuscación pública de **CR-009** y la restricción de exactas de
**CR-023** (que dejan de aplicar al público). `geo.obfuscate_to_grid` y `app/exif.py` se conservan
**ociosos** (binning del calor / módulo sin uso). Sin mención de motivaciones externas en el código/docs.

| AC (CR-025) | Implementación | Prueba |
|---|---|---|
| **AC1** `GET /public/observations` devuelve coords **exactas** (== guardadas) | `routers/public.py` sin `obfuscate_to_grid` | `backend/tests/test_roles.py` / `test_obfuscation.py` (público exacto) |
| **AC2** El **mapa de calor** se conserva: `/public/grid` agrega por celda (binning) | `routers/public.py` (sin cambios funcionales) | `backend/tests/test_public_grid.py` |
| **AC3** `EXACT_LOCATION_ROLES` incluye `evaluador` ⇒ exactas para **todos** los roles de consola; CSV exacto | `models.py` + `routers/restricted.py` + `routers/analytics.py` | `backend/tests/test_cr023_ubicacion_exacta.py` / `test_cr010_analytics.py` (actualizados) |
| **AC4** `GET /review/.../image` sirve la imagen **con GPS** (saneo retirado) | `routers/review.py` sin `strip_gps` | `backend/tests/test_review.py` (actualizado) |
| **AC5** Mapa **público** (móvil/web-voluntario): toggle calor⇄exacto (default calor) + pines exactos | `mobile/lib/src/ui/screens/heat_map_screen.dart` | `mobile/test/heat_map_test.dart` |
| **AC6** Consola: se conserva el toggle; modo exacto abierto a **todos** los roles; sin banner de "uso interno" | `web-admin/.../map_screen.dart` + `session.dart` | `web-admin/test/widget_map_exact_test.dart` / `session_test.dart` |
| **AC7** Legales (`aviso-privacidad`/`terminos` + HTML) sin promesa de obfuscación; bitácora enmendada | `docs/legal/*` + `infra/compose/legal/*` + `bitacora` (gate #5, Q5.B-D1) | revisión |
| **AC8** Suites verdes; números reales reportados por el orquestador | — | corridas de suites |

**Gate #5:** su parte pública se **retira** (público exacto). La celda de 300 m persiste **solo** como
binning del mapa de calor. Enmienda registrada en `bitacora_sdd_mezquite.md` (gate #5, Q5.B-D1 y la
salvaguarda EXIF de CR-001). Decisiones del usuario en `docs/change-requests/CR-025-ubicacion-exacta-publica.md`.

## Apertura del repositorio — repo público, licencia de datos CC BY 4.0

Directo sobre `main` (docs + metadatos + 2 constantes de copy). **No cambia el producto**: ninguna
regla de negocio, endpoint, modelo ni gate. Autorizada por el usuario y por el titular del copyright
(Club Rotario Bosques Aguascalientes). **350 pruebas verdes** (`contract` 21 · `mock` 9 ·
`backend` 155 · `mobile` 69 · `web-admin` 96).

| Criterio | Implementación | Prueba |
|---|---|---|
| Correo de contacto institucional en vez del personal, en licencia, docs y ambas apps | `LICENSE`, `README.md`, `TRACEABILITY.md`, `CR-013`, `mobile/lib/src/ui/copy.dart`, `web-admin/lib/src/ui/copy.dart` | `mobile/test/about_test.dart` · `web-admin/test/widget_about_test.dart` (asertan el correo nuevo) |
| Runbooks con valores reales del host (IP, rutas, panel del registrador) fuera del repo | eliminados de `docs/despliegue/` y del historial; se conservan fuera del árbol del repositorio. La versión reproducible y sin datos del host permanece en `DESPLIEGUE-HETZNER.md`/`DESPLIEGUE-SERVIDOR-UNICO.md` | `git grep` sin coincidencias de la IP ni de los archivos |
| Placeholders de dev no confundibles con secretos reales | `infra/k8s/base/secret.yaml` → `secret.example.yaml` (+ referencias en `kustomization.yaml`, `config.yaml`, `infra/k8s/README.md`) | `kubectl kustomize infra/k8s/base` construye |
| **Licencia de datos CC BY 4.0** con cita, esquema publicado y advertencia de origen ciudadano | `LICENSE-DATOS.md`; alcance = dataset de `/public/*`; excluye fotografías, identidad gráfica y código | revisión |
| Atribución al observador en el dato abierto | `handle` por observación ya viaja en `PublicObservation` (atribución I2); documentado en `LICENSE-DATOS.md` | `backend/tests/test_roles.py` (forma de la respuesta pública) |
| Canal de reporte de vulnerabilidades (servicio en producción) | `SECURITY.md`: correo, alcance, plazos, y qué **no** es vulnerabilidad (ubicación pública por CR-025; placeholders de dev) | revisión |
| Expectativas de contribución explícitas | `CONTRIBUTING.md`: sin PRs no solicitados; issues y uso del dataset bienvenidos; gates innegociables listados | revisión |
| Atribución de terceros | README: **OpenStreetMap** © colaboradores, **ODbL**, con la advertencia de proveedor de *tiles* para tráfico real | revisión |

**Gates:** ninguno se enmienda. #1 se refuerza (`LICENSE-DATOS.md` declara que especie y nivel **no**
son diagnóstico fitosanitario). #2 mejora: sale un correo personal de ambas apps y entra uno
institucional. #5 (parte pública, ya retirada por CR-025) se documenta como decisión de gobernanza,
sin motivaciones externas, en `LICENSE-DATOS.md` y `SECURITY.md`. #7 es esta entrada.

**CC BY 4.0 en los Términos — RESUELTO (2026-07-24):** el Club **aprobó** la licencia, así que el §7
("Datos abiertos y atribución") de `docs/legal/terminos.md` y su página pública
`infra/compose/legal/terminos.html` ya **nombran CC BY 4.0**, con la obligación de atribuir al Club y a
las personas observadoras (por seudónimo) y la exclusión explícita de las **fotografías**. md y html
sincronizados. **Pendiente menor (no bloquea):** los resúmenes legales *dentro de las apps*
(`mobile/lib/src/ui/copy.dart`, `web-admin/.../legal_screen.dart`) siguen diciendo "dato abierto" sin
nombrar la licencia — no contradicen los Términos; se alinean en el próximo build, porque cambiarlos
obliga a recompilar y redesplegar.

**Nombre del Club — corregido (2026-07-24):** `documento_presentacion_mezquite.md` decía "Club Rotario ·
Aguascalientes" y `protocolo_ciencia_ciudadana_mezquite.md` "Club Rotario + universidades aliadas"; ambos
usan ya el nombre completo **Club Rotario Bosques Aguascalientes**. El resto de apariciones "cortas" del
repo eran saltos de línea de markdown, no errores.

---

## CR-026 — Participación válida, sin horas, y mapas solo de observaciones confirmadas (2026-07-25)

**Origen:** solicitud de las **universidades participantes**. Detalle:
[`CR-026`](../change-requests/CR-026-participacion-valida-y-mapas-confirmados.md).

| Criterio | Implementación | Prueba |
|---|---|---|
| **AC1** La app del voluntario ya NO muestra "Horas de participación" | `mobile/lib/src/ui/screens/evidence_screen.dart` (se retira el `StatTile`), `copy.dart` | `mobile/test/cr010_movil_test.dart` (`find.text('3.5')` → `findsNothing` aunque el API la envíe) |
| **AC2** Las horas se siguen capturando y almacenando (dato, no UI) | `SessionTracker` y `POST /me/sessions` intactos; `horas_totales`/`sesiones` siguen en `EvidenceResponse` | `backend/tests/test_cr010_sessions_evidence.py` (horas y sesiones siguen agregándose) |
| **AC3** "Observaciones válidas registradas" = solo `confirmada` | `gamification.account_confirmed_count`; `routers/me.py::evidence` | `test_cr010_sessions_evidence.py::test_evidence_aggregates_captures_and_hours` (2 subidas, 1 confirmada ⇒ `capturas=1`, `capturas_totales=2`) |
| **AC4** El total crudo no se pierde | `capturas_totales` en `/me/evidence`; `account_observation_count` sin filtrar | misma prueba que AC3 |
| **AC5** La brecha se explica como revisión pendiente, nunca como rechazo (Q5.A-D1) | `Copy.evidenceCapturasNota` / `evidencePendientes`; mensaje de `/me/feedback` | `mobile/test/cr010_movil_test.dart` (claves `evidence_capturas_nota`, `evidence_pendientes`) · `test_rankings_profile.py::test_feedback_is_aggregate_not_individual` (el mensaje no dice "rechaz") |
| **AC6** Conteo, lifelist e insignias cuentan solo confirmadas | `account_lifelist`, `compute_badges`, `routers/me.py::profile` | `test_rankings_profile.py::test_profile_counts_only_confirmed` |
| **AC7** Los puntos solo cuentan confirmadas, en ambos sentidos | `account_points` con `JOIN observation ... = 'confirmada'` (filtro al leer; el ledger no se toca) | `test_rankings_profile.py::test_points_follow_the_verdict_both_ways` (confirmar suma, rechazar descuenta) |
| **AC8** La etiqueta L3 se recomputa al emitir veredicto | `routers/review.py::review_verdict` → `refresh_identity_label` | `test_rankings_profile.py::test_points_follow_the_verdict_both_ways` (perfil tras el veredicto) |
| **AC9 (gate #9 ENMENDADO)** El público solo ve `confirmada` | `routers/public.py` (`/observations` y `/grid`) | `test_public_grid.py::test_grid_excludes_observations_pending_review` · `test_review.py::test_ac1_new_observation_is_aceptada_but_not_public` |
| **AC10** Revertir a `aceptada` despublica | sin cambio de código (consecuencia de AC9) | `test_cr010_verdict_aceptada.py::test_aceptada_reverts_rejected_observation` |
| **AC11 (G2)** Los indicadores públicos describen el mismo universo que el mapa | `indicators.py` (`obs_filter` con `= 'confirmada'`; `arboles_unicos` por observación confirmada) | `test_indicators.py::test_indicators_describe_only_confirmed` |
| **AC12** El denominador crudo sigue visible | `observaciones_capturadas` + `proporcion_confirmada` (sobre TODAS) | misma prueba que AC11 |
| **AC13** El `CAVEAT` ya no afirma que lo publicado carece de revisión | `indicators.CAVEAT` | `test_indicators.py::test_indicators_describe_only_confirmed` (`"confirmadas" in caveat`) |
| **AC14 (G1)** El mapa de la consola arranca en confirmadas pero alcanza todos los estados | `routers/restricted.py` (`estado_revision` opcional); `web-admin/.../map_screen.dart` (`_ReviewFilter`) | `web-admin/test/widget_cr026_consola_test.dart` (default `confirmada`; "Pendientes" → `aceptada`; "Todas" → sin filtro) |
| **AC15 (F)** Reporte de participación por día × voluntario | `routers/analytics.py::participation_csv` | `backend/tests/test_cr026_participacion_csv.py::test_participation_crosses_sessions_with_review_outcome` |
| **AC16 (F)** El día se agrupa en `America/Mexico_City` | `Settings.report_timezone` + `AT TIME ZONE :tz` | `test_cr026_participacion_csv.py::test_day_is_grouped_in_mexico_city_not_utc` (02:00Z ⇒ día anterior) |
| **AC17 (F)** No se pierden días de solo-sesión ni de solo-captura | `FULL OUTER JOIN` entre las dos CTEs | `test_cr026_participacion_csv.py::test_session_without_captures_still_appears` |
| **AC18 (F)** Authz del reporte + gate #2 | `Depends(_analyst)` (`REVIEW_ROLES`) | `test_cr026_participacion_csv.py::test_participation_authz` · `::test_participation_has_no_pii` |
| **AC19 (F)** La consola descarga el reporte y advierte qué miden las horas | `data_screen.dart` + `Copy.dataParticipationNote`; `api_client.participationCsvBytes` | `web-admin/test/widget_cr026_consola_test.dart` (grupo "CR-026 F") |
| **AC20** Corrección incidental: `sum(points)` de rankings ya no se infla | `gamification.rankings` reescrito con subconsultas por cuenta | `test_rankings_profile.py::test_rankings_individual_and_by_institution` |

**Gates:** **#9 ENMENDADO** (público = `confirmada`, antes `<> 'rechazada'`); anotado en la bitácora
con fecha y motivo. **#3 intacto**: la observación sigue naciendo `aceptada` y nada se bloquea por
nivel. **#1**, **#2**, **#4**, **#5**, **#6**, **#8** sin cambio. **#7** es esta entrada.

**Dependencia operativa nueva:** la participación visible del voluntario y el mapa público quedan
supeditados al **ritmo de revisión de la consola**. Si nadie revisa, el piloto se ve vacío hacia fuera.

**Pendiente de aprobación humana:** el texto del `CAVEAT` público (§6 del CR) es texto de cara al
público; queda redactado y desplegado, sujeto a tu visto bueno.

---

## CR-027 — Endurecimiento de la superficie expuesta del backend (2026-07-25)

**Origen:** auditoría de autenticación endpoint por endpoint. Detalle:
[`CR-027`](../change-requests/CR-027-endurecimiento-superficie-expuesta.md).

| Criterio | Implementación | Prueba |
|---|---|---|
| **AC1** Fuera de dev, la API no arranca con el `AUTH_SECRET` por defecto | `config.Settings.validate_for_environment()`, invocada en `create_app()` | `backend/tests/test_cr027_endurecimiento.py::test_prod_refuses_to_start_with_default_secret` |
| **AC2** Con un secreto real, prod arranca normal | mismo | `::test_prod_starts_with_a_real_secret` |
| **AC3** Dev conserva el default (paridad de entornos, gate #6) | `Settings.is_dev` | `::test_dev_still_allows_the_default_secret` |
| **AC4** `/files/{key}` (imágenes sin token) no se monta fuera de dev | `main.py` (`storage_backend == 'local' and is_dev`) | `::test_files_route_is_not_mounted_outside_dev` |
| **AC5** En dev se conserva (el runbook local sirve las fotos sin S3) | mismo | `::test_files_route_stays_available_in_dev` |
| **AC6** Caddy ya no publica `/files/*` en ninguno de los dos dominios | `infra/compose/Caddyfile` | `::test_caddyfile_does_not_proxy_files` (y verifica que `/api/*` sigue proxyado) |
| **AC7** El TTL del token baja de 30 a 7 días | `Settings.auth_token_ttl_seconds` | `::test_token_ttl_is_at_most_seven_days` |

**Gates:** ninguno se enmienda; refuerza el **#2** (las fotos dejan de ser alcanzables sin sesión) y el
modelo de roles. **#6 intacto:** dev sigue corriendo sin nube y con el default.

**Deuda anotada (no incluida en este CR):** (a) no hay **revocación de tokens** — cerrar sesión no
invalida nada del lado del servidor; (b) la **cancelación ARCO no borra las fotografías**, solo
anonimiza la observación.

---

## CR-028 — Una institución por nombre (antiduplicados) (2026-07-28)

**Origen:** hallazgo en producción — dos "Global University" (una con estado, otra sin él) creadas
por dos caminos distintos de la misma app, porque **ninguna capa comprobaba si el nombre ya
existía**. Detalle: [`CR-028`](../change-requests/CR-028-instituciones-sin-duplicados.md).

Regla única de "el mismo nombre" (sin acentos, minúsculas, espacios colapsados) en
`backend/app/institution_names.py`, compartida por el índice SQL, el backend y la app.

| Criterio | Implementación | Prueba |
|---|---|---|
| **AC1** Dos altas del mismo nombre ⇒ una sola institución (el caso de producción) | `routers/institutions.py` (reusa la existente) | `backend/tests/test_cr028_instituciones_sin_duplicados.py::test_solicitar_dos_veces_el_mismo_nombre_no_duplica` |
| **AC2** Acentos, mayúsculas y espacios no crean instituciones distintas | `institution_names.normalize_institution_name` | `::test_variantes_de_acentos_mayusculas_y_espacios_son_la_misma` |
| **AC3** Reusar afilia la cuenta a la institución que sobrevive | `routers/institutions.py` | `::test_la_segunda_cuenta_queda_afiliada_a_la_institucion_existente` |
| **AC4** Reusar no aprueba por la puerta de atrás (una `solicitada` sigue `solicitada`) | mismo | `::test_reusar_no_cambia_el_estado_de_la_existente` |
| **AC5** El alta duplicada desde la consola responde 409 nombrando la existente | `routers/admin.py::_ya_existe` | `::test_alta_desde_la_consola_duplicada_es_409` |
| **AC6** La consola no puede duplicar una `solicitada` por un voluntario | mismo | `::test_la_consola_no_puede_duplicar_una_solicitada_por_el_voluntario` |
| **AC7** Ni un `INSERT` directo puede duplicar (última línea de defensa) | índice `ux_institution_nombre_norm` (migración `0007`, y `models.py` para `create_all`) | `::test_el_indice_unico_impide_el_duplicado_incluso_por_sql_directo` |
| **AC8** Un nombre vacío o de puros espacios se rechaza | `schemas._nombre_institucion_limpio` | `::test_nombre_vacio_o_solo_espacios_se_rechaza` |
| **AC9** El nombre se guarda con espacios normalizados (conservando acentos y mayúsculas) | mismo | `::test_el_nombre_se_guarda_con_espacios_normalizados` |
| **AC10** Un `estado` en blanco se guarda como `NULL`, no como un estado distinto | `schemas._estado_institucion_opcional` | `::test_estado_en_blanco_se_guarda_como_nulo` |
| **AC11** La siembra reconoce variantes previas, no duplica y ya no revienta | `seed_institutions.py` (por nombre canónico, ya no `one_or_none`) | `::test_la_siembra_reconoce_variantes_previas_y_no_duplica` |
| **AC12** La app aplica la MISMA regla que el backend | `Institution.normalizeName` | `mobile/test/cr028_instituciones_sin_duplicados_test.dart` (grupo "regla del nombre canónico") |
| **AC13** En el login, escribir una institución que ya está la **selecciona** en vez de encolar una gemela | `welcome_screen._buscarEnCatalogo` | `::la selecciona en vez de encolar una gemela, y lo dice` |
| **AC14** Una institución realmente nueva sigue quedando pendiente de registro | mismo | `::una institución realmente nueva sí queda pendiente de registro` |
| **AC15** Elegir una existente no dispara ningún POST de alta | mismo | `::elegir una existente no dispara ningún POST de alta` |
| **AC16** La consola explica el 409 en vez de invitar a reintentar | `institutions_screen._submit` | `web-admin/test/widget_cr028_test.dart::un nombre duplicado (409) se explica` |
| **AC17** El alta normal de la consola no cambia | mismo | `::un alta normal sigue confirmando como antes` |

**Gates:** ninguno se enmienda. **#3 (sin gating) preservado a propósito:** al voluntario nunca se le
rechaza — si escribe un nombre existente queda afiliado a esa institución. Por eso el reuso (200) y
no un 409 en `/institutions/request`: el catálogo público solo lista las aprobadas, así que una
institución en revisión no se puede "elegir" de ninguna lista.

**Migración `0007`:** crea el índice único y **se detiene enumerando los duplicados** si la base aún
tiene alguno. Es deliberado: fusionar exige decidir cuál sobrevive y repuntar `account.institution_id`
(única FK que apunta a `institution`), y eso no lo debe adivinar una migración.

**Deuda anotada (no incluida):** la consola sigue sin **fusionar/renombrar/eliminar** instituciones —
`/admin/institutions` solo tiene `GET`, `POST` y `approve`—, así que un duplicado por dos nombres
realmente distintos de la misma escuela sigue exigiendo entrar a la base.

---

## CR-029 — Correcciones de la consola: contador del Monitor, edición de instituciones y zoom (2026-07-28)

**Origen:** tres hallazgos del usuario usando la consola. Detalle:
[`CR-029`](../change-requests/CR-029-consola-correcciones.md).

**El bug del contador, en corto:** el Monitor mostraba 58 observaciones y 61 "Revisiones
registradas". El contador era honesto (cuenta EVENTOS del log append-only `human_review`), pero 3 de
esos eventos eran **el mismo veredicto grabado otra vez** sobre dos observaciones
(`confirmada → confirmada → confirmada` y `confirmada → confirmada`): nada impedía volver a confirmar
algo ya confirmado. Se corrigen las dos cosas — la escritura redundante y la pantalla que invitaba a
comparar dos números que no miden lo mismo.

| Criterio | Implementación | Prueba |
|---|---|---|
| **AC1** Repetir el veredicto vigente NO escribe en el log (el caso de producción) | `routers/review.py` (no-op + `sin_cambio`) | `backend/tests/test_cr029_consola_correcciones.py::test_repetir_el_mismo_veredicto_no_escribe_en_el_log` |
| **AC2** Un cambio real de veredicto sí se registra (la idempotencia no se traga una re-revisión) | mismo | `::test_un_cambio_real_de_veredicto_si_se_registra` |
| **AC3** El no-op no altera estado ni historial | mismo | `::test_el_no_op_no_altera_el_estado_ni_el_historial` |
| **AC4** También aplica a `aceptada` sobre una recién subida | mismo | `::test_repetir_aceptada_sobre_una_recien_subida_tampoco_escribe` |
| **AC5** `/review/stats` distingue observaciones revisadas (distintas) de veredictos emitidos | `routers/review.py::review_stats` + `schemas.ReviewStats` | `::test_stats_distingue_observaciones_revisadas_de_veredictos_emitidos` |
| **AC6** Sin revisiones, ambos contadores son 0 | mismo | `::test_sin_revisiones_ambos_contadores_son_cero` |
| **AC7** El Monitor pinta el escenario reportado sin parecer contradictorio | `monitor_screen.dart` | `web-admin/test/widget_cr029_test.dart::pinta el escenario reportado (58 observaciones, 61 veredictos)` |
| **AC8** El botón del veredicto vigente va deshabilitado (confirmada/aceptada/rechazada) | `review_screen.dart` | `::una observación CONFIRMADA no deja volver a confirmarla` (+ ACEPTADA, + RECHAZADA) |
| **AC9** Editar nombre y estado de una institución | `routers/admin.py::update_institution` (`PATCH`) | `::test_editar_nombre_y_estado` |
| **AC10** La edición NO cambia el `status` (decisión del usuario) | mismo (`InstitutionUpdateIn` no lo expone) | `::test_editar_no_cambia_el_status` + `widget_cr029_test.dart` (el body no lleva `status`) |
| **AC11** Renombrar al nombre de OTRA institución responde 409 (índice único de CR-028) | mismo | `::test_renombrar_a_un_nombre_de_otra_es_409` |
| **AC12** Corregir la escritura de la PROPIA institución sí se permite (el choque excluye su fila) | mismo | `::test_corregir_la_escritura_de_la_propia_institucion_si_se_permite` |
| **AC13** Editar solo el estado conserva el nombre; `estado` en blanco lo limpia | mismo (`model_fields_set`) | `::test_editar_solo_el_estado_conserva_el_nombre` · `::test_estado_vacio_lo_limpia` |
| **AC14** Nombre vacío 422 · institución inexistente 404 · rol insuficiente 403 | mismo | `::test_editar_con_nombre_vacio_es_422` · `::test_editar_una_inexistente_es_404` · `::test_editar_exige_rol_de_admin` |
| **AC15** La consola edita desde un diálogo precargado y guarda por `PATCH` | `institutions_screen.dart` (`_EditInstitutionDialog`) | `widget_cr029_test.dart::el diálogo llega precargado y guarda por PATCH` |
| **AC16** El 409 se explica sin cerrar el diálogo | mismo | `::un nombre ya usado (409) se explica sin cerrar el diálogo` |
| **AC17** Clic en la foto abre el visor; +/−/restablecer y cierre funcionan | `review_screen.dart::_ImageZoomDialog` | `::clic en la foto abre el visor con controles de zoom` |

**Gates:** ninguno se enmienda. **#7 reforzado:** el log de revisión deja de acumular entradas que no
corresponden a un cambio real de estado — sigue siendo append-only, solo se dejan de escribir
redundancias. **#2 intacto.**

**Zoom sin backend:** los bytes en resolución completa ya viajaban al navegador (`reviewImageBytes`,
con el header de autorización), así que ampliar no genera peticiones nuevas ni toca el RBAC del
endpoint de imagen. El área clicable se fijó a alto 280 / ancho completo para que no dependa de que
la imagen esté decodificada.

**Limpieza del dato existente (autorizada por el usuario):** se borran las 3 filas redundantes de
`human_review` en producción, conservando **la primera de cada observación** (la que sí produjo el
cambio de estado). No son "huérfanas" — huérfanas había 0.
