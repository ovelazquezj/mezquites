# Design system — tokens compartidos (móvil + web admin)

> Materializa **T7**. Estética **minimalista tipo eBird**, baja densidad visual, iconografía
> ecológica. Paleta de marca **Rotary (azul royal + dorado)** + **verdes ecológicos**.
> **Fuente única:** [`design-tokens.json`](design-tokens.json) — consumido por el cliente móvil
> (Flutter `ThemeData`) y por la web admin. Ninguna pantalla introduce elementos fuera de estos tokens.

## ⚠️ Valores hex = token pendiente

Los hex de marca Rotary son **provisionales** (marcados `PENDIENTE_marca_rotary`). La bitácora (T7)
sella la *paleta* (Rotary + verdes) pero **no fija las cifras**: deben tomarse de la **guía de marca
oficial de Rotary**. Al obtenerla, se actualiza **solo** `design-tokens.json` y ambos clientes
heredan el cambio.

## Roles semánticos (lo que el código usa)

| Token semántico | Referencia provisional | Uso |
|---|---|---|
| `primary` | Rotary royal blue | Acciones principales, encabezados, navegación |
| `secondary` | Rotary gold | Acentos, insignias, destacados |
| `accent` | Verde ecológico 500 | Estados de "vivo/observación", énfasis ecológico |
| `background` | Neutral surface-2 | Fondo de pantallas |
| `text` / `text_muted` | Tinta 900 / 600 | Texto principal / secundario |
| `success` | Verde 700 | Confirmaciones (p.ej. envío registrado) |
| `info` | Rotary azure | Mensajes informativos |

> **Importante (gate #4, Q5.A-D1):** no existe token ni patrón de "estado de validación individual"
> en la UI del voluntario. El feedback es **agregado**.

## Tipografía, espacio, forma

- **Tipografía:** `Inter`/`Roboto`, escala `display / title / body / caption`.
- **Espaciado:** múltiplos de 4 (`xs 4 … xl 32`).
- **Radios:** `sm 8 / md 12 / lg 20 / pill`.
- **Elevación:** mínima (`card 1`, `raised 3`) — coherente con baja densidad.

## Consumo

- **Flutter (Incremento 3):** un generador convierte `design-tokens.json` en un `ThemeData`/clase de
  tokens. Sin colores literales en widgets.
- **Web admin (Incremento 4):** los tokens se importan como variables (CSS custom properties o
  equivalente del framework elegido).
