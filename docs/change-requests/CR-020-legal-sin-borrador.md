# CR-020 — Quitar el sello "BORRADOR" de Términos y Aviso de privacidad (ya aprobados)

| Campo | Valor |
|---|---|
| **ID** | CR-020 |
| **Fecha** | 2026-06-28 |
| **Estado** | ✅ Implementado en `main` (local), pendiente de desplegar |
| **Alcance** | `mobile/` · `web-admin/` (solo lo legal) |
| **Relación** | Cierra el pendiente de CR-006 (banner BORRADOR in-app) |
| **Ejecución** | Directo sobre `main`, por el orquestador |

## 1. Contexto

El **Aviso de privacidad** (aprobado el 2026-06-25) y los **Términos** (aprobados el 2026-06-27) ya están
vigentes y publicados (páginas públicas `/aviso-privacidad` y `/terminos` servidas por Caddy). Sin
embargo, la app del voluntario y la consola seguían mostrando la leyenda **"BORRADOR"** sobre esos
textos, contradiciendo su estado real (era el pendiente declarado en CR-006).

## 2. Decisión del usuario (2026-06-28)

Quitar el sello "BORRADOR" **solo** de las pantallas legales (Términos / Aviso), ya que ambos están
aprobados. El borrador de "Aprender" es independiente y **se conserva**.

## 3. Qué se hizo

### Móvil

| Pieza | Detalle |
|---|---|
| `legal_screen.dart` | Se quitó `InfoNote(Copy.legalDraftBanner)`. |
| `copy.dart` | Se eliminó la constante `legalDraftBanner`. |
| `legal_test.dart` | Ahora afirma `findsNothing` para el texto 'BORRADOR'. |

### Web-admin

| Pieza | Detalle |
|---|---|
| `legal_screen.dart` | Se quitó `_DraftBadge` y `Copy.legalDraftBadge`; se ajustó `legalIntro` (textos **aprobados**). |
| Sección "Contacto" | Se corrigió (antes "pendiente de definición") → contacto oficial **contacto@rescatando-el-mezquite.org** + domicilio del responsable. |
| `widget_legal_test.dart` | Afirma que **ya no** aparece el sello. |

## 4. Alcance y gates

- **Alcance:** **solo lo legal**. El banner BORRADOR de "Aprender" (`learningDraftBanner`) **se conserva**
  intacto — sigue en revisión académica (AU2 / H4).
- **Gate #2 (sin PII):** **intacto** — el contacto/domicilio del **responsable** (el Club) es dato del
  responsable de tratamiento, no dato de usuario.
- Resto de gates: sin cambios.

## 5. Pruebas / verificación

- Móvil: `legal_test.dart` afirma ausencia de 'BORRADOR'.
- Web-admin: `widget_legal_test.dart` afirma ausencia del sello.
- Suites móvil (66) y web-admin (85) verdes tras el cambio.

## 6. Notas

- Las páginas públicas (`infra/compose/legal/*.html`) ya estaban sin borrador desde CR-006; este CR
  alinea las pantallas **in-app** con ese estado.
