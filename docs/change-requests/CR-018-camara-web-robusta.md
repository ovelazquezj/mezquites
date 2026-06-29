# CR-018 — Cámara web robusta (`getUserMedia`)

| Campo | Valor |
|---|---|
| **ID** | CR-018 |
| **Fecha** | 2026-06-28 |
| **Estado** | ✅ Implementado en `main` (local), pendiente de desplegar |
| **Alcance** | `mobile/` (solo el camino **web** desplegado) |
| **Relación** | Refuerza CR-005 (web del voluntario) · gate #4 (captura cámara) · enlaza CR-019 (reportar problema) |
| **Ejecución** | Directo sobre `main`, por el orquestador |

## 1. Contexto

En pruebas de campo un **Honor X9** **no pudo usar la cámara** y, más grave, a **ningún** usuario el
navegador le pidió **permiso de cámara**. Causa raíz:

1. La captura web usaba `image_picker` con `<input capture>`, que **delega al sistema operativo** y por
   diseño **nunca solicita permiso por navegador** (el permiso lo gestiona la app de cámara del SO, no la
   PWA). En algunos dispositivos eso fallaba en silencio.
2. El botón de captura se **deshabilitaba** cuando `isMobileWebBrowser()` no reconocía el *user-agent*.
   Varios Honor (y otros equipos) **no se reconocen** por UA → el botón quedaba **muerto**, sin forma de
   capturar.

El alcance es **solo el camino WEB** (la app desplegada es la PWA; el camino nativo está descartado).

## 2. Decisión del usuario (2026-06-28)

Rehacer la captura web sobre **`getUserMedia`** (que sí dispara el permiso del navegador y da preview en
vivo) y **quitar la compuerta de UA** que dejaba el botón muerto en dispositivos no reconocidos.

## 3. Qué se hizo

| Pieza | Detalle |
|---|---|
| Camino principal `getUserMedia` | Preview en vivo con un `<video>` embebido como `HtmlElementView`; captura por `<canvas>` → `toBlob('image/jpeg')` → bytes → `MultipartFile.fromBytes`. |
| Cámara trasera con reintento | `facingMode: { ideal: 'environment' }`; ante `OverconstrainedError` se reintenta con `{ video: true }` (defensa: no fallar si el equipo no satisface la restricción). |
| "Cambiar cámara" | `enumerateDevices()` + botón para alternar lentes (defensa multi-lente en equipos con varias cámaras traseras). |
| Teardown robusto | Al cerrar/reintentar se **detienen TODOS los tracks** del stream (defensa "cámara ocupada" por una sesión previa no liberada). |
| Permiso del navegador | `getUserMedia` **sí** dispara el diálogo de permiso del navegador (el problema raíz). |
| Errores legibles | Mapeo de errores por `name` (`NotAllowedError`/`NotFoundError`/`NotReadableError`/genérico) a textos en español (permiso denegado / cámara no encontrada / cámara en uso / error genérico). |
| **Fallback** | Para WebViews **sin** `getUserMedia`, se conserva el camino `image_picker` / cámara del SO. |
| **Se quitó la compuerta de UA** | `isMobileWebBrowser()` **ya no deshabilita** la captura; queda solo como **pista informativa** sin uso vivo. |
| UI de error | Ofrece **"Reintentar"**, **"Tomar con la cámara del sistema"** (fallback) y **"Reportar un problema"** (enlaza a CR-019). |
| Colisión de nombre | Se resolvió el choque de `CameraDevice` (de `image_picker` vs. el tipo propio) con `hide CameraDevice` en el import. |

### Archivos

- `mobile/lib/src/services/camera_web.dart` (+ `camera_web_shared.dart`, `camera_web_stub.dart`,
  `camera_web_impl.dart`)
- `mobile/lib/src/services/capture_service_web.dart`
- `mobile/lib/src/ui/screens/capture_pane_web.dart`
- `mobile/lib/src/services/web_platform.dart`
- Cadenas de cámara en `mobile/lib/src/ui/copy.dart`

## 4. Gates

- **Gate #4 (captura = cámara, nunca galería):** **intacto** — ambos caminos (`getUserMedia` y el
  fallback `image_picker` con `capture`) son **cámara en vivo**, jamás selección de galería. Un escritorio
  con webcam captura como cámara (no abre el explorador de archivos).
- **Gate #2 (sin PII):** sin cambios — solo cambia el mecanismo de obtención de los bytes de la imagen.
- **Gate #3 (sin gating):** **reforzado** — al quitar la compuerta de UA, **ningún dispositivo queda
  bloqueado** por no ser reconocido.
- Resto de gates: sin cambios.

## 5. Pruebas / verificación

- `flutter build web` compila.
- `flutter test` → **66** verdes. Las rutas web-only (`getUserMedia`, `<video>`/`<canvas>`) **no se
  compilan** en la VM de pruebas; el preview real requiere **build web + dispositivo**.
- Verificación de campo del preview/permiso queda para el dispositivo real tras desplegar.

## 6. Notas

- Pendiente humano en **Google Cloud** (origen JS autorizado + *test users* del OAuth) sigue vigente,
  igual que en CR-015; es independiente de este cambio.
- El camino nativo (`camera` + `native_exif`) ya no es la ruta desplegada; el foco es la PWA.
