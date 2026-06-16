# CR-005 — FE web del voluntario (Flutter Web)

| Campo | Valor |
|---|---|
| **ID** | CR-005 |
| **Título** | Versión web de la app del voluntario reutilizando el código Flutter actual |
| **Fecha** | 2026-06-16 |
| **Estado** | **W0 decidido (2026-06-16): web para teléfono/tablet (opción a).** Listo para ejecutar tras CR-004 W3 (CORS). |
| **Prioridad** | **Alta** — ruta de lanzamiento (meta **2026-07-10**; evita la certificación de tiendas). |
| **Depende de** | CR-002 (auth) · CR-003 (branding) · **CR-004 W3 (CORS)**; auth pública requiere CR-004 W1 + hosting (H6) |
| **Alcance** | App Flutter del voluntario compilada a **web para teléfono/tablet** (no escritorio). Sin cambios al backend salvo CORS (CR-004 W3). |

---

## 1. Contexto

La app del voluntario es Flutter; **Flutter Web** ya está probado en este repo (el web-admin). Se quiere
una **versión web** del voluntario reutilizando el código. La captura+subida **sí es posible en web**
con el paquete oficial **`image_picker`**: `pickImage(source: ImageSource.camera)` pide permiso de
cámara al navegador, se leen los bytes con `readAsBytes()` (sin rutas de archivo) y se suben con
`http.MultipartFile.fromBytes`.

Hoy la capa de captura **no es portable**: usa `camera` + `native_exif` + `MultipartFile.fromPath`
(ruta de archivo). Por eso este CR introduce una **capa de captura conmutable por plataforma**.

**Contexto de lanzamiento (2026-06-16):** esta web es la **ruta para lanzar el 10 de julio** sin esperar
la certificación de tiendas (~3 semanas). Es para **teléfono/tablet** (no escritorio); idealmente como
**PWA instalable** ("añadir a pantalla de inicio"). El camino crítico **no** es la ingeniería sino las
**dependencias externas**: hosting del backend+web con HTTPS (H6) y, para auth pública, proyecto
Firebase + aviso de privacidad.

## 2. Gates — punto de decisión (W0, sellado)

**Gate #4 (sellado):** *"solo cámara nativa con EXIF; galería deshabilitada"*. En web:
- En **navegador móvil**, `ImageSource.camera` abre la cámara real.
- En **navegador de escritorio**, suele **degradar a selector de archivos** (≈ galería) → roza el gate #4.
- **`native_exif` no corre en web** (la inyección de EXIF GPS/fecha es nativa).

**DECISIÓN (2026-06-16): opción (a).** La web es para **teléfono/tablet**; en escritorio no es objetivo
y se **bloquea/advierte** la captura. **No se enmienda el gate #4** (en móvil/tablet la cámara del
navegador es real). Las opciones que se evaluaron:
- **(a) Web solo en navegador móvil** (cámara real) — **no** enmienda el gate #4. ✅ **ELEGIDA**
- **(b) Relajar gate #4 para web** (permitir `image_picker`, aceptando el fallback de escritorio) —
  **enmienda sellada** (requiere tu OK explícito, como CR-001/002).
- **(c) Web "companion" sin captura** (solo mapa/perfil/rankings/onboarding) — **no** enmienda el gate #4.

Gates #2 (sin PII), #3 (sin gating), #5 (obfuscación), #6 (paridad), #7 (trazabilidad): intactos.

## 3. Qué se reutiliza vs. qué es nuevo

| Se reutiliza tal cual | Nuevo / específico de web |
|---|---|
| `ApiClient`, modelos, tema/design-tokens, copy | Capa de captura web (`image_picker` + bytes) |
| Pantallas mapa, perfil, rankings, onboarding, ayuda | `submitObservation` por **bytes** (`fromBytes`) |
| Auth (`firebase_auth`/`google_sign_in` web) | Habilitar target web + config Firebase web |
| `geolocator` (web: geolocalización del navegador) | Estrategia de EXIF/ubicación en web (W2) |

## 4. Diseño técnico

- **Abstracción de captura** (`CaptureService` con interfaz común) e implementaciones por plataforma
  vía *conditional imports*: móvil = `camera`+`native_exif`+`fromPath` (actual); web =
  `image_picker`(camera)+`readAsBytes`.
- **`ObservationDraft`** admite **bytes** además de ruta; `ApiClient.submitObservation` usa
  `MultipartFile.fromBytes` cuando hay bytes (web) y `fromPath` cuando hay ruta (móvil). Los headers y
  el campo `payload` (8 etiquetas) no cambian (el contrato del backend es el mismo).
- **Ubicación:** `geolocator` web para lat/lon en el `payload` (el backend ya usa el payload, no el
  EXIF). EXIF embebido: opcional vía lib Dart o sellado server-side (W2).
- **Target web:** habilitar web en el proyecto del voluntario (build como el web-admin) + config
  Firebase web + `google_sign_in` web.
- **CORS:** el navegador necesita CORS en el backend → **dependencia de CR-004 W3**.

## 5. Workstreams

| WS | Objetivo |
|---|---|
| **W0** | ✅ **Decidido: web para teléfono/tablet (a).** En escritorio se restringe la captura; gate #4 intacto. |
| **W1** | Capa de captura+subida conmutable (móvil `fromPath` / web `image_picker`+`fromBytes`). |
| **W2** | Ubicación/EXIF en web (`geolocator` web; decidir embebido EXIF vs payload+server). |
| **W3** | Habilitar target web del voluntario + Firebase/`google_sign_in` web. |
| **W4** | **Dependencia:** CORS (CR-004 W3). |
| **W5** | Pruebas (incl. captura por bytes) + build web + deploy + smoke. |

## 6. Desglose por agente

| # | Agente | Unidad | Archivos | Pruebas |
|---|---|---|---|---|
| E0 | Arquitecto | Cerrar W0 (gate #4) y la estrategia EXIF (W2) | `bitacora_sdd_mezquite.md` (si W0=b) | — |
| E1 | Dev móvil/Flutter | Abstracción de captura + `submitObservation` por bytes (W1) | `mobile/lib/src/services/capture_service*.dart`, `api/api_client.dart`, `models/models.dart` | mock con `fromBytes`; no rompe móvil |
| E2 | Dev móvil/Flutter | Target web + Firebase/google_sign_in web (W3) | `mobile/web/**`, `pubspec.yaml`, `google_auth_service.dart` | `flutter build web` OK |
| E3 | Dev backend | CORS (si no se hizo en CR-004 W3) | `backend/app/main.py` | preflight + orígenes |
| E4 | Tester/QA | Pruebas + smoke web + trazabilidad | `mobile/test/*`, `TRACEABILITY.md` | suite verde |
| E5 | Documentador | QUICKSTART/DESPLIEGUE (cómo levantar el FE web) | docs | al día |

## 7. Criterios de aceptación

- AC1: En **navegador móvil**, "Entrar con Google" (mock) → captura por cámara → la observación se
  **sube por bytes** (`MultipartFile.fromBytes`) y queda `aceptada` en el backend. *(según W0)*
- AC2: El **móvil nativo no se rompe**: sigue usando `camera`+`native_exif`+`fromPath` (suite móvil verde).
- AC3: `flutter build web` del voluntario compila; mapa/perfil/rankings/onboarding funcionan en web.
- AC4: El navegador llama la API **sin** workaround de Chrome (CORS de CR-004 W3 habilitado).
- AC5: **Sin PII de más** (gate #2): la auth web guarda solo el `sub` opaco.
- AC6: La postura de **gate #4** queda explícita según W0 (y enmendada en la bitácora **solo** si W0=b).

## 8. Riesgos

- **Escritorio degrada a selector de archivos** (≈ galería) → resuelto por W0 (restringir a móvil, o
  enmendar gate #4, o companion sin captura).
- **EXIF nativo no aplica en web** → ubicación por `geolocator`+payload; EXIF embebido opcional (W2).
- **Dependencia de CORS** (CR-004 W3): sin él, el FE web no llama a la API desde el navegador.
- **Auth real en web** requiere config Firebase web (CR-004 W1); testeable con el mock entre tanto.

## 9. Definition of Done

W0 resuelto (y bitácora enmendada solo si W0=b); captura conmutable con móvil intacto (AC2); build web
verde y funcional (AC3); CORS activo (AC4); gate #2 respetado (AC5); pruebas verdes con números reales.

> **Estado:** propuesto para tu revisión. Al aprobarlo lo dejo en el índice y arranco por **W0**
> (tu decisión de gate #4). Requiere CR-004 W3 (CORS) integrado.
