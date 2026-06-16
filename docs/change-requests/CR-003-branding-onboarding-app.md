# CR-003 — Branding, splash, ícono y onboarding de la app móvil

| Campo | Valor |
|---|---|
| **ID** | CR-003 |
| **Título** | Identidad visual del "Proyecto Mezquite" en la app Flutter: ícono, splash nativo, onboarding y tema |
| **Fecha** | 2026-06-15 |
| **Estado** | **Aprobado — sin codificar** |
| **Prioridad** | Media |
| **Depende de** | — (independiente; puede ir en paralelo a CR-001/CR-002) |
| **Alcance** | **Apps Flutter:** paleta/tema en `mobile/` **y** `web-admin/`; ícono, splash y onboarding solo en `mobile/`. El **backend NO se toca.** |

---

## 1. Objetivo y alcance

Aplicar la identidad visual oficial del **Proyecto Mezquite** a la app móvil del voluntario: **ícono
de app**, **splash nativo**, **onboarding** de 3 pantallas en el primer arranque, y alineación del
**tema** a la paleta oficial, usando los assets de marca de [`branding/`](../../branding/).

**Dentro de alcance (in):**
- **Paleta / design-tokens → ambas apps Flutter** (`mobile/` y `web-admin/`): se actualiza la fuente
  canónica `docs/design-system/design-tokens.json` y las **dos copias** empaquetadas.
- **Mobile (`mobile/`):** `pubspec.yaml`, configuración de `flutter_launcher_icons` y
  `flutter_native_splash`, archivos nativos generados en `mobile/android/` e `mobile/ios/`, código Dart
  del onboarding, tema y el flag de primer arranque.

**Fuera de alcance (out):**
- **Backend** (FastAPI/PostGIS) — explícitamente intacto.
- Los **SVG de referencia** `branding/onboarding_*.svg`, `branding/splash.svg` y los `icon_*.svg`:
  son **mockups**, **no** se incrustan como imagen final (el texto y los controles son widgets Flutter).
- **Ícono / splash / onboarding del web-admin:** el web-admin **solo** recibe la **paleta**; no tiene
  ícono de launcher, splash nativo ni onboarding en este CR.

---

## 2. Contexto técnico (estado actual verificado)

- El tema se genera **exclusivamente desde los design tokens** (`mobile/assets/design-tokens.json` →
  `theme/design_tokens.dart` → `theme/app_theme.dart`, principio T7). **No** hay colores literales en
  `app_theme.dart`: cambiar la paleta = cambiar los **tokens**, no el ThemeData.
- Los tokens actuales son **Rotary provisionales** (`primary #17458F`, `secondary #F7A81B`,
  `accent #4C9A5A`), marcados `PENDIENTE_marca_rotary`. **No** coinciden con la paleta oficial Mezquite
  de este CR → hay que actualizarlos (ver §5.4 y §8).
- **Fuente única de tokens (T7):** la canónica es `docs/design-system/design-tokens.json`;
  `mobile/assets/design-tokens.json` y `web-admin/assets/design-tokens.json` son **copias** empaquetadas
  (ambas con la misma paleta Rotary). Cambiar la paleta = actualizar **los tres** archivos.
- **`shared_preferences` ya es dependencia** (`^2.3.3`) y existe `SessionStore` con el patrón
  "mostrar una vez" (`disclaimerSeen`/`markDisclaimerSeen`). El flag de onboarding **reutiliza** ese
  patrón → `shared_preferences` **no** es dependencia nueva.
- El ruteo de arranque está en `src/app.dart`: hoy va a `WelcomeScreen` (sin sesión) o `HomeShell`
  (con sesión). El onboarding se inserta **antes** de ese ruteo (ver §5.5).
- `branding/` está en la **raíz del repo**, pero el paquete Flutter vive en `mobile/`. Los comandos de
  `flutter_launcher_icons`/`flutter_native_splash` corren **dentro de `mobile/`**, así que las rutas
  `branding/...` deben resolverse como `../branding/...` **o** (recomendado) copiar los **masters** a
  `mobile/assets/branding/` para que el paquete sea autocontenido (ver §5.1 y §8).

---

## 3. Gates — impacto

**Este CR NO enmienda ningún gate.** Salvaguardas a respetar:
- **Gate #3 (sin gating):** el onboarding es **informativo y omitible** ("Saltar"), se muestra **una
  sola vez** y **no** bloquea ninguna funcionalidad ni implica certificación.
- **Gate #2 (sin PII):** el flag de primer arranque es un **booleano local** en `shared_preferences`;
  no introduce PII.
- **Gates #4/#5/#6/#7:** sin cambios (no se toca captura, geolocalización, backend ni contrato).

> **Nota de gobernanza:** la bitácora tiene pendiente *"confirmar hex de marca con la guía oficial de
> Rotary"* y los tokens están `provisional`. La **paleta oficial Mezquite** de este CR **resuelve** ese
> pendiente para la app: el Documentador actualiza el `status` de los tokens y lo anota (no es enmienda
> de gate, es completar un dato operativo pendiente para **ambas apps Flutter**).

---

## 4. Decisiones tomadas (especificación del usuario)

Paleta oficial: **navy `#1F3A6E`** (primary / fondo splash) · **blue `#2E6FB7`** · **gold `#E0A21A`**
(accent) · **green `#5C9A3A`** · **white `#FFFFFF`**.

1. **Ícono** vía `flutter_launcher_icons` (dev_dependency), fuente `branding/icon_master_1024.png`,
   Android + iOS, `remove_alpha_ios: true`, adaptive icon con `background "#1F3A6E"` y foreground el
   mismo master.
2. **Splash** vía `flutter_native_splash` (dev_dependency), `color "#1F3A6E"`, imagen
   `branding/splash_logo_master.png`, bloque `android_12`, `fullscreen: true`.
3. **Onboarding** de 3 pantallas en Dart (no incrustar SVG con texto): `PageView` + dots + "Saltar" +
   botón inferior ("Siguiente" / "Comenzar"); contenido exacto en §5.5; **una sola vez** (flag).
4. **Tema:** `ColorScheme` con `primary #1F3A6E`, `secondary #E0A21A` y la paleta; wordmark "Mezquite"
   en una **serif de Google Fonts** (vía `google_fonts`; la fuente concreta se declara al implementar —
   este CR **no** sugiere ninguna).

---

## 5. Diseño técnico (a nivel de archivo)

### 5.1 Dependencias y assets

**`mobile/pubspec.yaml`:**
- **dev_dependencies (nuevas):** `flutter_launcher_icons`, `flutter_native_splash`.
- **dependencies (nuevas):**
  - `google_fonts` — **requerida** para el wordmark serif. La fuente concreta de Google Fonts se
    **elige al implementar**; este CR **no** sugiere ninguna.
  - `flutter_svg` — **condicional:** solo si se usan los `onboarding_*.svg` como apoyo visual.
- **`shared_preferences`:** ya presente — **no** agregar.

**Copia de assets desde `branding/` (REQUERIDA):** `branding/` está fuera del paquete `mobile/`, así
que se **copian** los archivos necesarios a `mobile/assets/branding/` y se declaran en `flutter: assets:`:

| Origen (`branding/`) | Destino (`mobile/assets/branding/`) | Uso |
|---|---|---|
| `icon_master_1024.png` | igual | ícono (`flutter_launcher_icons`) |
| `splash_logo_master.png` | igual | splash (`flutter_native_splash`) |
| `onboarding_1.svg`, `onboarding_2.svg`, `onboarding_3.svg` | igual | apoyo visual del onboarding (**solo si** se usa `flutter_svg`) |
| `logo_horizontal.png` (o `.svg`) | igual | wordmark en Welcome/onboarding (opcional) |

> El **web-admin** **no** recibe imágenes de branding: solo la **paleta** vía tokens (§5.4).

### 5.2 Ícono de app — `flutter_launcher_icons`

Config (en `pubspec.yaml` o `flutter_launcher_icons.yaml`), **rutas relativas a `mobile/`**:

```yaml
flutter_launcher_icons:
  image_path: "assets/branding/icon_master_1024.png"
  android: true            # mipmaps mdpi → xxxhdpi
  ios: true                # AppIcon set
  remove_alpha_ios: true
  adaptive_icon_background: "#1F3A6E"
  adaptive_icon_foreground: "assets/branding/icon_master_1024.png"
```

Comando previsto (lo ejecuta el implementador, **no** este CR): `dart run flutter_launcher_icons`.
Genera/sobrescribe `mobile/android/app/src/main/res/mipmap-*/` y
`mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

### 5.3 Splash nativo — `flutter_native_splash`

```yaml
flutter_native_splash:
  color: "#1F3A6E"
  image: "assets/branding/splash_logo_master.png"
  android_12:
    color: "#1F3A6E"
    image: "assets/branding/splash_logo_master.png"
  fullscreen: true
```

Comando previsto: `dart run flutter_native_splash:create`. Genera/sobrescribe recursos en
`mobile/android/` (drawables, `styles.xml`, `colors.xml`) e `mobile/ios/` (LaunchScreen).

### 5.4 Tema y paleta (design-tokens → ambas apps Flutter)

Como el tema es **token-driven (T7)**, **no** se hardcodean colores en `app_theme.dart`. La paleta se
actualiza en **la fuente canónica y sus dos copias**, para que móvil **y** web-admin queden alineados:
`docs/design-system/design-tokens.json`, `mobile/assets/design-tokens.json` y
`web-admin/assets/design-tokens.json`. Tokens semánticos a la paleta oficial Mezquite:

| Token semántico | Valor objetivo |
|---|---|
| `primary` | `#1F3A6E` (navy) |
| `secondary` | `#E0A21A` (gold) |
| `accent` | `#5C9A3A` (green) |
| `info` (o nuevo `blue`) | `#2E6FB7` |
| `on_primary` / `surface` | `#FFFFFF` |

- Reemplazar los valores de marca Rotary provisionales por la paleta Mezquite; agregar `#2E6FB7` (blue)
  y `#5C9A3A` (green); actualizar `status` de `PENDIENTE_marca_rotary`/`provisional` → oficial Mezquite.
  **Mantener los tres archivos sincronizados.**
- **Wordmark serif:** añadir un token tipográfico para el wordmark "Mezquite" servido por
  **`google_fonts`** (la fuente concreta se declara al implementar; este CR **no** la sugiere) y
  aplicarlo **solo** al wordmark, no al texto base (que sigue en la sans del design system).
- `app_theme.dart`/`design_tokens.dart` (de cada app) solo se tocan si hay que exponer el token serif o
  el color `blue`; el `ColorScheme` ya deriva de los tokens.

### 5.5 Onboarding (Dart) + flag de primer arranque

- **Nuevo** `src/ui/screens/onboarding_screen.dart`: `PageView` de 3 páginas, **dots indicator**,
  botón "Saltar" (esquina superior), botón inferior "Siguiente" (en la última, **"Comenzar"**).
  Ilustraciones como **widgets Flutter** (o `flutter_svg` con `branding/onboarding_*.svg` solo de apoyo);
  **texto y controles = widgets nativos**.
- **Contenido exacto:**

  | Pág. | Eyebrow | Título | Acento | Cuerpo |
  |---|---|---|---|---|
  | P1 | `PASO 1 · MESES 1-6` | **Concientizar** | blue `#2E6FB7` | Registra mezquites de tu comunidad con la app y activa censos base en preparatorias piloto. |
  | P2 | `PASO 2 · MESES 7-14` | **Capacitar** | green `#5C9A3A` | Toma microcursos y forma redes estudiantiles para validar daños por paxtle con evidencia. |
  | P3 | `PASO 3 · MESES 15-24` | **Combatir** | gold `#E0A21A` | Articula con autoridades el manejo fitosanitario coordinado en las zonas críticas identificadas. |

- **Flag (una sola vez):** añadir `onboardingSeen` / `markOnboardingSeen()` a
  `src/services/session_store.dart` (mismo patrón que `disclaimerSeen`, clave nueva
  `onboarding_seen`).
- **Ruteo (`src/app.dart`):** si `!onboardingSeen` → `OnboardingScreen` (al "Comenzar"/"Saltar" marca
  el flag y continúa); si ya visto → ruteo actual (`WelcomeScreen`/`HomeShell`). Exponer el flag por un
  provider (Riverpod) como ya se hace con la sesión.

---

## 6. Archivos afectados previstos

| Área | Archivos |
|---|---|
| Dependencias / assets | `mobile/pubspec.yaml`, `mobile/assets/branding/*` (**copias requeridas** desde `branding/`, ver §5.1) |
| Config de paquetes | bloque `flutter_launcher_icons` y `flutter_native_splash` (en `pubspec.yaml` o `*.yaml` dedicados) |
| Nativo Android (generado) | `mobile/android/app/src/main/res/mipmap-*/`, `drawable*/`, `values*/styles.xml`, `colors.xml` |
| Nativo iOS (generado) | `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `LaunchScreen.storyboard`, `Info.plist` |
| Tema / tokens (ambas apps) | `docs/design-system/design-tokens.json` (canónico) + copias `mobile/assets/design-tokens.json` y `web-admin/assets/design-tokens.json`; `*/lib/src/theme/design_tokens.dart`, `app_theme.dart` (mínimo) |
| Onboarding | **nuevo** `mobile/lib/src/ui/screens/onboarding_screen.dart`, `src/app.dart`, `src/services/session_store.dart`, `src/state/providers.dart` |
| Copy | `mobile/lib/src/ui/copy.dart` (textos del onboarding, si se centralizan) |
| Pruebas | `mobile/test/onboarding_test.dart` (nuevo), ajustes en tests de tema si aplica |
| Docs | `docs/design-system/*`, nota en `QUICKSTART.md`, bitácora (status de marca) |

---

## 7. Dependencias nuevas (resumen)

| Paquete | Tipo | Motivo | Condicional |
|---|---|---|---|
| `flutter_launcher_icons` | dev | Genera íconos Android/iOS | No |
| `flutter_native_splash` | dev | Genera splash nativo (incl. Android 12) | No |
| `google_fonts` | runtime | Wordmark serif (la fuente concreta se elige al implementar) | **No** (requerida) |
| `flutter_svg` | runtime | Apoyo visual del onboarding desde SVG | Solo si se usan los SVG |
| ~~`shared_preferences`~~ | — | **Ya presente** (`^2.3.3`) — no se agrega | — |

---

## 8. Desglose por agente (unidades construibles)

| # | Agente | Unidad / objetivo | Archivos | Pruebas |
|---|---|---|---|---|
| C0 | **Arquitecto** | Cerrar detalles de implementación: elegir la **serif concreta de Google Fonts**; confirmar el orden de **sincronización de los 3 archivos de tokens**; decidir si el onboarding usa `flutter_svg` o ilustraciones en widgets | — | — |
| C1 | **Dev móvil** | Deps + ícono (`flutter_launcher_icons`) + copia de masters | `pubspec.yaml`, `assets/branding/`, config ícono | build genera mipmaps/AppIcon |
| C2 | **Dev móvil** | Splash (`flutter_native_splash`, incl. android_12) | config splash, nativos | splash visible en frío |
| C3 | **Dev móvil** | Paleta en tokens canónico + móvil + wordmark serif (`google_fonts`) | `docs/design-system/design-tokens.json`, `mobile/assets/design-tokens.json`, `mobile/lib/src/theme/*`, `pubspec.yaml` | ColorScheme = paleta; wordmark serif |
| C3b | **Dev web-admin** | Paleta en la copia del web-admin | `web-admin/assets/design-tokens.json` | tema web = paleta Mezquite |
| C4 | **Dev móvil** | Onboarding (PageView + dots + flag + ruteo) | `onboarding_screen.dart`, `app.dart`, `session_store.dart`, `providers.dart`, `copy.dart` | primer arranque vs subsecuente |
| C5 | **Tester/QA** | Builds Android+iOS, pruebas de primer arranque, suite verde | `mobile/test/*` | ver §9–§10 |
| C6 | **Documentador** | design-system, QUICKSTART, status de marca en bitácora | docs | enlaces y status al día |

---

## 9. Criterios de aceptación (verificables por feature)

- **AC-Ícono-1:** instalada la app, el ícono del launcher es `icon_master_1024` con fondo navy; en
  Android el adaptive icon usa fondo `#1F3A6E`; en iOS el AppIcon **no** tiene canal alfa.
- **AC-Splash-1:** en arranque en frío aparece el splash con fondo `#1F3A6E` y el logo centrado; en
  **Android 12+** el splash usa el recurso `android_12` y el logo **no se recorta** (margen del master 1152).
- **AC-Tema-1:** en la **app móvil** el `ColorScheme` efectivo tiene `primary #1F3A6E` y
  `secondary #E0A21A`; el wordmark "Mezquite" se renderiza en una **serif de Google Fonts** (distinta de
  la sans base).
- **AC-Tema-2:** el **web-admin** levanta con la **misma paleta Mezquite** (su copia de tokens
  actualizada y sincronizada con la canónica); **sin** cambios en backend.
- **AC-Onboarding-1:** en **primer arranque** aparecen las **3 páginas** con el contenido **exacto** de
  §5.5 (eyebrow/título/acento/cuerpo), dots, "Saltar" y botón inferior ("Siguiente" → "Comenzar").
- **AC-Onboarding-2:** "Saltar" o "Comenzar" marcan el flag; en **arranques subsecuentes** la app va
  **directo** al ruteo actual (Welcome/Home) **sin** mostrar onboarding (gate #3: omitible, una vez).
- **AC-Onboarding-3:** el onboarding **no** bloquea funcionalidad ni pide datos (sin PII, sin gating).
- **AC-Backend-0:** **cero** cambios en `backend/` (verificable por diff).

---

## 10. Riesgos

- **Sobrescritura de archivos nativos:** `flutter_launcher_icons` y `flutter_native_splash`
  **regeneran/sobrescriben** archivos en `mobile/android/` e `mobile/ios/` (mipmaps, `styles.xml`,
  `LaunchScreen`, `Info.plist`). Revisar el diff tras generar y **no** editar a mano lo generado.
- **Recorte circular del splash en Android 12+:** la API de splash recorta el ícono en **círculo**; el
  master `splash_logo_master.png` (1152) ya deja margen, pero **verificar** que el logo no quede cortado.
- **Design tokens compartidos (resuelto):** la paleta vive en el design system (T7) compartido
  móvil + web-admin. **Decisión del usuario:** se actualizan la fuente canónica **y las dos copias**
  para que **ambas apps Flutter** queden alineadas. Mantener los tres archivos **sincronizados** (no
  editar solo uno) para no divergir.
- **Serif:** usar **`google_fonts`**; la fuente concreta se **elige al implementar** (este CR no la
  fija). Verificar que la serif cargue correctamente en **release** (google_fonts descarga/empaqueta
  según configuración).
- **Rutas de assets:** `branding/` está fuera del paquete `mobile/`; si no se copian los masters a
  `mobile/assets/branding/`, las rutas de los paquetes deben ser `../branding/...` (frágil).

---

## 11. Plan de pruebas

- **Build Android (release):** `cd mobile && flutter build apk --release` exitoso; instalar y verificar
  AC-Ícono-1, AC-Splash-1 (incluido un dispositivo/emulador **Android 12+** para el recorte).
- **Build iOS:** `flutter build ios --no-codesign` (o en macOS con firma) compila; AppIcon sin alfa
  (AC-Ícono-1) y LaunchScreen con el splash.
- **Primer arranque vs. subsecuente:** test de widget (`onboarding_test.dart`) con `shared_preferences`
  mockeado: (1) flag ausente → muestra las 3 páginas y el contenido exacto; (2) "Comenzar"/"Saltar"
  marca el flag y navega; (3) flag presente → **no** muestra onboarding. `flutter test` verde.
- **Análisis:** `flutter analyze` limpio (en `mobile/` y `web-admin/`).
- **Web-admin:** `cd web-admin && flutter test` verde con la copia de tokens actualizada; arranca con la
  paleta Mezquite (AC-Tema-2).
- **No-regresión backend:** `git diff --stat backend/` vacío (AC-Backend-0).

---

## 12. Definition of Done

`flutter analyze` limpio y `flutter test` verde (números reales), AC-Ícono/Splash/Tema/Onboarding
verificados en build real (incl. Android 12+), **backend intacto**, design-tokens actualizados a la
paleta oficial con su `status`, y documentación (design-system + nota en QUICKSTART) al día. Este CR
**no enmienda gates**; respeta #2, #3, #4, #5, #6, #7.

---

> **Estado:** aprobado y agregado al índice [`docs/change-requests/README.md`](README.md). Listo para
> que el equipo de agentes lo ejecute.
