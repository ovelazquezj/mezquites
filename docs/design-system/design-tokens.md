# Design system — tokens compartidos (móvil + web admin)

> Materializa **T7**. Estética **minimalista tipo eBird**, baja densidad visual, iconografía
> ecológica. **Paleta oficial del Proyecto Mezquite** (CR-003): **navy + azul + dorado + verde**.
> **Fuente única:** [`design-tokens.json`](design-tokens.json) — consumido por el cliente móvil
> (Flutter `ThemeData`) y por la web admin. Ninguna pantalla introduce elementos fuera de estos tokens.

## Paleta oficial Mezquite (CR-003)

Los hex de marca son **oficiales** (`status: oficial_mezquite`): la paleta del Proyecto Mezquite
**resuelve** el pendiente histórico de marca para **ambas apps Flutter**. Al cambiar la paleta se
actualiza la fuente canónica `design-tokens.json` **y sus dos copias** empaquetadas
(`mobile/assets/design-tokens.json`, `web-admin/assets/design-tokens.json`), que deben quedar
**byte-idénticas**.

| Marca | Hex |
|---|---|
| navy | `#1F3A6E` (primary / fondo de splash / fondo adaptive icon) |
| blue | `#2E6FB7` |
| gold | `#E0A21A` (secondary) |
| green | `#5C9A3A` (accent) |
| white | `#FFFFFF` |

## Roles semánticos (lo que el código usa)

| Token semántico | Referencia Mezquite | Uso |
|---|---|---|
| `primary` | navy `#1F3A6E` | Acciones principales, encabezados, navegación |
| `secondary` | gold `#E0A21A` | Acentos, insignias, destacados |
| `accent` | green `#5C9A3A` | Estados de "vivo/observación", énfasis ecológico |
| `blue` / `info` | blue `#2E6FB7` | Acento del onboarding (P1) y mensajes informativos |
| `background` | Neutral surface-2 | Fondo de pantallas |
| `text` / `text_muted` | Tinta 900 / 600 | Texto principal / secundario |
| `success` | Verde 700 | Confirmaciones (p.ej. envío registrado) |

> **Importante (gate #4, Q5.A-D1):** no existe token ni patrón de "estado de validación individual"
> en la UI del voluntario. El feedback es **agregado**.

## Tipografía, espacio, forma

- **Tipografía base:** `Inter`/`Roboto`, escala `display / title / body / caption`.
- **Wordmark serif (CR-003):** token `font_family_wordmark` = **`Fraunces`** (serif de Google Fonts,
  servida vía `google_fonts`). Se aplica **solo** al wordmark "Mezquite"; el resto del texto sigue en
  la sans base. En la app móvil el wordmark vive en el widget `Wordmark` (Welcome + onboarding).
- **Espaciado:** múltiplos de 4 (`xs 4 … xl 32`).
- **Radios:** `sm 8 / md 12 / lg 20 / pill`.
- **Elevación:** mínima (`card 1`, `raised 3`) — coherente con baja densidad.

## Consumo

- **Flutter (Incremento 3):** un generador convierte `design-tokens.json` en un `ThemeData`/clase de
  tokens. Sin colores literales en widgets.
- **Web admin (Incremento 4):** los tokens se importan como variables (CSS custom properties o
  equivalente del framework elegido).
