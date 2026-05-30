# Mezquite — App del voluntario (Flutter)

App móvil de ciencia ciudadana del mezquite. **Target primario: Android.** Un
solo código base, arquitectura limpia (api / models / state / ui / services).

> Frontera (gate #1): esta app es de **observación y datos**. No promete control
> fitosanitario, reducción de infestación ni recomendaciones de manejo.

## Requisitos

- Flutter SDK `>=3.27.0` (probado con **Flutter 3.27.1 / Dart 3.6.0**).
- Android SDK (compileSdk 35, minSdk 24) para compilar/correr en Android.

## Cómo correr / verificar

```bash
cd mobile
flutter pub get          # resuelve dependencias
flutter analyze          # análisis estático (debe salir "No issues found!")
flutter test             # pruebas unit + widget (gate #7)
```

### Correr en emulador o dispositivo Android (criterio T1)

```bash
flutter devices                       # lista dispositivos/emuladores
flutter run -d <android_device>       # debug
# Apunta la app a tu backend (por defecto http://10.0.2.2:8000/api/v1):
flutter run --dart-define=API_BASE_URL=http://<host>:8000/api/v1
```

`10.0.2.2` es el alias del host desde el emulador Android. Para un dispositivo
físico, usa la IP de la máquina que corre el backend.

### Build de APK

```bash
flutter build apk --debug      # o --release
```

### Prueba de integración en dispositivo (EXIF real, T1/gate #4)

`integration_test/capture_exif_test.dart` verifica que la captura inyecta
lat/lon/timestamp en el EXIF. Requiere emulador/dispositivo:

```bash
flutter test integration_test/capture_exif_test.dart -d <android_device>
```

## Estado de verificación

- `flutter pub get` ✅ · `flutter analyze` ✅ (sin issues) · `flutter test` ✅
  (30 pruebas verdes).
- `flutter build apk --debug` ✅ — APK construido
  (`build/app/outputs/flutter-apk/app-debug.apk`). T1 (compila para Android)
  verificado.
- La **prueba de integración con cámara real** (EXIF en hardware) corre solo en
  emulador/dispositivo; pendiente de ejecución física.

## Arquitectura (`lib/src/`)

| Capa | Archivos |
|---|---|
| **Tema/design system** | `theme/design_tokens.dart` (carga `assets/design-tokens.json`, fuente única), `theme/app_theme.dart` (genera `ThemeData`; **sin colores literales en widgets**, T7) |
| **Modelos** | `models/enums.dart` (vocabulario controlado = `Literal` del backend), `models/models.dart` |
| **API** | `api/api_client.dart` (consume `/api/v1`: auth, observations [multipart], me/feedback, me/profile, gamification/rankings, public/*) |
| **Servicios** | `services/capture_service.dart` (cámara nativa + EXIF, gate #4), `services/session_store.dart` (sesión sin PII + flag disclaimer) |
| **Estado** | `state/providers.dart` (Riverpod), `state/app_config.dart` |
| **UI** | `ui/screens/*`, `ui/widgets/*`, `ui/copy.dart` (todo el texto, para revisión de copy) |

## Mapa de gates en el código

- **#2 Sin PII** — `RegisterScreen`/`RecoverScreen`/`AccountScreen` solo manejan
  handle; `RegisterRequest` envía `institution_id` + `role`. Código de respaldo
  (+ QR) para recuperación.
- **#3 Sin gating** — `LearningScreen`: ningún módulo se bloquea; `HomeShell`:
  todos los destinos disponibles; etiqueta de identidad sin desbloquear funciones.
- **#4 Cámara nativa + EXIF** — `CaptureScreen`/`CaptureService`: solo
  `takePicture()`; **no hay `image_picker` ni galería**; EXIF GPS/fecha inyectado.
- **#5 Obfuscación 1 km** — `DashboardScreen` consume `/public/observations`
  (obfuscadas server-side) y nunca pide coords exactas; aviso visible.
- **#8 Autodeclarado** — `G4Selector` y toggles: la UI no afirma validación.
- **#9 Sin estado de validación individual** — el voluntario nunca ve veredicto
  por observación; solo feedback **agregado** vía `/me/feedback`.

## Placeholders declarados

- **Texto final del disclaimer** (`Copy.disclaimerBody`): texto-base derivado de
  Q7-D1 (buenas prácticas de campo). El copy definitivo es anexo del protocolo
  → marcado `[PLACEHOLDER_TEXTO_FINAL]`.
- **Contenidos de Aprendizaje** (`LearningModule.placeholders`): producción AU2
  (Q5.C) → marcado `[PLACEHOLDER_AU2]`.
- **Catálogo de instituciones**: el backend solo expone `GET /admin/institutions`
  a `admin_consorcio`. Para que el voluntario elija institución en el alta se
  requiere un endpoint de catálogo accesible (p.ej. `GET /institutions`). Hasta
  entonces el alta ofrece "Independiente" + "solicitar agregar" (ver reporte al
  Orquestador).
- **Iconos de launcher**: placeholder sólido (azul Rotary). Sustituir por el
  arte final cuando exista guía de marca.

## Design system

El tema se genera **exclusivamente** desde `assets/design-tokens.json`, que es
una copia exacta de `docs/design-system/design-tokens.json` (fuente única). Una
prueba verifica que ambos archivos son idénticos. Los hex de marca Rotary son
provisionales (pendientes de la guía oficial); al actualizar el JSON fuente, se
recopia a `assets/` y el tema hereda el cambio.
