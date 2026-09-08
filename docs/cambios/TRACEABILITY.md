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
| **Q8** Toda observación atribuible a estado y municipio **por geolocalización** | backend | 2–CR-036 | `geo.resolver_ubicacion` (join `admin_boundary`, límites INEGI nacionales cargados); el servidor deriva SIEMPRE, el cliente ya no declara: `backend/tests/test_cr036_geografia_derivada.py` | ✅ (CR-036 cierra la carga de límites, pendiente desde el Inc. 2) |
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

---

## CR-030 — Números reales para el voluntario (2026-07-29)

**Origen:** voluntarios reportan que la app "solo deja registrar 20 mezquites".

**Hallazgo (verificado contra la base de producción, fotografía del 2026-07-29 ~15:20 h):** el
registro **no tiene tope**. Había cuentas
con **22, 27, 29, 31 y 37** observaciones —una de ellas 37 en 47 minutos—, **0** filas sin imagen, 167
claves de imagen distintas para 167 filas, y un retraso entre captura y `created_at` de **19–23 s de
promedio (109 s el máximo)**: las subidas entraban en tiempo real. El 20 estaba **en el texto**:
`feedback_window = 20` era el `LIMIT` de `GET /me/feedback`, así que la frase "de tus últimas 20
observaciones" **se congelaba en 20** para quien pasara de 20 y mostraba el total real por debajo de
ese umbral — razón por la que el hallazgo era invisible desde una cuenta con 13 capturas.

| # | Criterio de aceptación | Implementación | Prueba |
|---|---|---|---|
| **AC1** El resumen considera TODAS las observaciones, no 20 | `routers/me.py::feedback` (sin `LIMIT`) + `gamification.account_review_counts` | `backend/tests/test_cr030_numeros_reales.py::test_feedback_sin_ventana_de_20` (22 subidas ⇒ 22) |
| **AC2** El mensaje nombra el total real y el 20 no reaparece | mismo | `::test_feedback_mensaje_usa_total_real` (afirma que "20" y "últimas" NO están) |
| **AC3** El resumen sigue siendo agregado y no delata rechazos | mismo | `test_rankings_profile.py::test_feedback_is_aggregate_not_individual` · `::test_en_revision_excluye_rechazadas` |
| **AC4** `/me/profile` expone `total_uploaded` sin alterar `total_observations` (CR-026) | `routers/me.py::profile` + `schemas.ProfileResponse` | `::test_profile_expone_subidas_sin_tocar_confirmadas` (3 subidas / 1 confirmada) |
| **AC5** `en_revision` excluye rechazadas en profile y evidence | `account_review_counts` (`count(*) FILTER` por estado) | `::test_en_revision_excluye_rechazadas` |
| **AC6** El texto concuerda en número (no dice "1 observaciones") | `routers/me.py::feedback` | `::test_feedback_concordancia_en_singular` |
| **AC7** `feedback_window` desapareció de la configuración | `config.py` | `::test_config_ya_no_expone_feedback_window` |
| **AC8** Perfil pinta subidas y confirmadas con etiquetas distintas | `profile_screen.dart` (`activity_subidas` / `activity_confirmadas`) | `mobile/test/cr030_numeros_reales_test.dart::con 31 subidas y 3 confirmadas pinta AMBOS números` |
| **AC9** La brecha se explica como cola de revisión; sin cola, no hay nota | `profile_screen.dart` (`activity_en_revision`) | mismo · `::con todo revisado no aparece la nota de brecha` (caso real de 37/37) |
| **AC10** Mi participación abre con el total subido y no cuenta rechazadas como pendientes | `evidence_screen.dart` (`evidence_subidas`) + `models.dart::Evidence.pendientes` | `::una rechazada NO se cuenta como "sigue en revisión"` (13/12/1) |
| **AC11** Los modelos toleran un backend anterior a CR-030 | `models.dart` (campos con default y respaldo) | `::AC-8 — los modelos toleran un backend anterior a CR-030` (4 casos) |
| **AC12** Ningún texto del voluntario fija un tope ni habla de "las últimas N" | `copy.dart` | `::ningún texto del voluntario promete un tope de 20` |

**Gates:** ninguno se enmienda. **#9 / CR-026 intacto:** conteos "válidos", insignias, etiqueta L3,
puntos, mapas e indicadores públicos siguen contando **solo `confirmada`**; este CR **añade** el dato
crudo al lado, no redefine qué es válida. **Q5.A-D1 intacto:** el resumen sigue siendo agregado.
**Sin migración** (no se toca ninguna tabla).

**Decisión del usuario (2026-07-29):** las **rechazadas NO se le muestran** al voluntario. El mensaje
nombra confirmadas y en revisión, y el total subido se presenta como cifra aparte. Consecuencia
asumida: para quien tenga rechazos, confirmadas + en revisión **no suman** el total subido, y esa
diferencia no se explica en pantalla.

**Compatibilidad:** `window` se conserva en la respuesta (deprecado, ahora igual al total) para que
una PWA con bundle viejo en caché no reviente al parsearlo como `int` obligatorio. Como el `message`
lo arma el **servidor**, esos clientes ven el texto corregido **en cuanto se despliega el backend**.

**Nota sobre AC4 de CR-026:** el `account_observation_count` que citaba ese renglón fue reemplazado
por `account_review_counts` (una consulta agregada con los cuatro estados); el criterio no cambia.

**Deuda anotada (NO entra en este CR):** el envío es *fire-and-forget* y **falla en silencio** —
`capture_screen.dart` muestra "registrada y aceptada" **antes** de que el POST responda,
`.catchError((_) {})` se traga el error, la `PendingQueue` es solo en memoria y **ningún widget la
pinta**, no hay reintento, y el **401** de un token vencido (TTL 7 días, CR-027) no se maneja. **No
hay almacenamiento sin conexión:** una captura tomada sin red se pierde y el usuario ve un mensaje de
éxito. Los datos de producción no muestran un corte sistemático, pero por diseño ese fallo no deja
rastro en la base. Amerita su propio CR. → **Es CR-031.**

---

## CR-031 — Captura sin conexión y subida diferida (2026-07-29)

Los **21 criterios de aceptación** y las 9 decisiones humanas resueltas están en
[`CR-031-captura-sin-conexion.md`](../change-requests/CR-031-captura-sin-conexion.md) (§8, §10, §12).
Aquí queda el mapa de dónde vive cada cosa y qué la prueba.

| Paquete | Implementación | Pruebas |
|---|---|---|
| **W1** submit idempotente + 410 | migración `0008` · `models.Observation.client_capture_id` (+ índice parcial único, declarado también en el modelo) · `routers/observations.py` (200 + `ya_existia`) · `deps.py` (410 Gone) · `web-admin/.../api_exception.dart` (`isAuthError` suma 410) | `backend/tests/test_cr031_idempotencia.py` (7) · `web-admin/test/cr031_410_test.dart` (3) |
| **W2** almacén persistente | `pending_capture.dart` · `pending_store.dart` · `pending_backend_io.dart` (nativo) · `pending_backend_web.dart` (IndexedDB, PRODUCCIÓN) · `pending_backend.dart` (import condicional) | `mobile/test/cr031_pending_store_test.dart` (21) |
| **W3** motor de subida | `pending_uploader.dart` · `api_client.submitObservation` → `SubmitResult` | `mobile/test/cr031_uploader_test.dart` (16), incluye **AC14** (respuesta perdida ⇒ no duplica) |
| **W4** interfaz honesta + disparadores | `capture_screen.dart` · `pending_uploads_card.dart` · `account_screen.dart` (D3) · `problem_report_screen.dart` (AC21) · `home_shell.dart` (ciclo de vida) · `network_signal*.dart` (evento `online`) · `providers.dart` (`PendingQueueController`) · `AuthSession.accountId` desde el `sub` del JWT | `mobile/test/cr031_ui_test.dart` (15) |

**Gates:** ninguno se enmienda. **#4 intacto** (la cola solo contiene lo que produjo la cámara; el
`captured_at` no se reescribe al subir tarde). **#9 / Q5.A-D1 intacto** y reforzado en el texto: los
mensajes de la cola hablan de **transporte** ("en tu teléfono", "por subir"), nunca de veredicto.
**#3 intacto:** ningún aviso de acumulación impide capturar. **#2 intacto:** el diagnóstico de la cola
viaja sin PII (probado).

**Sin cobertura automática, dicho explícitamente:** el backend de **IndexedDB** —que es el de
producción— no se puede ejercitar en `flutter test`, que corre sobre la VM de Dart y no en un
navegador. Por eso su costura se redujo a cuatro primitivas sin decisiones y toda la lógica se prueba
contra un backend en memoria. Se verifica además con `flutter build web`, que sí compila esa rama.
**AC15 (que la PWA abra sin conexión) requiere un teléfono real en modo avión.**

---

## CR-032 — Aprender como pestaña inicial + ilustraciones de los módulos (2026-07-30)

**Origen:** petición del usuario. (1) La app abría en la cámara y debe abrir en **Aprender**. (2) Los
módulos de reconocimiento no tenían imágenes; el usuario aportó tres de Wikimedia Commons.

**Hallazgo al analizar el CSV aportado:** las tres URLs eran **páginas de descripción** de Commons
(`content-type: text/html`), no imágenes — puestas tal cual habrían mostrado un hueco roto. La ruta
que sí sirve los bytes es `Special:FilePath/<archivo>?width=N` (y no la de `upload.wikimedia.org` con
hash, que puede cambiar). **Decisión del usuario:** empaquetarlas, no enlazarlas — así "Aprender"
sigue funcionando sin conexión, que es donde de verdad hace falta reconocer paxtle o cúscuta.

| # | Criterio | Implementación | Prueba |
|---|---|---|---|
| **AC1** La app abre en Aprender | `home_shell.dart` (`_index = _tabAprender`) | `cr032_aprender_imagenes_test.dart::la pestaña inicial es Aprender, no la cámara` |
| **AC2** Los 4 destinos siguen disponibles (gate #3) | mismo | `::capturar sigue estando a un toque` |
| **AC3** Cada módulo referencia su imagen con ruta **relativa** | `docs/learning/mod_{que_es,paxtle,cuscuta}.md` | `::cada módulo referencia su imagen con ruta relativa` |
| **AC4** **Ninguna** imagen por red en los contenidos | mismos | `::ningún módulo carga imágenes por red` |
| **AC5** Los JPEG existen en fuente y bundle, idénticos y válidos | `docs/learning/img/` → `mobile/assets/learning/img/` | `::los archivos existen en la fuente y en el bundle, idénticos` (comprueba los *magic bytes*, porque las URLs del CSV devolvían HTML) |
| **AC6** `pubspec` declara `assets/learning/img/` | `mobile/pubspec.yaml` | `::pubspec declara assets/learning/img/ explícitamente` |
| **AC7** Atribución CC BY-SA visible: autor + licencia + enlace | pie de foto en los dos módulos | `::las dos CC BY-SA nombran autor, licencia y enlace` |
| **AC8** La de dominio público también acredita | `mod_que_es.md` | `::la de dominio público también acredita al autor` |
| **AC9** Registro de procedencia | `docs/learning/CREDITOS-IMAGENES.md` | `::existe el registro de procedencia` |
| **AC10** El detalle pinta la imagen desde assets, no el texto de reemplazo | `learning_detail_screen.dart::_buildImage` | `::mod_cuscuta muestra la imagen y no el texto de reemplazo` |

**Licencias.** Empaquetar es **redistribuir**, así que la atribución es condición de la licencia:
cúscuta (ShahadatHossain) y paxtle (Juan Carlos Fonseca Mata) son **CC BY-SA 4.0** y llevan autor,
licencia y enlace al pie de su imagen; mezquite (Renebeto) es **dominio público** y se acredita igual.
Incluirlas **sin modificarlas** es agregación, no obra derivada: **no cambia la licencia MIT del
software** ni la CC BY 4.0 de los datos. ⚠️ Recortar o retocar alguna sí crearía obra derivada y
obligaría a publicarla como BY-SA — anotado en el archivo de créditos.

**Peso:** +**717 KB** al bundle del voluntario (960×540, 960×600 y 960×1280; medido con Pillow, no
estimado). Se pidió `width=800` y Commons sirvió 960: mejor resolución al mismo peso.

**Nota de plataforma:** declarar `assets/learning/` en `pubspec.yaml` **no** incluye subcarpetas en
Flutter; `assets/learning/img/` va en su propia línea. Verificado en el bundle compilado
(`build/web/assets/AssetManifest.json`), no solo en las pruebas.

**Gates:** ninguno se enmienda. El banner de **BORRADOR** de los contenidos (pendiente de validación
AU2/H4) sigue igual: añadir ilustraciones no los valida.

---

## CR-033 — La cola de Revisión completa y sin perder la página (2026-07-31)

**Origen:** dos bugs reportados por el usuario usando la consola. (1) La cola de Revisión mostraba
como máximo 200 registros aunque la base tuviera más. (2) Al entrar al detalle de una observación y
volver, la lista regresaba a la página 1 con 10 filas por página, perdiendo dónde estaba el revisor.

**Diagnóstico.** (1) El tope era del **cliente**: `review_screen.dart` pedía `reviewQueue(limit: 200)`
— una sola página — y el backend (`/review/queue`, `le=1000` + `offset`) tenía el resto disponible
pero nadie lo pedía. (2) El estado de paginación (`_page`/`_perPage`) vivía **dentro** del
`PagedTable`; al volver del detalle la pantalla recarga la cola, el `FutureBuilder` pasa por el
spinner y **saca la tabla del árbol**, destruyendo su estado — renacía con los defaults.

| # | Criterio | Implementación | Prueba |
|---|---|---|---|
| **AC1** La consola trae TODA la cola, paginando contra el backend hasta la página corta | `api_client.dart::reviewQueueAll` (páginas de 1000 con `offset`) | `review_api_test.dart::reviewQueueAll recorre offsets hasta la página corta (CR-033)` (1150 filas → 2 peticiones, filtro en ambas) |
| **AC2** Con >200 registros la tabla muestra el total real | `review_screen.dart::_reload` usa `reviewQueueAll` | `widget_cr033_test.dart::la cola muestra MÁS de 200 registros` (331 filas → "1–10 de 331") |
| **AC3** Volver del detalle conserva página y filas/página | estado de paginación en `_ReviewScreenState` + `PagedTable` controlado (`page`/`perPage` + callbacks, CR-033) | `::volver del detalle conserva la página y las filas por página` (25/pág + pág 2 → abrir detalle → cerrar → sigue en "26–30 de 30" y 25/pág) |
| **AC4** Cambiar el filtro de estado SÍ vuelve a la página 1 (intencional) | chips de filtro reinician `_page = 0` | `::cambiar el filtro SÍ regresa a la página 1 (intencional)` |
| **AC5** Las otras tablas (modo no controlado) no cambian de comportamiento | `PagedTable` con `page`/`perPage` **opcionales** (null = estado propio, como siempre) | `widget_cr012_test.dart` intacto (paginación default) |

**Decisiones.** Traer toda la cola y seguir paginando en **cliente** (no paginación de servidor en la
tabla): es la opción más simple, el backend ya soportaba `offset`, y a la escala del piloto (cientos
de filas) el costo es de una petición extra por millar. Si la cola creciera a decenas de miles, ahí
sí tocaría paginar contra el servidor. Si la lista encoge (un veredicto saca la fila del filtro
activo), la tabla se acota sola a la última página existente (clamp que ya existía).

**Gates:** ninguno se toca. Solo consola (web-admin); sin backend, sin migración.

---

## CR-034 — Listas completas en toda la consola + claridad del panel público + pastel de paxtle (2026-07-31)

**Origen:** tres peticiones del usuario. (1) El tope silencioso de CR-033 existía en las DEMÁS
listas; (2) el panel público mostraba datos ilegibles "entre llaves"; (3) falta un gráfico de pastel
del nivel de paxtle.

**Diagnóstico.** (1) Cada pantalla pedía UNA página con `limit` fijo (público 200, restringido 500,
Datos 1000, mapa exacto 2000) y **ninguno de los tres endpoints aceptaba `offset`** — el resto del
dataset era inalcanzable por diseño. (2) Los indicadores anidados (`distribucion_niveles`,
`distribucion_identidad_e3`) son mapas JSON y `_Metric` los pintaba con `toString()` →
`"{leve: 3, moderado: 1}"`; además `proporcion_confirmada` salía como fracción (`0.5`) y a
`observaciones_capturadas` le faltaba etiqueta.

| # | Criterio | Implementación | Prueba |
|---|---|---|---|
| **AC1** Los 3 endpoints de listas aceptan `offset` (ge=0, 422 si negativo) | `public.py`/`restricted.py`/`analytics.py` + `OFFSET` en SQL (ya tenían `ORDER BY captured_at DESC`) | `test_cr034_offset_listas.py` (4 casos: páginas disjuntas, unión = dataset, orden estable, 422) |
| **AC2** El cliente recorre TODO con lazo de offset | `ApiClient._fetchAll` + `publicObservationsAll` (5000/pág) · `restrictedObservationsAll` (20000/pág) · `analyticsObservationsAll` (5000/pág) | `cr034_test.dart::Listas completas` (3 casos) |
| **AC3** Panel público, restringido, Datos y mapa exacto usan las variantes `All` | las 4 pantallas; `publicGrid` sube a 5000 (tope) | `::muestra MÁS de 200 observaciones` (331 → "1–10 de 331") |
| **AC4** Ningún indicador se pinta como mapa crudo | `_IndicatorGroup` separa escalares de desgloses; `_Breakdown` traduce claves wire (`Copy.nivelG4`/`identidadE3`) en orden de escala | `::ningún indicador se pinta como mapa crudo "{...}"` |
| **AC5** Proporciones como porcentaje; etiquetas completas | `_Metric._display`; `Copy`: `observaciones_capturadas`, `proporcion_confirmada`, `identidadE3` | mismo caso (50 % presente, 0.5 ausente) |
| **AC6** Pastel del nivel de paxtle en el panel público | `PaxtlePieChart` (CustomPainter, sin dependencias) + `_PaxtlePieCard`; datos = `distribucion_niveles` (agregado del SERVIDOR sobre todas las confirmadas — inmune a topes de lista) | `::el pastel pinta rebanadas y leyenda` (+ aserción de alto > 0, la trampa de CR-029/032) |
| **AC7** Pastel legible sin depender del color | leyenda SIEMPRE con conteo y % + total; separadores de 2 px; vacío honesto | `PaxtlePieChart (unidad)` (3 casos: vacío, un nivel, niveles en cero) |

**Decisiones.** (a) El pastel usa la MISMA rampa de severidad del mapa de calor (`HeatRampTheme`,
sano→severo): una variable, una codificación en todo el producto, y T7 intacto (cero hex nuevos en
widgets; la prueba-gate `theme_tokens_test` lo vigila y de hecho **atrapó** el primer intento con
rampa propia). Paleta validada con el verificador del método de dataviz: CVD ΔE 14.8, visión normal
15.8; el bajo contraste del amarillo se releva con separadores + leyenda numérica. (b) El nivel es
una escala ORDENADA: las rebanadas van en orden de escala fijo, nunca por tamaño. (c) El pastel se
alimenta del indicador agregado, NO de contar filas de la lista: sobrevive a cualquier paginación.
(d) Render inspeccionado visualmente (golden temporal, luego borrado), no solo afirmado en pruebas.

**Deuda anotada:** el mapa del VOLUNTARIO (móvil/PWA) conserva sus topes (`publicGrid` 500,
observaciones 2000) — arreglarlo exige recompilar y desplegar el bundle del voluntario; y
`/public/grid` escanea a lo más 5000 filas para el binning (suficiente hasta ~5000 confirmadas).

**Gates:** ninguno se enmienda. El texto del pastel repite el caveat (nivel autodeclarado, sin
validación de expertos — gate #8). Sin migración; el despliegue requiere backend + consola.

**Extensión (mismo CR, 2026-08-01):** se retiran también los topes del mapa del **VOLUNTARIO**
(la deuda anotada arriba): `publicObservationsAll` en el cliente móvil (lazo de offset, páginas de
5000) alimenta `publicObservationsProvider`, y `publicGrid` sube su default a 5000 (tope del
backend). Pruebas: `api_client_test.dart::publicObservationsAll recorre offsets hasta la página
corta (CR-034)` y `::publicGrid pide el tope del backend (5000) por defecto (CR-034)`. Queda solo la
deuda del *binning* del calor (≤5000 filas escaneadas, en ambos clientes).

---

## CR-035 — Sesión vencida: aviso visible y re-ingreso amable (2026-08-06)

**Origen:** reporte de voluntarios (*"no podemos subir fotos"*). Diagnóstico en producción: tokens de
7 días (CR-027) venciendo **en lote** el 2026-08-05 (120 `POST /observations` → 401 en un día) y la
app "logueada" en silencio — CR-031 pausa la cola y conserva las fotos, pero el aviso solo aparecía
con cola no vacía, era texto pasivo sin botón, y `sesionRenovada()` no lo llamaba nadie. Diseño y
decisiones en [`CR-035-sesion-vencida-reingreso.md`](../change-requests/CR-035-sesion-vencida-reingreso.md).
**Solo app del voluntario; sin backend, sin migración.** Restricción dura: detectar la sesión vencida
**nunca** cierra sesión ni bloquea la captura offline (gate #3).

| # | Criterio | Implementación | Prueba |
|---|---|---|---|
| **AC1** Un 401 autenticado enciende el aviso; un login fallido sin token NO | `ApiClient.onSessionExpired` (guard `_token != null`) en `_decode`/`_decodeList` — cubre uploader, tracker y providers de una vez; cableado en `apiClientProvider` | `cr035_sesion_vencida_test.dart` (JSON, multipart con `MockClient.streaming`, y sin token) |
| **AC2** Token restaurado ya vencido ⇒ aviso al abrir, sin esperar ningún 401 | `expiryFromJwt`/`tokenVencido` (`models.dart`, claim `exp`, reloj inyectable) + `_comprobarSesionVencida()` en `home_shell.dart` (postFrame y `resumed`) | `cr035_ui_test.dart::JWT vencido al primer frame` |
| **AC3** Aviso en las 4 pestañas, NO descartable, NO bloquea nada (gate #3) | `session_expired_banner.dart` (nuevo; no usa `InfoNote` a propósito) montado en el body de `HomeShell` | `cr035_ui_test.dart` (4 pestañas, sin botón de cierre, capturar sigue posible) |
| **AC4** Nunca cierra sesión ni vacía la cola | `sessionExpiredProvider` es un aviso, no estado de auth; `AuthController` intacto | `cr035_ui_test.dart` + AC9/AC17 de CR-031 (vigentes) |
| **AC5** "Volver a entrar" → login → aviso fuera + cola reanuda sola | botón `session_relogin` → `push(WelcomeScreen)`; `ref.listen(authProvider)` en `pendingQueueProvider` apaga el flag y llama **`sesionRenovada()`** (por fin con caller) | `cr035_ui_test.dart::re-login reanuda la cola` |
| **AC6** Capturar con sesión vencida guarda y lo dice honesto | `capture_screen.dart`: SnackBar `captureSavedSessionExpired` (mira flag de cola Y global) | `cr035_ui_test.dart::SnackBar honesto` |
| **AC7** La tarjeta de pendientes ofrece "Volver a entrar" | `pending_uploads_card.dart` (`pending_relogin`) | `cr035_ui_test.dart` |
| **AC8** El logout manual apaga el aviso | el mismo `ref.listen` (cualquier cambio de sesión invalida el aviso) | `cr035_ui_test.dart::logout apaga` |
| **AC9** Sin `POST /me/sessions` mientras esté vencida; reanuda al re-entrar | `SessionTracker(sesionVencida:)` — el PRIMER 401 sigue pasando (disparador reactivo) | `cr035_sesion_vencida_test.dart` |
| **AC10** Ningún texto nuevo menciona "revisión" (gate #9) | `Copy.sessionExpiredBanner`/`sessionExpiredRelogin`/`captureSavedSessionExpired` | `cr035_ui_test.dart` (prueba de copy) |
| **AC11** Otra cuenta de Google: capturas ajenas ni se suben ni se borran (D8/D1) | sin cambio de código (`next(accountId:)` ya filtra); documentado en §6 del CR | AC10 de CR-031 (aislamiento por cuenta) |

**Gates:** ninguno se enmienda. **#3** protagonista (nada se bloquea, jamás logout forzado); **#9**
con prueba de copy; **#4** intacto — el hook de prueba `CaptureScreen(initialShot:)` es
`@visibleForTesting` (en producción siempre `null`; la cámara sigue siendo la única entrada).
`isSessionExpired` del móvil = **solo 401** (a diferencia del `isAuthError` de la consola,
401||403||410): la pregunta del móvil es "¿se cura re-entrando?" — el 403 no (ya es
`necesitaAtencion`) y el 410 no (cuenta eliminada, camino D6).

**179 pruebas móviles verdes** (152 previas + 27 nuevas: 16 en `cr035_sesion_vencida_test.dart`, 11
en `cr035_ui_test.dart`), 2026-08-06. `web-admin`, `backend`, `welcome_screen.dart`, `AuthController`
y `pending_uploader.dart` sin tocar.

---

## CR-036 — Geografía derivada en el servidor + alcance nacional (2026-08-10)

**Origen:** hallazgo del usuario (*"por vez primera se han detectado registros fuera del estado"*).
Diagnóstico en producción **antes** de tocar código: **39 observaciones al oeste de −102.867** (el
punto más occidental de Aguascalientes) etiquetadas "Calvillo, Aguascalientes", capturadas por una
cuenta entre el 6 y el 8 de agosto. Los 20 rechazos de ese grupo fueron por **calidad de foto**, no
por geografía: el error de etiqueta pasó la revisión humana sin que nadie pudiera verlo.

**Naturaleza:** **cumplimiento** del criterio sellado **Q8-D1** (*"atribuible a estado y municipio
por geolocalización"*), en 🟡 desde el Incremento 2 por falta de los límites. **Ningún gate se
enmienda.** Diseño y decisiones en
[`CR-036-geografia-derivada-y-alcance-nacional.md`](../change-requests/CR-036-geografia-derivada-y-alcance-nacional.md).

**El hallazgo grande no eran las 39.** El ensayo del backfill se corrió en la Fase 0 **sin escribir
en producción** (se exportaron las coordenadas por lectura y se resolvieron contra los límites en
local): **235 filas mal etiquetadas de 2 342**, en exactamente dos transiciones.

| Antes | Después | Filas | de ellas confirmadas |
|---|---|---|---|
| Aguascalientes / **Jesús María** | Aguascalientes / **Aguascalientes** | **196** | 144 |
| Aguascalientes / **Calvillo** | **Zacatecas / Jalpa** | **39** | 19 |

El **57.8 % de lo que el dashboard contaba como Jesús María** está en el municipio de
Aguascalientes. Ese error llevaba meses invisible porque cae dentro del estado y suena plausible;
las 39 solo se vieron porque cruzaron una línea estatal. **0 observaciones quedaron sin resolver.**

| # | Criterio | Implementación | Prueba |
|---|---|---|---|
| **AC1** | `admin_boundary` con cobertura nacional | Marco Geoestadístico INEGI 2025, capa municipal: **2 478 municipios / 32 entidades / 0 geometrías inválidas**; `scripts/geo/preparar_limites_inegi.py` (descarga selectiva por *range requests*: 245 MB de 2.77 GB) | prueba de aceptación del propio script (8/8 puntos de control) |
| **AC2** | El servidor deriva **ignorando al cliente** | `geo.resolver_ubicacion` + precedencia invertida en `routers/observations.py` | `test_cr036_geografia_derivada.py` (3 casos: etiqueta falsa, estado inventado, cliente que no manda nada) |
| **AC3** | Punto fuera de todo polígono ⇒ sin geografía, sin bloquear (gate #3) | `Ubicacion` vacía; el submit continúa | `::test_ac3_*` (2 casos, incluido `admin_boundary` vacía) |
| **AC4** | `cve_ent`/`cve_mun` como clave de agrupación | migración **0009**; `geo_filtros.py` | `::test_ac2_*` + `cr036_filtros_geograficos_test.dart` |
| **AC5** | El cluster real resuelve a **Zacatecas** | límites a resolución original | prueba de aceptación del preparador (4 coordenadas reales del cluster) |
| **AC6** | `GET /geo/resolve` | `routers/geo.py` | `::test_ac6_*` (3: resuelto, fuera de cobertura = **200 no 404**, validación de rango) |
| **AC7** | `GET /geo/estados` y `/geo/municipios` | mismo router; catálogo por `SELECT DISTINCT` sobre la capa municipal | `::test_ac7_*` (2, incluye que son públicos) |
| **AC8** | `municipio` en los 3 endpoints públicos | `routers/public.py` + `indicators.py` | suites de `public`/`indicators` sin regresión |
| **AC9** | `summary` gana `por_estado` y `por_municipio_cve` | `routers/analytics.py` | `test_cr010_analytics.py` (actualizada) |
| **AC10** | Las 4 rutas de analítica filtran por geografía | `geo_filtros.CLAUSULA_GEO` | `cr036_filtros_geograficos_test.dart::las 4 rutas…` |
| **AC11** | `participation.csv` declara que el filtro solo aplica a observaciones | nota emitida **solo con filtro activo** (sin filtro, el CSV sale byte a byte igual que antes) | `routers/analytics.py` |
| **AC12** | `/public/grid` agrega en SQL, **sin tope de 5 000** | binning equivalente a `obfuscate_to_grid`; el parámetro `limit` desaparece | `test_public_grid.py` **sin cambios** — compara coordenadas exactas de celda y pasa: el SQL produce las mismas celdas que el Python |
| **AC13** | La captura no tiene selectores de ubicación | `observation_form.dart`; **`municipios.dart` eliminado** | `observation_form_test.dart::AC13` |
| **AC14** | Con red: nombre del lugar + coordenadas | `GeoLugar.etiqueta` | `::AC14` |
| **AC15** | Sin red: coordenadas + aviso honesto; captura intacta | `ApiClient.geoResolve` **nunca lanza** | `::AC15` (2 casos, incl. sin resolvedor) |
| **AC16** | Precisión del GPS capturada y enviada | los dos `capture_service_*`; `gps_accuracy_m` con CHECK ≥ 0 | `::AC16` (2) + `::test_ac16_*` backend (3) |
| **AC17** | Ningún catálogo local | `municipios.dart` borrado; el estado de una institución sale de `/geo/estados` | `cr010_movil_test.dart` (actualizada) |
| **AC18/19** | Filtros estado+municipio en Panel público y Datos | `widgets/geo_filter.dart` (dependientes, por clave) | `cr036_filtros_geograficos_test.dart` (3, incl. limpieza al cambiar estado y degradación si el catálogo falla) |
| **AC20** | Las dos descargas heredan los filtros | `data_screen.dart` + `api_client.dart` | `::las 4 rutas…` |
| **AC21** | Tarjeta "Por estado" en Datos | `_SummaryCards` (antes que la de municipio) | `data_screen.dart` |
| **AC22** | Los mapas encuadran sobre los datos | `encuadreDe` + `CameraFit.bounds`; el centro de Aguascalientes queda solo de respaldo | `::AC22` (3: vacío, dos estados, punto único) |
| **AC23** | Filtro geográfico en Revisión; desglose en Monitor | `review_screen.dart`, `monitor_screen.dart` | análisis + suite de consola |
| **AC24** | Backfill con simulacro y guarda | `backend/app/backfill_geografia.py` (`--simulacro` / `--aplicar --esperado N`) | `test_cr036_backfill.py` (6: conteo exacto, no escribe en simulacro, corrige y llena claves, conserva lo no resuelto, total invariante, ningún veredicto tocado) |
| **AC25** | Q8 pasa de 🟡 a ✅ | esta sección | — |

**Decisiones de implementación.**

(a) **`ST_Subdivide` resultó innecesario.** Estaba previsto en el CR, pero medido da **1.7–11.4 ms**
por consulta con la geometría sin simplificar (62 MB de tabla, 148 GB libres en el volumen). Los
límites se cargan a **resolución original**: degradarlos habría comprometido justo la frontera que
este CR necesita resolver bien.

(b) Se corrigió que `derive_estado_municipio` casteaba a `geometry` dentro del `WHERE`, lo que
**inhabilitaba el índice GiST**; con la tabla vacía daba igual, con 2 478 polígonos habría sido un
escaneo secuencial con un test caro por fila.

(c) Los límites de prueba son **sintéticos** (3 cuadrados con claves INEGI reales): una prueba no
debe depender de un artefacto de 62 MB. La fidelidad del dataset real la verifica el preparador
contra coordenadas reales de producción.

(d) La cola offline (CR-031) **lee el formato anterior sin romperse**: hay teléfonos con capturas
guardadas con `estado`/`municipio`; se ignoran y se acepta la ausencia de `gps_accuracy_m`. Una cola
pendiente no puede perderse por un cambio de esquema.

(e) `estado`/`municipio` **siguen aceptándose** en el submit aunque se ignoren: los bundles PWA en
caché los siguen enviando, y rechazar el POST los dejaría sin poder subir.

**Deuda cerrada de paso:** `/public/grid` ya no escanea un tope de 5 000 filas (deuda anotada en
CR-034) — en **los dos** clientes.

**Deuda anotada:** editar estado/municipio desde la consola (decisión del usuario: fuera de este CR);
aviso de baja precisión en la consola (el dato ya se captura); actualización de los límites cuando
INEGI publique una versión nueva del marco.

**584 pruebas verdes** (21 contrato · 9 mock · **235** backend · **183** móvil · **136** consola),
2026-08-10. Delta: +16 backend, +4 móvil, +8 consola.

---

## CR-037 — La foto se ve antes de enviarla (2026-09-08)

**Origen:** el usuario reporta, revisando observaciones en la consola, que muchas fotos se rechazan
por problemas evidentes de la imagen y el voluntario no puede darse cuenta. Al leer el código el
hueco era mayor: `observation_form.dart` **nunca renderizaba la imagen** (solo la pasaba al draft) y
**ninguna** pantalla del voluntario la mostraba — ni antes, ni durante la captura de datos, ni
después de enviarla. El primer humano en verla era quien revisaba, con la observación ya registrada.
Diseño y decisiones en [`CR-037-preview-de-la-foto.md`](../change-requests/CR-037-preview-de-la-foto.md).
**Solo app del voluntario; sin backend, sin migración.**

| # | Criterio | Implementación | Prueba |
|---|---|---|---|
| **AC1** El formulario muestra la foto capturada | `CapturaPreview` (nuevo) en una `SectionCard` al **principio** del `ListView` de `observation_form.dart` | `cr037_preview_foto_test.dart` |
| **AC2** La miniatura tiene alto **real > 0** aunque la imagen no decodifique | `SizedBox(112×112)` fijo + `BoxFit.contain`; la prueba usa `tester.getSize`, no `findsOneWidget` | ídem (bytes de utilería ilegibles a propósito) |
| **AC3** Tocar la miniatura abre el visor con zoom | `_VisorFotoCaptura` (`Dialog.fullscreen` + `InteractiveViewer`, pellizco/doble toque, 1×–8×), espejo del visor de CR-029 | ídem |
| **AC4** El visor cierra y devuelve al formulario | botón `captura_foto_visor_cerrar` | ídem |
| **AC5** "Repetir foto" avisa a la pantalla; sin callback no hay botón pero la foto se ve | `onRepetirFoto` opcional → `CaptureScreen._repetirFoto()` (`_shot = null`) | ídem |
| **AC6** El formulario se siembra con etiquetas y espeja cada cambio | `EtiquetasCaptura` (valor inmutable, `copyWith`, `completa`) + `etiquetasIniciales`/`onEtiquetasChanged` | ídem |
| **AC7** Repetir **conserva** las etiquetas del mismo árbol y no encola nada | las etiquetas viven en `_CaptureScreenState`, no en el `State` del formulario (que se destruye al volver la cámara) | ídem (ciclo completo: se invoca el `onCaptured` del `CapturePane` real, sin seam de producción nuevo) |
| **AC8** Tras registrar, el árbol siguiente empieza en blanco | `_submit` limpia `_etiquetas` junto con `_shot` | ídem |
| **AC9** Gate #4: ninguna acción de galería | "Repetir foto" reabre el mismo `CapturePane` | prueba de pantalla + grep sobre `main.dart.js` compilado: **0** ocurrencias |
| **AC10** Gate #9: la tarjeta no insinúa veredicto | `Copy.captureFoto*` hablan de la foto, nunca de revisión | prueba de copy |

**Gates:** ninguno se enmienda. **#4** protagonista (repetir = cámara, jamás galería); **#9** con
prueba de copy; **#3** intacto — ampliar trabaja sobre la imagen que ya está en el dispositivo, sin
red, así que funciona igual capturando sin señal.

**Decisión de diseño con precedente:** `BoxFit.contain`, nunca `cover` — recortar una foto que el
voluntario está a punto de juzgar puede esconder justo lo que la invalida (mismo criterio que el fix
de CR-032). Y **alto fijo**, por la trampa que este repo ya pagó dos veces (CR-029 y el fix de
CR-032: `Size(1048, 0)`, en el árbol e invisible).

**Fuera de alcance:** la **orientación** de la foto (iba a ser CR-038) se **omitió por decisión del
usuario** — con la miniatura, el voluntario ve que no puede enviarla así. Salvedad anotada: por el
camino de respaldo (`image_picker`) el JPEG sí trae EXIF `Orientation` y no se verificó si Flutter Web
la honra al pintar; de honrarla, esa minoría se vería bien en la miniatura y de lado en la consola.
**Descartar** la captura completa es CR-039 (pendiente). Reparar las ~6 000 fotos ya capturadas:
descartado explícitamente.

**195 pruebas móviles verdes** (183 previas + 12 nuevas en `cr037_preview_foto_test.dart`),
2026-09-08. `backend`, `web-admin`, `contract` y `mock-validator` no se tocan y no se re-corrieron.
Verificado además que el **build web de producción compila** (`flutter build web --release`) y que los
textos nuevos están en el `main.dart.js` servido — la rama web del import condicional
(`captura_imagen_web.dart`) no la compila `flutter test`, que corre sobre la rama io.
