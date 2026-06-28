# CR-016 — Botón "Instalar app" (instalación PWA) en la app del voluntario

| Campo | Valor |
|---|---|
| **ID** | CR-016 |
| **Fecha** | 2026-06-28 |
| **Estado** | ✅ **Integrado en `main`** (a desplegar con el siguiente build web) |
| **Alcance** | `mobile/` (solo web) |
| **Depende de** | CR-005 (la app del voluntario compila a web / PWA) |
| **Ejecución** | Directo sobre `main`, por el orquestador |

## 1. Contexto

La app del voluntario es una **PWA** instalable (manifest válido, service worker, íconos 192/512 +
maskable, HTTPS). Sin embargo, el **banner automático** de instalación de Chrome aparece **una sola vez
por origen** y luego entra en cooldown (~90 días). En el piloto, el dominio
`app.rescatando-el-mezquite.org` ya había sido visitado (despliegue *mock* previo), así que el banner ya
no reaparecía y los voluntarios no tenían una forma evidente de instalar la app.

## 2. Decisión del usuario (2026-06-28)
Agregar un **botón propio "Instalar app"** dentro de la app (probado en Android), en **Bienvenida** y
**Perfil**.

## 3. Qué se hizo
| Pieza | Detalle |
|---|---|
| `mobile/web/index.html` | Script que captura `beforeinstallprompt` (preventDefault + lo guarda en `window`), escucha `appinstalled`, y expone `pwaCanInstall()`, `pwaIsStandalone()`, `pwaPromptInstall()`. Así el botón propio lanza el diálogo nativo **aunque el banner automático esté en cooldown**. |
| `mobile/lib/src/services/pwa_install*.dart` | Servicio con **import condicional** (`pwa_install_web.dart` con `dart:js_interop` + `package:web`; `pwa_install_stub.dart` para no-web/tests). API: `canInstall()`, `isStandalone()`, `isIosWeb()`, `promptInstall()`, `installabilityChanges()`. |
| `mobile/lib/src/ui/widgets/install_app_button.dart` | Botón **`InstallAppButton`** que se auto-oculta si no aplica (fuera de web, o ya instalada). En Android/escritorio aparece cuando hay prompt; en **iOS** muestra instrucciones (Compartir → Agregar a inicio), ya que Safari no soporta el evento. |
| Pantallas | Botón en **Bienvenida** (bajo "Ver el mapa público") y **Perfil** (junto a "Acerca de"). |
| `copy.dart` | Textos `installButton`, `installTitle`, `installIosInstructions`, `installIosOk`. |
| `pubspec.yaml` | Dependencia `web: ^1.1.0` (interop de navegador). |

## 4. Gates
- **Gate #3 (sin gating):** el botón es **opcional** y NUNCA bloquea ni condiciona el uso de la app.
- **Gate #2 (sin PII):** la instalación es 100 % del lado del navegador; no recolecta ni envía datos.
- Resto de gates: sin cambios.

## 5. Pruebas
- `mobile/test/install_app_button_test.dart` — fuera de web (en `flutter test`, VM) el botón **no** se
  muestra (no rompe la UI). El comportamiento web (prompt nativo) se valida manualmente en el navegador.
- Suite móvil completa re-corrida verde tras el cambio.

## 6. Notas
- En **iPhone/Safari** no existe prompt programático: el botón abre las instrucciones manuales (es lo
  máximo que iOS permite).
- No requiere backend ni migración.
