# CR-013 — Licencia MIT + pantalla "Acerca de"

| Campo | Valor |
|---|---|
| **ID** | CR-013 |
| **Fecha** | 2026-06-18 |
| **Estado** | ✅ **Integrado en `main`** |
| **Alcance** | Raíz (`LICENSE`) · `mobile/` · `web-admin/` · docs |
| **Ejecución** | Directo sobre `main`, por el orquestador |

## Decisiones del usuario (2026-06-18)
1. **Licencia tipo MIT** en la raíz del repo.
2. **Titular del copyright:** `Club Rotario Bosques Aguascalientes`.
3. **Autoría (desarrollo):** `Omar Velázquez <ovelazquezj@gmail.com>` — acreditada en la licencia y en "Acerca de".
4. **Pantalla "Acerca de"** en **ambas apps** (voluntario + web-admin), con nombre del proyecto, versión **`beta-2606`**, copyright del Club y el correo del autor.

## Qué se hizo
| Pieza | Detalle |
|---|---|
| `LICENSE` (raíz) | Texto canónico **MIT**. `Copyright (c) 2026 Club Rotario Bosques Aguascalientes` + línea `Autor / Author: Omar Velázquez <ovelazquezj@gmail.com>`. |
| Constantes de copy | `appVersion='beta-2606'`, `projectName`, `copyrightNotice='© 2026 …'`, `authorName`, `authorEmail` y textos de "Acerca de" en `mobile/lib/src/ui/copy.dart` y `web-admin/lib/src/ui/copy.dart` (fuente única; el semver técnico sigue en `pubspec.yaml`). |
| App del voluntario | `mobile/lib/src/ui/screens/about_screen.dart` (logo, proyecto, versión, copyright del Club, autoría + correo, licencia MIT, botón "Ver licencias de terceros" → `showLicensePage`). Acceso desde **Perfil** (`ListTile` "Acerca de", key `profile_about_link`). |
| Web-admin | `web-admin/lib/src/screens/about_screen.dart` + entrada **"Acerca de"** en el `NavigationRail` (`Copy.navAbout`), visible a **todos los roles** (junto a Legal). |

## Gates
- **Gate #2 (sin PII):** la autoría/copyright es **metadato del proyecto** (crédito estático del autor y del titular del copyright), **no** un dato de usuario recolectado ni un cambio al modelo de datos. El correo mostrado es el de contacto del autor, no PII de una persona voluntaria. **No se viola el gate.**
- Resto de gates: sin cambios.

## Pruebas
- `mobile/test/about_test.dart` — nombre del proyecto, `beta-2606`, copyright del Club, autoría (Omar Velázquez) + correo, licencia MIT.
- `web-admin/test/widget_about_test.dart` — equivalente en la consola.
- Suites completas re-corridas; números reales reportados en el cierre y en `TRACEABILITY.md`.

## Notas
- Sin cambios de backend ni migración.
- `beta-2606` es la **etiqueta de release visible** que pidió el usuario; el `version:` de cada `pubspec.yaml` se conserva como semver técnico del build.
