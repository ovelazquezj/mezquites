# CR-012 — Paginación de tablas + header (hallazgos de revisión)

| Campo | Valor |
|---|---|
| **ID** | CR-012 |
| **Fecha** | 2026-06-17 |
| **Estado** | ✅ **Integrado en `main`** (301 pruebas verdes) |
| **Alcance** | Solo `web-admin/` |
| **Ejecución** | Directo sobre `main`, por el orquestador |

## Decisiones del usuario (2026-06-17)
1. Header (#3): **(a)** logo grande del proyecto + "Club Rotario Bosques Aguascalientes" como **subtítulo** más pequeño.
2. Paginación (#1/#2): **sí**, en **todas** las tablas; **10** filas/página por defecto.
3. Ejecución directa.

## Hallazgos → arreglo
| # | Hallazgo | Causa raíz | Arreglo |
|---|---|---|---|
| 1 | La barra de scroll horizontal queda hasta el final (hay que bajar al último registro) | la barra del `HScroll` se dibuja al borde inferior de una tabla **muy alta** (sin paginar) | paginación: páginas cortas ⇒ la barra queda bajo las filas visibles |
| 2 | ¿Las tablas paginan? ¿cómo? | **no** paginaban (DataTable con todas las filas) | nuevo **`PagedTable<T>`**: paginación cliente, selector 10/25/50, Anterior/Siguiente, "X–Y de Z" |
| 3 | Header se ve muy pequeño / "logo equivocado" | **(1)** se renderizaba a 44 px; **(2)** el logo tenía letras **azul marino**, **ilegibles** sobre el header navy (por eso parecía "el equivocado") | logo 44→**56**, AppBar 64→**80**, Club como subtítulo (15 px) **+ variante de letras blancas** (`logo_horizontal_white.png`, provista por el usuario) en el header; el login (fondo blanco) conserva el logo normal |

## Implementación
- `web-admin/lib/src/widgets/paged_table.dart` — `PagedTable<T>` (envuelve `HScroll`+`DataTable` + controles).
- 5 tablas migradas a `PagedTable`: `public_dashboard`, `restricted_dashboard`, `review`, `data`, `institutions`.
- `home_shell.dart` — AppBar (logo 56, toolbarHeight 80, subtítulo del Club, **logo de letras blancas**).
- `web-admin/assets/branding/logo_horizontal_white.png` (+ `pubspec.yaml`) — variante de letras blancas
  para el header navy (provista por el usuario). El **login** (fondo blanco) sigue con `logo_horizontal.png`.

## Pruebas
**301 verdes** — `contract` 21 · `mock` 9 · `backend` 136 · `móvil` 61 · **`web-admin` 74** (+2:
`widget_cr012_test.dart` — 10 filas/página, rango "1–10 de 25", "Siguiente" avanza). Demo: web-admin
reconstruido por `appctl`.

## Notas
- Sin cambios de backend ni móvil. Sin migración.
- `HScroll` se conserva (lo usa `PagedTable` internamente).
